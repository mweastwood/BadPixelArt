import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'prompts.dart';
import 'drawing_commands.dart';
import 'algorithms/k_means_quantizer.dart';
import 'agents/base_agent.dart';
import 'agents/color_selection_agent.dart';
import 'orchestrators/sketch_orchestrator.dart';
import 'orchestrators/refinement_orchestrator.dart';
import 'orchestrators/decomposition_orchestrator.dart';
import 'orchestrators/sculpting_orchestrator.dart';
import 'controllers/auto_play_controller.dart';
import 'controllers/canvas_history_controller.dart';
import 'controllers/canvas_drawing_handler.dart';
import 'repositories/canvas_repository.dart';
import 'utils/bmp_utils.dart';
import 'models/color_palette.dart';
import 'models/canvas_model.dart';
import 'utils/logging_ai_service.dart';
import 'wizard_state.dart';

export 'utils/bmp_utils.dart';
export 'models/canvas_model.dart';
export 'models/pixel_art_component.dart';
export 'agents/color_selection_agent.dart';
export 'controllers/canvas_history_controller.dart';
export 'controllers/canvas_drawing_handler.dart';

abstract class AgentCanvas {
  List<List<int>> get grid;
  List<Color> get palette;
  void applyCommand(String toolName, List<num> params, int colorIndex);
  Uint8List generateCombinedVisualInput(
    Uint8List? referenceBmp,
    Uint8List? previousBmp,
  );
}

class CanvasNotifier extends StateNotifier<CanvasModel> implements AgentCanvas {
  AiService _aiService;
  final CanvasRepository _repository;
  final AutoPlayWizardController _autoPlayController;
  final WizardNotifier? wizardNotifier;
  final CanvasHistoryController _historyController;
  final CanvasDrawingHandler _drawingHandler;
  late DecompositionOrchestrator _decompositionOrchestrator;
  late SculptingOrchestrator _sculptingOrchestrator;
  Timer? _autoRunTimer;

  static const int gridSize = 16;

  CanvasModel get model => state;
  AiService get aiService => _aiService;

  @override
  List<List<int>> get grid => state.grid;

  @override
  List<Color> get palette => state.palette;

  @override
  void applyCommand(String toolName, List<num> params, int colorIndex) {
    final boundedColorIndex = state.palette.isEmpty
        ? 0
        : colorIndex.clamp(0, state.palette.length - 1);
    state = state.copyWith(selectedColorIndex: boundedColorIndex);

    if (toolName == 'undo') {
      undo();
      return;
    }

    final command = DrawingCommandFactory.create(toolName, params);
    if (command != null) {
      _executeCommand(command);
    }
  }

  @override
  Uint8List generateCombinedVisualInput(
    Uint8List? referenceBmp,
    Uint8List? previousBmp,
  ) {
    final List<Uint8List> bmpsToCombine = [];

    if (referenceBmp != null) {
      var refGrid = bmpToDownscaledColorGrid(referenceBmp, state.gridSize);
      if (refGrid.isEmpty) {
        refGrid = bmpToColorGrid(referenceBmp);
        if (refGrid.isNotEmpty && refGrid.length != state.gridSize) {
          refGrid = downscaleColorGrid(refGrid, state.gridSize);
        }
      }
      if (refGrid.isNotEmpty) {
        final blurredGrid = applyGaussianBlur(refGrid);
        final quantizedGrid = applyColorQuantization(
          blurredGrid,
          state.palette,
        );
        final quantizedBmp = bmpFromColorGrid(quantizedGrid);
        bmpsToCombine.add(quantizedBmp);
      }
    }

    final currentBmp = previousBmp ?? generateBmp(state.grid, state.palette);
    bmpsToCombine.add(currentBmp);

    return combineBmps(bmpsToCombine);
  }

  static List<Color> get grayscalePalette => PaletteRegistry.grayscalePalette;
  static List<Color> get primaryPalette => PaletteRegistry.primaryPalette;
  static List<Color> get gameboyPalette => PaletteRegistry.gameboyPalette;
  static List<Color> get nesPalette => PaletteRegistry.nesPalette;
  static List<Color> get pico8Palette => PaletteRegistry.pico8Palette;

  Timer? _saveTimer;
  bool _isRestoring = false;
  bool _isSaving = false;
  bool _hasPendingSave = false;

  @override
  set state(CanvasModel value) {
    super.state = value;
    _scheduleSave();
  }

