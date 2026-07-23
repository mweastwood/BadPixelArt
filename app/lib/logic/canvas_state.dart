import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'prompts.dart';
import 'drawing_commands.dart';
import 'algorithms/k_means_quantizer.dart';
import 'agents/base_agent.dart';
import 'agents/decomposer_agent.dart';
import 'agents/shape_sculpter_agent.dart';
import 'orchestrators/sketch_orchestrator.dart';
import 'orchestrators/refinement_orchestrator.dart';
import 'utils/bmp_utils.dart';
import 'models/color_palette.dart';
import 'models/canvas_model.dart';
import 'utils/logging_ai_service.dart';
import 'package:drift/drift.dart' as drift;
import 'utils/database.dart';
import 'utils/database_helpers.dart';

export 'utils/bmp_utils.dart';
export 'models/canvas_model.dart';
export 'models/pixel_art_component.dart';

abstract class AgentCanvas {
  List<List<int>> get grid;
  List<Color> get palette;
  void applyCommand(String toolName, List<int> params, int colorIndex);
  Uint8List generateCombinedVisualInput(
    Uint8List? referenceBmp,
    Uint8List? previousBmp,
  );
}

class CanvasNotifier extends StateNotifier<CanvasModel> implements AgentCanvas {
  AiService _aiService;
  Timer? _autoRunTimer;
  Completer<bool>? _confirmationCompleter;

  static const int gridSize = 16;

  @override
  List<List<int>> get grid => state.grid;

  @override
  List<Color> get palette => state.palette;