  void _scheduleSave() {
    if (_isRestoring) return;
    final isTesting =
        kDebugMode &&
        !kIsWeb &&
        Platform.environment.containsKey('FLUTTER_TEST');
    if (isTesting) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      await saveToDb();
    });
  }

  // --- DATABASE / PERSISTENCE OPERATIONS ---

  Future<void> saveToDb() async {
    if (!mounted || _isRestoring) return;
    if (_isSaving) {
      _hasPendingSave = true;
      return;
    }
    _isSaving = true;
    try {
      do {
        _hasPendingSave = false;
        final currentState = state;
        final savedState = await _repository.saveCanvas(currentState);
        if (!mounted) return;
        // Preserve any concurrent user state mutations while updating creationId
        if (state.creationId != savedState.creationId) {
          state = state.copyWith(creationId: savedState.creationId);
        }
      } while (_hasPendingSave && mounted && !_isRestoring);
    } finally {
      _isSaving = false;
    }
  }

  Future<void> loadFromDb(int id) async {
    if (!mounted) return;
    _isRestoring = true;
    try {
      if (state.autoRun) {
        _autoRunTimer?.cancel();
      }
      final newState = await _repository.loadCanvas(id, state);
      if (!mounted) return;
      if (newState != null) {
        state = newState;
      }
    } finally {
      _isRestoring = false;
    }
  }

  Future<void> loadLastSession() async {
    if (!mounted) return;
    _isRestoring = true;
    try {
      final newState = await _repository.loadLastSession(state);
      if (!mounted) return;
      if (newState != null) {
        state = newState;
      }
    } finally {
      _isRestoring = false;
    }
  }

  Future<void> startNewCanvas() async {
    if (!mounted) return;
    _isRestoring = true;
    try {
      _saveTimer?.cancel();
      _hasPendingSave = false;
      if (state.autoRun) {
        _autoRunTimer?.cancel();
      }

      state = CanvasModel(
        gridSize: 16,
        grid: List.generate(16, (_) => List.filled(16, 0)),
        selectedColorIndex: 1,
        selectedTool: CanvasTool.line,
        paletteName: 'primary',
        palette: primaryPalette,
        userPrompt: '',
        aiStatus: AiCoreStatus.available,
        isGenerating: false,
        autoRun: false,
        autoRunSpeed: 1.5,
        undoStack: const [],
        redoStack: const [],
        aiHistory: const [],
        referenceImage: null,
        originalReferenceImage: null,
        modelReleaseStage: state.modelReleaseStage,
        modelPreference: state.modelPreference,
      );

      await _repository.saveNewSession(state);
    } finally {
      _isRestoring = false;
    }
  }

  Future<void> duplicateCanvas(int id) async {
    if (!mounted) return;
    final newId = await _repository.duplicateCanvas(id);
    if (!mounted) return;
    if (newId != null) {
      await loadFromDb(newId);
    }
  }

  Future<void> renameCanvas(String newTitle) async {
    if (!mounted) return;
    state = state.copyWith(title: newTitle);
    await saveToDb();
  }

  Future<void> renameCanvasById(int id, String newTitle) async {
    if (!mounted) return;
    if (state.creationId == id) {
      await renameCanvas(newTitle);
    } else {
      await _repository.renameCanvasById(id, newTitle);
    }
  }

  Future<void> deleteCanvas(int id) async {
    if (!mounted) return;
    final nextId = await _repository.deleteCanvas(id);
    if (!mounted) return;
    if (state.creationId == id) {
      if (nextId != null) {
        await loadFromDb(nextId);
      } else {
        await startNewCanvas();
      }
    }
  }

  void _setupLoggingAiService() {
    if (_aiService is LoggingAiService) {
      final logging = _aiService as LoggingAiService;
      logging.onLog = (entry) {
        if (!mounted) return;
        state = state.copyWith(aiHistory: [...state.aiHistory, entry]);
      };
      logging.onLogUpdate = (oldEntry, newEntry) {
        if (!mounted) return;
        final history = List<AgentHistoryEntry>.from(state.aiHistory);
        final index = history.indexOf(oldEntry);
        if (index != -1) {
          history[index] = newEntry;
        } else {
          history.add(newEntry);
        }
        state = state.copyWith(aiHistory: history);
      };
    }
  }

  void updateAiService(AiService newAiService) {
    _aiService = newAiService;
    _decompositionOrchestrator = DecompositionOrchestrator(_aiService);
    _sculptingOrchestrator = SculptingOrchestrator(_aiService);
    _setupLoggingAiService();
  }

  CanvasNotifier(
    this._aiService, {
    CanvasModel? initialModel,
    CanvasRepository? repository,
    AutoPlayWizardController? autoPlayController,
    this.wizardNotifier,
    DecompositionOrchestrator? decompositionOrchestrator,
    SculptingOrchestrator? sculptingOrchestrator,
    CanvasHistoryController? historyController,
    CanvasDrawingHandler? drawingHandler,
  }) : _repository = repository ?? CanvasRepository(),
       _autoPlayController = autoPlayController ?? AutoPlayWizardController(),
       _historyController =
           historyController ?? const CanvasHistoryController(),
       _drawingHandler =
           drawingHandler ??
           CanvasDrawingHandler(
             historyController:
                 historyController ?? const CanvasHistoryController(),
           ),
       super(
         initialModel ??
             CanvasModel(
               gridSize: 16,
               grid: List.generate(16, (_) => List.filled(16, 0)),
               selectedColorIndex: 1, // Start with white/light color
               selectedTool: CanvasTool.line,
               paletteName: 'primary',
               palette: primaryPalette,
               userPrompt: '',
               aiStatus: AiCoreStatus.available,
               isGenerating: false,
               autoRun: false,
               autoRunSpeed: 1.5,
               undoStack: [],
               redoStack: [],
               aiHistory: const [],
               referenceImage: null,
               originalReferenceImage: null,
               modelReleaseStage: 'stable',
               modelPreference: 'full',
             ),
       ) {
    _decompositionOrchestrator =
        decompositionOrchestrator ?? DecompositionOrchestrator(_aiService);
    _sculptingOrchestrator =
        sculptingOrchestrator ?? SculptingOrchestrator(_aiService);
    _setupLoggingAiService();
    _initModelConfig();
  }

  void changeResolution(int newSize) {
    if (newSize != 8 && newSize != 16) return;
    state = state.copyWith(
      gridSize: newSize,
      grid: List.generate(newSize, (_) => List.filled(newSize, 0)),
      decomposedComponents: const [],
      pendingDecompositionOptions: const [],
      activeComponentIndex: 0,
      showPaletteSuggestion: false,
      clearSuggestedPalette: true,
      undoStack: const [],
      redoStack: const [],
    );
  }

  void selectComponent(int index) {
    if (index >= 0 && index < state.decomposedComponents.length) {
      state = state.copyWith(activeComponentIndex: index);
    }
  }

  void updateComponentBoundingBox(int index, Rect newBoundingBox) {
    if (index >= 0 && index < state.decomposedComponents.length) {
      final updated = List<PixelArtComponent>.from(state.decomposedComponents);
      updated[index] = updated[index].copyWith(
        relativeBoundingBox: newBoundingBox,
      );
      state = state.copyWith(decomposedComponents: updated);
    }
  }

  void updateComponentColors(
    int index,
    Color? fillColor,
    Color? outlineColor, {
    Color? fillColor2,
    double? gradientAngle,
  }) {
    if (index >= 0 && index < state.decomposedComponents.length) {
      final updated = List<PixelArtComponent>.from(state.decomposedComponents);
      updated[index] = updated[index].copyWith(
        fillColor: fillColor == null ? () => null : () => fillColor,
        fillColor2: fillColor2 == null ? () => null : () => fillColor2,
        gradientAngle: gradientAngle ?? updated[index].gradientAngle,
        outlineColor: outlineColor == null ? () => null : () => outlineColor,
      );
      state = state.copyWith(decomposedComponents: updated);
    }
  }

  void batchUpdateComponentColors(List<PixelArtComponent> updatedComponents) {
    if (updatedComponents.isEmpty || state.decomposedComponents.isEmpty) return;
    final updated = List<PixelArtComponent>.from(state.decomposedComponents);
    final count = math.min(updated.length, updatedComponents.length);
    for (int i = 0; i < count; i++) {
      final c = updatedComponents[i];
      updated[i] = updated[i].copyWith(
        fillColor: c.fillColor == null ? () => null : () => c.fillColor,
        fillColor2: c.fillColor2 == null ? () => null : () => c.fillColor2,
        gradientAngle: c.gradientAngle,
        outlineColor: c.outlineColor == null
            ? () => null
            : () => c.outlineColor,
      );
    }
    state = state.copyWith(decomposedComponents: updated);
  }

  Future<AiColorSelectionResult?> suggestComponentColors() async {
    if (!mounted || state.isGenerating || state.decomposedComponents.isEmpty) {
      return null;
    }
    state = state.copyWith(isGenerating: true);
    try {
      final agent = ColorSelectionAgent(_aiService);
      final result = await agent.suggestColors(
        userPrompt: state.userPrompt,
        components: state.decomposedComponents,
        palette: state.palette,
        imageBytes: state.referenceImage,
      );
      if (mounted) {
        state = state.copyWith(isGenerating: false);
      }
      return result;
    } catch (e) {
      debugPrint('Error suggesting component colors: $e');
      if (mounted) {
        state = state.copyWith(
          isGenerating: false,
          autoRun: false,
          isPausing: false,
        );
      }
      return null;
    }
  }

  void deleteComponent(int index) {
    if (index >= 0 && index < state.decomposedComponents.length) {
      final updated = List<PixelArtComponent>.from(state.decomposedComponents);
      updated.removeAt(index);
      int newActiveIndex = state.activeComponentIndex;
      if (updated.isEmpty) {
        newActiveIndex = 0;
      } else if (newActiveIndex >= updated.length) {
        newActiveIndex = updated.length - 1;
      }
      state = state.copyWith(
        decomposedComponents: updated,
        activeComponentIndex: newActiveIndex,
      );
    }
  }

  void applyDecompositionOption(int index) {
    if (index >= 0 && index < state.pendingDecompositionOptions.length) {
      final selectedComponents = state.pendingDecompositionOptions[index];
      state = state.copyWith(
        decomposedComponents: selectedComponents,
        activeComponentIndex: 0,
        pendingDecompositionOptions: const [],
      );
    }
  }

  void clearPendingDecompositionOptions() {
    state = state.copyWith(pendingDecompositionOptions: const []);
  }

  void clearDecomposedComponents() {
    state = state.copyWith(
      pendingDecompositionOptions: const [],
      decomposedComponents: const [],
      activeComponentIndex: 0,
    );
  }

  Future<void> _initModelConfig() async {
    if (!mounted) return;
    await _aiService.setModelConfig(
      releaseStage: state.modelReleaseStage,
      preference: state.modelPreference,
    );
    if (!mounted) return;
    await checkAiStatus();
  }

  Future<void> setModelConfig(String stage, String preference) async {
    if (!mounted) return;
    state = state.copyWith(
      modelReleaseStage: stage,
      modelPreference: preference,
    );
    await _aiService.setModelConfig(
      releaseStage: state.modelReleaseStage,
      preference: state.modelPreference,
    );
    if (!mounted) return;
    await checkAiStatus();
  }

  @override
  void dispose() {
    _autoRunTimer?.cancel();
    _saveTimer?.cancel();
    _hasPendingSave = false;
    super.dispose();
  }

  Future<void> checkAiStatus() async {
    if (!mounted) return;
    final status = await _aiService.checkStatus();
    if (!mounted) return;
    state = state.copyWith(aiStatus: status);
  }

  Future<void> triggerDownload() async {
    if (!mounted) return;
    state = state.copyWith(aiStatus: AiCoreStatus.downloading);
    await _aiService.triggerDownload();
    if (!mounted) return;
    await checkAiStatus();
  }

  void setPalette(String name, List<Color> colors) {
    state = state.copyWith(
      paletteName: name,
      palette: colors,
      selectedColorIndex: 0,
      decomposedComponents: const [],
      pendingDecompositionOptions: const [],
    );
    resetCanvas();
  }

  void selectPalette(String name) {
    final newPalette = PaletteRegistry.getById(name).colors;
    setPalette(name, newPalette);
  }

  void selectColorIndex(int index) {
    if (index >= 0 && index < state.palette.length) {
      state = state.copyWith(selectedColorIndex: index);
    }
  }

  void selectColor(int index) {
    selectColorIndex(index);
  }

  void selectTool(CanvasTool tool) {
    state = state.copyWith(selectedTool: tool);
  }

  void updatePrompt(String prompt) {
    final promptChanged = state.userPrompt != prompt;
    state = state.copyWith(
      userPrompt: prompt,
      decomposedComponents: promptChanged
          ? const []
          : state.decomposedComponents,
      pendingDecompositionOptions: promptChanged
          ? const []
          : state.pendingDecompositionOptions,
    );
  }

  void setReferenceImage(Uint8List? bytes, {Uint8List? originalBytes}) {
    if (bytes == null) {
      state = state.copyWith(
        clearReference: true,
        clearSuggestedPalette: true,
        showPaletteSuggestion: false,
        clearNextFocus: true,
        decomposedComponents: const [],
        pendingDecompositionOptions: const [],
      );
    } else {
      state = state.copyWith(
        referenceImage: bytes,
        originalReferenceImage: originalBytes,
        decomposedComponents: const [],
        pendingDecompositionOptions: const [],
      );
    }
  }

  Future<void> setUploadedReferenceImage(Uint8List rawBytes) async {
    final bmp = await resizeAndConvertToBmp(rawBytes, 512);
    if (!mounted) return;
    if (bmp != null) {
      state = state.copyWith(
        referenceImage: bmp,
        originalReferenceImage: rawBytes,
        decomposedComponents: const [],
        pendingDecompositionOptions: const [],
      );
    }
  }

  Future<void> suggestPaletteFromReference() async {
    if (!mounted) return;
    final refImg = state.referenceImage;
    if (refImg == null) return;

    state = state.copyWith(
      isSuggestingPalette: true,
      showPaletteSuggestion: false,
    );

    try {
      final colors = await _aiService.suggestPalette(refImg);
      if (!mounted) return;
      if (colors != null) {
        state = state.copyWith(
          suggestedPalette: colors,
          showPaletteSuggestion: true,
        );
      } else {
        state = state.copyWith(
          isSuggestingPalette: false,
          autoRun: false,
          isPausing: false,
        );
        return;
      }
    } catch (e) {
      debugPrint('Error suggesting palette: $e');
      if (!mounted) return;
      state = state.copyWith(
        isSuggestingPalette: false,
        autoRun: false,
        isPausing: false,
      );
      return;
    } finally {
      if (mounted) {
        final willStop = state.isPausing;
        state = state.copyWith(
          isSuggestingPalette: false,
          autoRun: willStop ? false : state.autoRun,
          isPausing: false,
        );
      }
    }
  }

  Future<void> suggestDescriptionFromReference() async {
    if (!mounted) return;
    final refImg = state.referenceImage;
    if (refImg == null || state.isGenerating || state.isSuggestingDescription) {
      return;
    }

    state = state.copyWith(isSuggestingDescription: true);

    try {
      final response = await _aiService.generateContent(
        prompt:
            'Describe what subject or item this reference image depicts in a concise 1-2 sentence description for a pixel art drawing prompt.',
        imageBytes: refImg,
      );
      if (!mounted) return;
      if (response != null && response.trim().isNotEmpty) {
        updatePrompt(response.trim());
      }
    } catch (e) {
      debugPrint('Error suggesting description from reference image: $e');
      if (!mounted) return;
      state = state.copyWith(
        isSuggestingDescription: false,
        autoRun: false,
        isPausing: false,
      );
      return;
    } finally {
      if (mounted) {
        final willStop = state.isPausing;
        state = state.copyWith(
          isSuggestingDescription: false,
          autoRun: willStop ? false : state.autoRun,
          isPausing: false,
        );
      }
    }
  }

  void acceptSuggestedPalette() {
    if (state.suggestedPalette != null) {
      state = state.copyWith(
        paletteName: 'suggested',
        palette: state.suggestedPalette,
        showPaletteSuggestion: false,
        selectedColorIndex: 0,
      );
      resetCanvas();
    }
  }

  void rejectSuggestedPalette() {
    state = state.copyWith(
      showPaletteSuggestion: false,
      clearSuggestedPalette: true,
    );
  }

  void extractPaletteAlgorithmic([int k = 8]) {
    final refImg = state.referenceImage;
    if (refImg == null) return;
    try {
      final colorGrid = bmpToColorGrid(refImg);
      final colors = kMeansQuantize(colorGrid, k);
      state = state.copyWith(
        paletteName: 'algorithmic',
        palette: colors,
        selectedColorIndex: 1,
      );
      resetCanvas();
    } catch (e) {
      debugPrint('Error in algorithmic color extraction: $e');
    }
  }

  void resetCanvas() {
    state = state.copyWith(
      grid: List.generate(
        state.gridSize,
        (_) => List.filled(state.gridSize, 0),
      ),
      undoStack: [],
      redoStack: [],
    );
  }

  void _pushToUndo(List<List<int>> currentGrid) {
    final pushResult = _historyController.push(currentGrid, state.undoStack);
    state = state.copyWith(
      undoStack: pushResult.undoStack,
      redoStack: pushResult.redoStack,
    );
  }

  void undo() {
    final result = _historyController.undo(
      undoStack: state.undoStack,
      redoStack: state.redoStack,
      currentGrid: state.grid,
    );
    if (result != null) {
      state = state.copyWith(
        grid: result.grid,
        undoStack: result.undoStack,
        redoStack: result.redoStack,
      );
    }
  }

  void redo() {
    final result = _historyController.redo(
      undoStack: state.undoStack,
      redoStack: state.redoStack,
      currentGrid: state.grid,
    );
    if (result != null) {
      state = state.copyWith(
        grid: result.grid,
        undoStack: result.undoStack,
        redoStack: result.redoStack,
      );
    }
  }

  // Drawing implementations
  void drawPixel(int x, int y, {bool preview = false}) {
    if (x < 0 || x >= state.gridSize || y < 0 || y >= state.gridSize) return;
    if (!preview) {
      _pushToUndo(state.grid);
    }
    final newGrid = _drawingHandler.drawPixel(
      state.grid,
      x,
      y,
      state.selectedColorIndex,
      state.gridSize,
    );
    if (newGrid != null) {
      state = state.copyWith(grid: newGrid);
    }
  }

  void _executeCommand(DrawingCommand command) {
    _pushToUndo(state.grid);
    final newGrid = _drawingHandler.executeCommand(
      state.grid,
      command,
      state.selectedColorIndex,
      state.gridSize,
    );
    state = state.copyWith(grid: newGrid);
  }

  void applyLine(int x1, int y1, int x2, int y2) =>
      _executeCommand(LineCommand(x1, y1, x2, y2));
  void applyCircle(num cx, num cy, num r) =>
      _executeCommand(CircleCommand(cx, cy, r));
  void applyCircleFilled(num cx, num cy, num r) =>
      _executeCommand(CircleFilledCommand(cx, cy, r));
  void applyCircleHatched(num cx, num cy, num r) =>
      _executeCommand(CircleHatchedCommand(cx, cy, r));
  void applyRectangle(int x1, int y1, int x2, int y2) =>
      _executeCommand(RectangleCommand(x1, y1, x2, y2));
  void applyRectangleFilled(int x1, int y1, int x2, int y2) =>
      _executeCommand(RectangleFilledCommand(x1, y1, x2, y2));
  void applyRectangleHatched(int x1, int y1, int x2, int y2) =>
      _executeCommand(RectangleHatchedCommand(x1, y1, x2, y2));
  void applyFill(int startX, int startY) =>
      _executeCommand(FillCommand(startX, startY));
  void applyHatch(int startX, int startY) =>
      _executeCommand(HatchCommand(startX, startY));

  // Triggering next stroke from AI service
  Future<void> triggerAiStroke() async {
    // Painter agent strokes suggestion is currently disabled until PainterAgent is implemented.
  }

  Future<void> triggerDecomposition() async {
    if (!mounted || state.isGenerating) return;
    state = state.copyWith(isGenerating: true);

    try {
      final res = await _decompositionOrchestrator.decompose(
        gridSize: state.gridSize,
        activePalette: state.palette,
        userPrompt: state.userPrompt,
        currentGrid: state.grid,
        referenceImage: state.referenceImage,
      );

      if (!mounted) return;
      final willStop = state.isPausing;
      state = state.copyWith(
        decomposedComponents: res.components,
        pendingDecompositionOptions: const [],
        isGenerating: false,
        autoRun: willStop ? false : state.autoRun,
        isPausing: false,
      );
      _scheduleSave();
    } catch (e) {
      debugPrint('Error triggering decomposer: $e');
      if (!mounted) return;
      state = state.copyWith(
        isGenerating: false,
        autoRun: false,
        isPausing: false,
      );
    }
  }

  void clearAiHistory() {
    state = state.copyWith(aiHistory: const []);
  }

  void resetComponentGrid(int index) {
    if (index >= 0 && index < state.decomposedComponents.length) {
      final updated = List<PixelArtComponent>.from(state.decomposedComponents);
      updated[index] = updated[index].copyWith(grid: null, isSculpted: false);
      state = state.copyWith(decomposedComponents: updated);
    }
  }

  void toggleComponentPixel(int compIndex, int x, int y, int value) {
    if (state.isGenerating) return;
    if (compIndex >= 0 && compIndex < state.decomposedComponents.length) {
      final updated = List<PixelArtComponent>.from(state.decomposedComponents);
      final comp = updated[compIndex];
      if (comp.grid != null) {
        final newGrid = List<List<int>>.from(
          comp.grid!.map((row) => List<int>.from(row)),
        );
        newGrid[y][x] = value;
        updated[compIndex] = comp.copyWith(grid: newGrid, isSculpted: true);
        state = state.copyWith(decomposedComponents: updated);
      }
    }
  }

  Future<void> sculptComponent(int index) async {
    if (!mounted ||
        state.isGenerating ||
        index < 0 ||
        index >= state.decomposedComponents.length) {
      return;
    }
    state = state.copyWith(
      isGenerating: true,
      decomposingComponentIndex: index,
      activeComponentIndex: index,
      sculptingStatus: 'Sculpting shape...',
    );

    try {
      final orchestrator = SketchOrchestrator(_aiService);
      final updatedComponents = await orchestrator.sketchSingleComponent(
        components: state.decomposedComponents,
        targetIndex: index,
        gridSize: state.gridSize,
        palette: state.palette,
        userPrompt: state.userPrompt,
        autoRunSpeed: state.autoRunSpeed,
        onStep: (activeIndex, updated, status) {
          if (!mounted) return;
          state = state.copyWith(
            decomposingComponentIndex: activeIndex,
            activeComponentIndex: activeIndex,
            sculptingStatus: status,
            decomposedComponents: List.from(updated),
          );
        },
        onLogHistory: (log) {
          if (!mounted) return;
          final newHistory = List<AgentHistoryEntry>.from(state.aiHistory);
          newHistory.add(log);
          state = state.copyWith(aiHistory: newHistory);
        },
        isShouldStop: () => !mounted || state.isPausing,
      );

      if (!mounted) return;
      final willStop = state.isPausing;
      state = state.copyWith(
        decomposedComponents: updatedComponents,
        isGenerating: false,
        autoRun: willStop ? false : state.autoRun,
        isPausing: false,
        clearDecomposingComponent: true,
        clearSculptingStatus: true,
      );
      _scheduleSave();
    } catch (e) {
      debugPrint('Error sculpting component: $e');
      if (!mounted) return;
      state = state.copyWith(
        isGenerating: false,
        autoRun: false,
        isPausing: false,
        clearDecomposingComponent: true,
        clearSculptingStatus: true,
      );
    }
  }

  Future<void> sculptComponents() async {
    if (!mounted || state.isGenerating || state.decomposedComponents.isEmpty) {
      return;
    }
    state = state.copyWith(isGenerating: true);

    try {
      final updatedComponents = await _sculptingOrchestrator
          .sculptAllComponents(
            components: state.decomposedComponents,
            gridSize: state.gridSize,
            activePalette: state.palette,
            userPrompt: state.userPrompt,
            onStep: (activeIndex, updated, status) {
              if (!mounted) return;
              state = state.copyWith(
                decomposingComponentIndex: activeIndex,
                activeComponentIndex: activeIndex,
                sculptingStatus: status,
                decomposedComponents: List.from(updated),
              );
            },
          );

      if (!mounted) return;
      state = state.copyWith(
        decomposedComponents: updatedComponents,
        isGenerating: false,
        clearDecomposingComponent: true,
        clearSculptingStatus: true,
      );
    } catch (e) {
      debugPrint('Error sculpting components: $e');
      if (!mounted) return;
      state = state.copyWith(
        isGenerating: false,
        autoRun: false,
        isPausing: false,
        clearDecomposingComponent: true,
        clearSculptingStatus: true,
      );
      _scheduleSave();
    }
  }

  Future<void> sketchComponents() async {
    if (!mounted || state.isGenerating || state.decomposedComponents.isEmpty) {
      return;
    }
    state = state.copyWith(
      isGenerating: true,
      sculptingStatus: 'Sculpting shape...',
    );

    try {
      final orchestrator = SketchOrchestrator(_aiService);
      final result = await orchestrator.sketch(
        components: state.decomposedComponents,
        gridSize: state.gridSize,
        palette: state.palette,
        userPrompt: state.userPrompt,
        autoRunSpeed: state.autoRunSpeed,
        onStep: (activeIndex, updated, status) {
          if (!mounted) return;
          state = state.copyWith(
            activeComponentIndex: activeIndex,
            decomposedComponents: updated,
            sculptingStatus: status,
          );
        },
        onLogHistory: (log) {
          if (!mounted) return;
          final newHistory = List<AgentHistoryEntry>.from(state.aiHistory);
          newHistory.add(log);
          state = state.copyWith(aiHistory: newHistory);
        },
        isShouldStop: () => !mounted || state.isPausing,
      );

      if (!mounted) return;
      final willStop = state.isPausing;
      state = state.copyWith(
        decomposedComponents: result,
        isGenerating: false,
        autoRun: willStop ? false : state.autoRun,
        isPausing: false,
        clearSculptingStatus: true,
      );
      _scheduleSave();
    } catch (e) {
      debugPrint('Error in sketching components: $e');
      if (!mounted) return;
      state = state.copyWith(
        isGenerating: false,
        autoRun: false,
        isPausing: false,
        clearSculptingStatus: true,
      );
      _scheduleSave();
    }
  }

  void mergeComponentsToCanvas() {
    final newGrid = List.generate(
      state.gridSize,
      (_) => List.filled(state.gridSize, 0),
    );

    final paletteMap = <int, int>{};
    for (int i = 0; i < state.palette.length; i++) {
      paletteMap[state.palette[i].toARGB32()] = i + 1;
    }

    for (final comp in state.decomposedComponents) {
      bool drewAnything = false;
      final outline = comp.getOutlineGrid();

      // 1. Draw fill if set
      if (comp.fillColor != null && comp.grid != null) {
        for (int y = 0; y < state.gridSize; y++) {
          for (int x = 0; x < state.gridSize; x++) {
            if (comp.grid![y][x] > 0) {
              final col = comp.getPixelFillColor(x, y);
              if (col != null) {
                final colorIndex = paletteMap[col.toARGB32()];
                if (colorIndex != null) {
                  newGrid[y][x] = colorIndex;
                  drewAnything = true;
                }
              }
            }
          }
        }
      }

      // 2. Draw outline if set
      if (comp.outlineColor != null && outline != null) {
        final colorIndex = paletteMap[comp.outlineColor!.toARGB32()];
        if (colorIndex != null) {
          for (int y = 0; y < state.gridSize; y++) {
            for (int x = 0; x < state.gridSize; x++) {
              if (outline[y][x] > 0) {
                newGrid[y][x] = colorIndex;
                drewAnything = true;
              }
            }
          }
        }
      }

      // 3. Fallback: if no custom colors were set, draw the outline using the selected/default color index
      if (!drewAnything && outline != null) {
        final targetColorIndex = state.selectedColorIndex > 0
            ? state.selectedColorIndex
            : 1;
        for (int y = 0; y < state.gridSize; y++) {
          for (int x = 0; x < state.gridSize; x++) {
            if (outline[y][x] > 0) {
              newGrid[y][x] = targetColorIndex;
            }
          }
        }
      }
    }

    _pushToUndo(state.grid);
    state = state.copyWith(grid: newGrid);
  }

  void setAutoRunState({required bool autoRun, required bool isPausing}) {
    state = state.copyWith(autoRun: autoRun, isPausing: isPausing);
  }

  Future<void> startAutoPlay([WizardNotifier? targetWizardNotifier]) async {
    final activeWizardNotifier = targetWizardNotifier ?? wizardNotifier;
    if (activeWizardNotifier == null) return;
    await _autoPlayController.startAutoPlay(this, activeWizardNotifier);
  }

  void stopAutoPlay() {
    if (!state.autoRun && !state.isPausing) return;

    if (state.isGenerating ||
        state.isSuggestingDescription ||
        state.isSuggestingPalette) {
      state = state.copyWith(isPausing: true);
    } else {
      state = state.copyWith(autoRun: false, isPausing: false);
    }
  }

  void toggleAutoRun() {
    if (state.autoRun) {
      stopAutoPlay();
    }
  }

  void reorderComponents(int oldIndex, int newIndex) {
    final list = List<PixelArtComponent>.from(state.decomposedComponents);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex < 0 || newIndex > list.length) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(decomposedComponents: list);
    _scheduleSave();
  }

  Future<void> refineCanvas(String refinementPrompt) async {
    if (!mounted || state.isGenerating) return;
    state = state.copyWith(isGenerating: true);

    try {
      final orchestrator = RefinementOrchestrator(_aiService);
      final promptToUse = refinementPrompt.trim().isNotEmpty
          ? refinementPrompt
          : state.userPrompt;
      final result = await orchestrator.refine(
        initialGrid: state.grid,
        gridSize: state.gridSize,
        palette: state.palette,
        userPrompt: promptToUse,
        autoRunSpeed: state.autoRunSpeed,
        referenceImage: state.referenceImage,
        onStep: (updatedGrid) {
          if (!mounted) return;
          state = state.copyWith(grid: updatedGrid);
        },
        onLogHistory: (log) {
          if (!mounted) return;
          final newHistory = List<AgentHistoryEntry>.from(state.aiHistory);
          newHistory.add(log);
          state = state.copyWith(aiHistory: newHistory);
        },
        isShouldStop: () => !mounted || state.isPausing,
      );

      if (!mounted) return;
      _pushToUndo(state.grid);
      final willStop = state.isPausing;
      state = state.copyWith(
        grid: result,
        isGenerating: false,
        autoRun: willStop ? false : state.autoRun,
        isPausing: false,
      );
      _scheduleSave();
    } catch (e) {
      debugPrint('Error refining canvas: $e');
      if (!mounted) return;
      state = state.copyWith(
        isGenerating: false,
        autoRun: false,
        isPausing: false,
      );
    }
  }
}

final canvasStateProvider = StateNotifierProvider<CanvasNotifier, CanvasModel>((
  ref,
) {
  final aiService = ref.read(loggingAiServiceProvider);
  final wizardNotifier = ref.read(wizardStateProvider.notifier);
  final repository = ref.read(canvasRepositoryProvider);
  final notifier = CanvasNotifier(
    aiService,
    wizardNotifier: wizardNotifier,
    repository: repository,
  );
  ref.listen<AiService>(loggingAiServiceProvider, (_, newService) {
    notifier.updateAiService(newService);
  });
  return notifier;
});

final isDraggingCanvasProvider = StateProvider<bool>((ref) => false);

enum CanvasScaleMode { full, scaled1x, scaled4x }

final canvasScaleModeProvider = StateProvider<CanvasScaleMode>(
  (ref) => CanvasScaleMode.full,
);