  @override
  void applyCommand(String toolName, List<int> params, int colorIndex) {
    final boundedColorIndex = colorIndex.clamp(0, state.palette.length);
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

  List<List<Color>> _downscaleColorGrid(
    List<List<Color>> original,
    int targetSize,
  ) {
    final List<List<Color>> result = List.generate(
      targetSize,
      (_) => List.filled(targetSize, const Color(0xFF000000)),
    );
    final double scale = original.length / targetSize;
    for (int y = 0; y < targetSize; y++) {
      final int srcY = (y * scale).toInt().clamp(0, original.length - 1);
      for (int x = 0; x < targetSize; x++) {
        final int srcX = (x * scale).toInt().clamp(0, original[0].length - 1);
        result[y][x] = original[srcY][srcX];
      }
    }
    return result;
  }

  @override
  Uint8List generateCombinedVisualInput(
    Uint8List? referenceBmp,
    Uint8List? previousBmp,
  ) {
    final List<Uint8List> bmpsToCombine = [];

    if (referenceBmp != null) {
      var refGrid = bmpToColorGrid(referenceBmp);
      if (refGrid.length != state.gridSize) {
        refGrid = _downscaleColorGrid(refGrid, state.gridSize);
      }
      final blurredGrid = applyGaussianBlur(refGrid);
      final quantizedGrid = applyColorQuantization(blurredGrid, state.palette);
      final quantizedBmp = bmpFromColorGrid(quantizedGrid);
      bmpsToCombine.add(quantizedBmp);
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
    if (_isRestoring) return;
    final db = AppDatabaseHelper.db;
    final now = DateTime.now();

    final creationsCompanion = CreationsCompanion(
      title: drift.Value(state.title),
      gridSize: drift.Value(state.gridSize),
      gridData: drift.Value(serializeGrid(state.grid)),
      paletteName: drift.Value(state.paletteName),
      paletteColors: drift.Value(serializePalette(state.palette)),
      decomposedComponents: drift.Value(
        serializeComponents(state.decomposedComponents),
      ),
      aiHistoryLogs: drift.Value(serializeHistory(state.aiHistory)),
      referenceImage: drift.Value(state.referenceImage),
      originalReferenceImage: drift.Value(state.originalReferenceImage),
      updatedAt: drift.Value(now),
    );

    if (state.creationId == null) {
      _isRestoring = true;
      try {
        final newCompanion = creationsCompanion.copyWith(
          createdAt: drift.Value(now),
        );
        final newId = await db.createCreation(newCompanion);
        state = state.copyWith(creationId: newId);
      } finally {
        _isRestoring = false;
      }
    } else {
      final updateCompanion = creationsCompanion.copyWith(
        id: drift.Value(state.creationId!),
      );
      await db.updateCreation(updateCompanion);
    }

    final sessionCompanion = WorkspaceSessionsCompanion(
      id: const drift.Value(1),
      activeCreationId: drift.Value(state.creationId),
      selectedColorIndex: drift.Value(state.selectedColorIndex),
      selectedTool: drift.Value(state.selectedTool.name),
      userPrompt: drift.Value(state.userPrompt),
      lastSavedAt: drift.Value(now),
    );
    await db.saveSession(sessionCompanion);
  }

  Future<void> loadFromDb(int id) async {
    _isRestoring = true;
    try {
      final db = AppDatabaseHelper.db;
      final creation = await db.getCreationById(id);
      if (creation == null) return;

      final grid = deserializeGrid(creation.gridData);
      final palette = deserializePalette(creation.paletteColors);
      final components = deserializeComponents(creation.decomposedComponents);
      final history = deserializeHistory(creation.aiHistoryLogs);

      if (state.autoRun) {
        _autoRunTimer?.cancel();
      }

      state = state.copyWith(
        creationId: creation.id,
        title: creation.title,
        gridSize: creation.gridSize,
        grid: grid,
        paletteName: creation.paletteName,
        palette: palette,
        decomposedComponents: components,
        aiHistory: history,
        referenceImage: creation.referenceImage,
        originalReferenceImage: creation.originalReferenceImage,
        undoStack: const [],
        redoStack: const [],
        autoRun: false,
      );

      final now = DateTime.now();
      final sessionCompanion = WorkspaceSessionsCompanion(
        id: const drift.Value(1),
        activeCreationId: drift.Value(creation.id),
        selectedColorIndex: drift.Value(state.selectedColorIndex),
        selectedTool: drift.Value(state.selectedTool.name),
        userPrompt: drift.Value(state.userPrompt),
        lastSavedAt: drift.Value(now),
      );
      await db.saveSession(sessionCompanion);
    } finally {
      _isRestoring = false;
    }
  }

  Future<void> loadLastSession() async {
    _isRestoring = true;
    try {
      final db = AppDatabaseHelper.db;
      final session = await db.getSession();
      if (session != null && session.activeCreationId != null) {
        final creation = await db.getCreationById(session.activeCreationId!);
        if (creation != null) {
          final grid = deserializeGrid(creation.gridData);
          final palette = deserializePalette(creation.paletteColors);
          final components = deserializeComponents(
            creation.decomposedComponents,
          );
          final history = deserializeHistory(creation.aiHistoryLogs);

          final tool = CanvasTool.values.firstWhere(
            (t) => t.name == session.selectedTool,
            orElse: () => CanvasTool.line,
          );

          state = state.copyWith(
            creationId: creation.id,
            title: creation.title,
            gridSize: creation.gridSize,
            grid: grid,
            paletteName: creation.paletteName,
            palette: palette,
            decomposedComponents: components,
            aiHistory: history,
            referenceImage: creation.referenceImage,
            originalReferenceImage: creation.originalReferenceImage,
            selectedColorIndex: session.selectedColorIndex,
            selectedTool: tool,
            userPrompt: session.userPrompt,
            undoStack: const [],
            redoStack: const [],
          );
        }
      }
    } finally {
      _isRestoring = false;
    }
  }

  Future<void> startNewCanvas() async {
    _isRestoring = true;
    try {
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

      final db = AppDatabaseHelper.db;
      final now = DateTime.now();
      final sessionCompanion = WorkspaceSessionsCompanion(
        id: const drift.Value(1),
        activeCreationId: const drift.Value.absent(),
        selectedColorIndex: drift.Value(state.selectedColorIndex),
        selectedTool: drift.Value(state.selectedTool.name),
        userPrompt: drift.Value(state.userPrompt),
        lastSavedAt: drift.Value(now),
      );
      await db.saveSession(sessionCompanion);
    } finally {
      _isRestoring = false;
    }
  }

  Future<void> duplicateCanvas(int id) async {
    final db = AppDatabaseHelper.db;
    final creation = await db.getCreationById(id);
    if (creation == null) return;

    final now = DateTime.now();
    final duplicateCompanion = CreationsCompanion(
      title: drift.Value('${creation.title} (Copy)'),
      gridSize: drift.Value(creation.gridSize),
      gridData: drift.Value(creation.gridData),
      paletteName: drift.Value(creation.paletteName),
      paletteColors: drift.Value(creation.paletteColors),
      decomposedComponents: drift.Value(creation.decomposedComponents),
      aiHistoryLogs: drift.Value(creation.aiHistoryLogs),
      referenceImage: drift.Value(creation.referenceImage),
      originalReferenceImage: drift.Value(creation.originalReferenceImage),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    );

    final newId = await db.createCreation(duplicateCompanion);
    await loadFromDb(newId);
  }

  Future<void> renameCanvas(String newTitle) async {
    state = state.copyWith(title: newTitle);
    await saveToDb();
  }

  Future<void> deleteCanvas(int id) async {
    final db = AppDatabaseHelper.db;
    await db.deleteCreation(id);

    if (state.creationId == id) {
      final creationsList = await db.getAllCreations();
      if (creationsList.isNotEmpty) {
        await loadFromDb(creationsList.first.id);
      } else {
        await startNewCanvas();
      }
    }
  }

  void updateAiService(AiService newAiService) {
    _aiService = newAiService;
    if (_aiService is LoggingAiService) {
      (_aiService as LoggingAiService).onLog = (entry) {
        state = state.copyWith(aiHistory: [...state.aiHistory, entry]);
      };
    }
  }

  CanvasNotifier(this._aiService, {CanvasModel? initialModel})
    : super(
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
    if (_aiService is LoggingAiService) {
      (_aiService as LoggingAiService).onLog = (entry) {
        state = state.copyWith(aiHistory: [...state.aiHistory, entry]);
      };
    }
    _initModelConfig();
  }

  void changeResolution(int newSize) {
    if (newSize != 8 && newSize != 16) return;
    state = state.copyWith(
      gridSize: newSize,
      grid: List.generate(newSize, (_) => List.filled(newSize, 0)),
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

  void updateComponentColors(int index, Color? fillColor, Color? outlineColor) {
    if (index >= 0 && index < state.decomposedComponents.length) {
      final updated = List<PixelArtComponent>.from(state.decomposedComponents);
      updated[index] = updated[index].copyWith(
        fillColor: fillColor == null ? () => null : () => fillColor,
        outlineColor: outlineColor == null ? () => null : () => outlineColor,
      );
      state = state.copyWith(decomposedComponents: updated);
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
    await _aiService.setModelConfig(
      releaseStage: state.modelReleaseStage,
      preference: state.modelPreference,
    );
    await checkAiStatus();
  }

  Future<void> setModelConfig(String stage, String preference) async {
    state = state.copyWith(
      modelReleaseStage: stage,
      modelPreference: preference,
    );
    await _aiService.setModelConfig(
      releaseStage: stage,
      preference: preference,
    );
    await checkAiStatus();
  }

  @override
  void dispose() {
    _autoRunTimer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> checkAiStatus() async {
    final status = await _aiService.checkStatus();
    state = state.copyWith(aiStatus: status);
  }

  Future<void> triggerDownload() async {
    state = state.copyWith(aiStatus: AiCoreStatus.downloading);
    await _aiService.triggerDownload();
    await checkAiStatus();
  }

  void selectPalette(String name) {
    final newPalette = PaletteRegistry.getById(name).colors;

    state = state.copyWith(
      paletteName: name,
      palette: newPalette,
      selectedColorIndex: 1,
    );
    resetCanvas();
  }

  void selectColor(int index) {
    if (index >= 0 && index <= state.palette.length) {
      state = state.copyWith(selectedColorIndex: index);
    }
  }

  void selectTool(CanvasTool tool) {
    state = state.copyWith(selectedTool: tool);
  }

  void updatePrompt(String prompt) {
    state = state.copyWith(userPrompt: prompt);
  }

  void setReferenceImage(Uint8List? bytes, {Uint8List? originalBytes}) {
    if (bytes == null) {
      state = state.copyWith(
        clearReference: true,
        clearSuggestedPalette: true,
        showPaletteSuggestion: false,
        clearNextFocus: true,
      );
    } else {
      state = state.copyWith(
        referenceImage: bytes,
        originalReferenceImage: originalBytes,
      );
    }
  }

  Future<void> setUploadedReferenceImage(Uint8List rawBytes) async {
    final bmp = await resizeAndConvertToBmp(rawBytes, 512);
    if (bmp != null) {
      state = state.copyWith(
        referenceImage: bmp,
        originalReferenceImage: rawBytes,
      );
    }
  }

  Future<void> suggestPaletteFromReference() async {
    final refImg = state.referenceImage;
    if (refImg == null) return;

    state = state.copyWith(
      isSuggestingPalette: true,
      showPaletteSuggestion: false,
    );

    try {
      final colors = await _aiService.suggestPalette(refImg);
      if (colors != null) {
        state = state.copyWith(
          suggestedPalette: colors,
          showPaletteSuggestion: true,
        );
      }
    } catch (e) {
      debugPrint('Error suggesting palette: $e');
    } finally {
      state = state.copyWith(isSuggestingPalette: false);
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
    final clonedGrid = currentGrid.map((row) => List<int>.from(row)).toList();
    final newUndo = List<List<List<int>>>.from(state.undoStack)
      ..add(clonedGrid);
    state = state.copyWith(
      undoStack: newUndo,
      redoStack: [], // Clear redo stack on new operation
    );
  }

  void undo() {
    if (state.undoStack.isEmpty) return;

    final newUndo = List<List<List<int>>>.from(state.undoStack);
    final previousGrid = newUndo.removeLast();

    final currentCloned = state.grid.map((row) => List<int>.from(row)).toList();
    final newRedo = List<List<List<int>>>.from(state.redoStack)
      ..add(currentCloned);

    state = state.copyWith(
      grid: previousGrid,
      undoStack: newUndo,
      redoStack: newRedo,
    );
  }

  void redo() {
    if (state.redoStack.isEmpty) return;

    final newRedo = List<List<List<int>>>.from(state.redoStack);
    final nextGrid = newRedo.removeLast();

    final currentCloned = state.grid.map((row) => List<int>.from(row)).toList();
    final newUndo = List<List<List<int>>>.from(state.undoStack)
      ..add(currentCloned);

    state = state.copyWith(
      grid: nextGrid,
      undoStack: newUndo,
      redoStack: newRedo,
    );
  }

  // Drawing implementations
  void drawPixel(int x, int y, {bool preview = false}) {
    if (x < 0 || x >= state.gridSize || y < 0 || y >= state.gridSize) return;
    if (!preview) {
      _pushToUndo(state.grid);
    }
    final newGrid = state.grid.map((row) => List<int>.from(row)).toList();
    newGrid[y][x] = state.selectedColorIndex;
    state = state.copyWith(grid: newGrid);
  }

  void _executeCommand(DrawingCommand command) {
    _pushToUndo(state.grid);
    final newGrid = state.grid.map((row) => List<int>.from(row)).toList();
    command.execute(newGrid, state.selectedColorIndex, state.gridSize);
    state = state.copyWith(grid: newGrid);
  }

  void applyLine(int x1, int y1, int x2, int y2) =>
      _executeCommand(LineCommand(x1, y1, x2, y2));
  void applyCircle(int cx, int cy, int r) =>
      _executeCommand(CircleCommand(cx, cy, r));
  void applyCircleFilled(int cx, int cy, int r) =>
      _executeCommand(CircleFilledCommand(cx, cy, r));
  void applyCircleHatched(int cx, int cy, int r) =>
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

  // Core algorithms

  // Triggering next stroke from AI service
  Future<void> triggerAiStroke() async {
    // Painter agent strokes suggestion is currently disabled until PainterAgent is implemented.
  }

  Future<void> triggerDecomposition() async {
    if (state.isGenerating) return;
    state = state.copyWith(isGenerating: true);

    try {
      final agent = DecomposerAgent();
      final context = AgentContext(
        gridSize: state.gridSize,
        activePalette: state.palette,
        userPrompt: state.userPrompt,
        currentGrid: state.grid,
        referenceImage: state.referenceImage,
      );

      // Perform 4 concurrent calls to the AI service
      final results = await Future.wait([
        agent.decompose(_aiService, context),
        agent.decompose(_aiService, context),
        agent.decompose(_aiService, context),
        agent.decompose(_aiService, context),
      ]);

      final List<List<PixelArtComponent>> options = [];

      for (int i = 0; i < results.length; i++) {
        final res = results[i];
        options.add(res.components);
      }

      state = state.copyWith(
        pendingDecompositionOptions: options,
        isGenerating: false,
      );
    } catch (e) {
      debugPrint('Error triggering decomposer: $e');
      state = state.copyWith(isGenerating: false);
    }
  }

  void clearAiHistory() {
    state = state.copyWith(aiHistory: const []);
  }

  void respondToConfirmation(bool approved) {
    if (_confirmationCompleter != null &&
        !_confirmationCompleter!.isCompleted) {
      _confirmationCompleter!.complete(approved);
    }
    state = state.copyWith(clearConfirmingComponent: true);
  }

  void resetComponentGrid(int index) {
    if (index >= 0 && index < state.decomposedComponents.length) {
      final updated = List<PixelArtComponent>.from(state.decomposedComponents);
      updated[index] = updated[index].copyWith(grid: null);
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
        updated[compIndex] = comp.copyWith(grid: newGrid);
        state = state.copyWith(decomposedComponents: updated);
      }
    }
  }

  Future<void> sculptComponent(int index) async {
    if (state.isGenerating ||
        index < 0 ||
        index >= state.decomposedComponents.length) {
      return;
    }
    state = state.copyWith(
      isGenerating: true,
      decomposingComponentIndex: index,
      activeComponentIndex: index,
    );

    try {
      final List<PixelArtComponent> updatedComponents = List.from(
        state.decomposedComponents,
      );
      var comp = updatedComponents[index];

      comp = comp.initializeDefaultGrid(state.gridSize);

      final agent = ShapeSculpterAgent();
      final context = AgentContext(
        gridSize: state.gridSize,
        activePalette: state.palette,
        userPrompt: state.userPrompt,
        targetComponent: comp,
        currentGrid: state.grid,
        referenceImage: state.referenceImage,
        allComponents: state.decomposedComponents,
      );

      final newGrid = await agent.sculptComponent(_aiService, context);
      updatedComponents[index] = comp.copyWith(grid: newGrid);

      state = state.copyWith(
        decomposedComponents: updatedComponents,
        isGenerating: false,
        clearDecomposingComponent: true,
      );
    } catch (e) {
      debugPrint('Error sculpting component: $e');
      state = state.copyWith(
        isGenerating: false,
        clearDecomposingComponent: true,
      );
    }
  }

  Future<void> sculptComponents() async {
    if (state.isGenerating || state.decomposedComponents.isEmpty) return;
    state = state.copyWith(isGenerating: true);

    try {
      final List<PixelArtComponent> updatedComponents = List.from(
        state.decomposedComponents,
      );
      final agent = ShapeSculpterAgent();

      for (int i = 0; i < updatedComponents.length; i++) {
        state = state.copyWith(
          decomposingComponentIndex: i,
          activeComponentIndex: i,
        );
        var comp = updatedComponents[i];

        comp = comp.initializeDefaultGrid(state.gridSize);

        final context = AgentContext(
          gridSize: state.gridSize,
          activePalette: state.palette,
          userPrompt: state.userPrompt,
          targetComponent: comp,
          currentGrid: state.grid,
          allComponents: state.decomposedComponents,
        );

        final newGrid = await agent.sculptComponent(_aiService, context);
        updatedComponents[i] = comp.copyWith(grid: newGrid);

        state = state.copyWith(
          decomposedComponents: List.from(updatedComponents),
        );
      }

      state = state.copyWith(
        isGenerating: false,
        clearDecomposingComponent: true,
      );
    } catch (e) {
      debugPrint('Error sculpting components: $e');
      state = state.copyWith(
        isGenerating: false,
        clearDecomposingComponent: true,
      );
    }
  }

  Future<void> sketchComponents() async {
    if (state.isGenerating || state.decomposedComponents.isEmpty) return;
    state = state.copyWith(isGenerating: true);

    try {
      final orchestrator = SketchOrchestrator(_aiService);
      final result = await orchestrator.sketch(
        components: state.decomposedComponents,
        gridSize: state.gridSize,
        palette: state.palette,
        userPrompt: state.userPrompt,
        autoRunSpeed: state.autoRunSpeed,
        onStep: (activeIndex, updated) {
          state = state.copyWith(
            activeComponentIndex: activeIndex,
            decomposedComponents: updated,
          );
        },
        onLogHistory: (log) {
          final newHistory = List<AgentHistoryEntry>.from(state.aiHistory);
          newHistory.add(log);
          state = state.copyWith(aiHistory: newHistory);
        },
        onConfirmComponent: (index) async {
          _confirmationCompleter = Completer<bool>();
          state = state.copyWith(confirmingComponentIndex: index);
          final approved = await _confirmationCompleter!.future;
          _confirmationCompleter = null;
          return approved;
        },
      );

      state = state.copyWith(decomposedComponents: result, isGenerating: false);
    } catch (e) {
      debugPrint('Error in sketching components: $e');
      state = state.copyWith(isGenerating: false);
    }
  }

  void mergeComponentsToCanvas() {
    final newGrid = List.generate(
      state.gridSize,
      (_) => List.filled(state.gridSize, 0),
    );

    for (final comp in state.decomposedComponents) {
      bool drewAnything = false;

      // 1. Draw fill if set
      if (comp.fillColor != null && comp.grid != null) {
        final colorIndex = state.palette.indexWhere(
          (c) => c.toARGB32() == comp.fillColor!.toARGB32(),
        );
        if (colorIndex != -1) {
          final dbIndex = colorIndex + 1;
          for (int y = 0; y < state.gridSize; y++) {
            for (int x = 0; x < state.gridSize; x++) {
              if (comp.grid![y][x] > 0) {
                newGrid[y][x] = dbIndex;
                drewAnything = true;
              }
            }
          }
        }
      }

      // 2. Draw outline if set
      if (comp.outlineColor != null) {
        final outline = comp.getOutlineGrid();
        if (outline != null) {
          final colorIndex = state.palette.indexWhere(
            (c) => c.toARGB32() == comp.outlineColor!.toARGB32(),
          );
          if (colorIndex != -1) {
            final dbIndex = colorIndex + 1;
            for (int y = 0; y < state.gridSize; y++) {
              for (int x = 0; x < state.gridSize; x++) {
                if (outline[y][x] > 0) {
                  newGrid[y][x] = dbIndex;
                  drewAnything = true;
                }
              }
            }
          }
        }
      }

      // 3. Fallback: if no custom colors were set, draw the outline using the selected/default color index
      if (!drewAnything) {
        final outline = comp.getOutlineGrid();
        if (outline != null) {
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
    }

    _pushToUndo(state.grid);
    state = state.copyWith(grid: newGrid);
  }

  void toggleAutoRun() {
    final nextAutoRun = !state.autoRun;
    state = state.copyWith(autoRun: nextAutoRun);
    if (nextAutoRun) {
      _startAutoRunLoop();
    } else {
      _autoRunTimer?.cancel();
    }
  }

  void updateSpeed(double speed) {
    state = state.copyWith(autoRunSpeed: speed);
    if (state.autoRun) {
      _autoRunTimer?.cancel();
      _startAutoRunLoop();
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
    if (state.isGenerating) return;
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
        onStep: (updatedGrid) {
          state = state.copyWith(grid: updatedGrid);
        },
        onLogHistory: (log) {
          final newHistory = List<AgentHistoryEntry>.from(state.aiHistory);
          newHistory.add(log);
          state = state.copyWith(aiHistory: newHistory);
        },
      );

      _pushToUndo(state.grid);
      state = state.copyWith(grid: result, isGenerating: false);
      _scheduleSave();
    } catch (e) {
      debugPrint('Error refining canvas: $e');
      state = state.copyWith(isGenerating: false);
    }
  }

  void _startAutoRunLoop() {
    _autoRunTimer = Timer.periodic(
      Duration(milliseconds: (state.autoRunSpeed * 1000).toInt()),
      (timer) async {
        if (!state.isGenerating) {
          final lifecycle = WidgetsBinding.instance.lifecycleState;
          if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
            await triggerAiStroke();
          } else {
            debugPrint(
              'Skipping AI stroke: app is in background/inactive state ($lifecycle)',
            );
          }
        }
      },
    );
  }
}

final canvasStateProvider = StateNotifierProvider<CanvasNotifier, CanvasModel>((
  ref,
) {
  final aiService = ref.read(loggingAiServiceProvider);
  final notifier = CanvasNotifier(aiService);
  ref.listen<AiService>(loggingAiServiceProvider, (_, newService) {
    notifier.updateAiService(newService);
  });
  return notifier;
});

final isDraggingCanvasProvider = StateProvider<bool>((ref) => false);
