import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_agent/local_agent.dart';
import 'prompts.dart';
import 'drawing_commands.dart';
import 'algorithms/k_means_quantizer.dart';
import 'agents/base_agent.dart';
import 'agents/decomposer_agent.dart';
import 'agents/shape_sculpter_agent.dart';
import 'orchestrators/sketch_orchestrator.dart';
import 'utils/bmp_utils.dart';
import 'models/color_palette.dart';

export 'utils/bmp_utils.dart';

enum CanvasTool { line, circle, fill, hatch }

abstract class AgentCanvas {
  List<List<int>> get grid;
  List<Color> get palette;
  void applyCommand(String toolName, List<int> params, int colorIndex);
  Uint8List generateCombinedVisualInput(
    Uint8List? referenceBmp,
    Uint8List? previousBmp,
  );
}

@immutable
class CanvasModel {
  final int gridSize;
  final List<List<int>> grid;
  final int selectedColorIndex;
  final CanvasTool selectedTool;
  final String paletteName;
  final List<Color> palette;
  final Uint8List? referenceImage;
  final Uint8List? originalReferenceImage;
  final String userPrompt;
  final AiCoreStatus aiStatus;
  final bool isGenerating;
  final bool autoRun;
  final double autoRunSpeed; // in seconds
  final List<List<List<int>>> undoStack;
  final List<List<List<int>>> redoStack;
  final List<AgentHistoryEntry> aiHistory;
  final List<Color>? suggestedPalette;
  final bool isSuggestingPalette;
  final bool showPaletteSuggestion;
  final String? nextFocus;
  final String modelReleaseStage;
  final String modelPreference;
  final List<List<PixelArtComponent>> pendingDecompositionOptions;
  final List<PixelArtComponent> decomposedComponents;
  final int activeComponentIndex;
  final int? confirmingComponentIndex;
  final int? decomposingComponentIndex;

  const CanvasModel({
    this.gridSize = 16,
    required this.grid,
    required this.selectedColorIndex,
    required this.selectedTool,
    required this.paletteName,
    required this.palette,
    this.referenceImage,
    this.originalReferenceImage,
    required this.userPrompt,
    required this.aiStatus,
    required this.isGenerating,
    required this.autoRun,
    required this.autoRunSpeed,
    required this.undoStack,
    required this.redoStack,
    required this.aiHistory,
    this.suggestedPalette,
    this.isSuggestingPalette = false,
    this.showPaletteSuggestion = false,
    this.nextFocus,
    this.modelReleaseStage = 'stable',
    this.modelPreference = 'full',
    this.pendingDecompositionOptions = const [],
    this.decomposedComponents = const [],
    this.activeComponentIndex = 0,
    this.confirmingComponentIndex,
    this.decomposingComponentIndex,
  });

  CanvasModel copyWith({
    int? gridSize,
    List<List<int>>? grid,
    int? selectedColorIndex,
    CanvasTool? selectedTool,
    String? paletteName,
    List<Color>? palette,
    Uint8List? referenceImage,
    Uint8List? originalReferenceImage,
    bool clearReference = false,
    String? userPrompt,
    bool clearUserPrompt = false,
    AiCoreStatus? aiStatus,
    bool? isGenerating,
    bool? autoRun,
    double? autoRunSpeed,
    List<List<List<int>>>? undoStack,
    List<List<List<int>>>? redoStack,
    List<AgentHistoryEntry>? aiHistory,
    List<Color>? suggestedPalette,
    bool? isSuggestingPalette,
    bool? showPaletteSuggestion,
    bool clearSuggestedPalette = false,
    String? nextFocus,
    bool clearNextFocus = false,
    String? modelReleaseStage,
    String? modelPreference,
    List<List<PixelArtComponent>>? pendingDecompositionOptions,
    List<PixelArtComponent>? decomposedComponents,
    int? activeComponentIndex,
    int? confirmingComponentIndex,
    bool clearConfirmingComponent = false,
    int? decomposingComponentIndex,
    bool clearDecomposingComponent = false,
  }) {
    return CanvasModel(
      gridSize: gridSize ?? this.gridSize,
      grid: grid ?? this.grid,
      selectedColorIndex: selectedColorIndex ?? this.selectedColorIndex,
      selectedTool: selectedTool ?? this.selectedTool,
      paletteName: paletteName ?? this.paletteName,
      palette: palette ?? this.palette,
      referenceImage: clearReference
          ? null
          : (referenceImage ?? this.referenceImage),
      originalReferenceImage: clearReference
          ? null
          : (originalReferenceImage ?? this.originalReferenceImage),
      userPrompt: userPrompt ?? this.userPrompt,
      aiStatus: aiStatus ?? this.aiStatus,
      isGenerating: isGenerating ?? this.isGenerating,
      autoRun: autoRun ?? this.autoRun,
      autoRunSpeed: autoRunSpeed ?? this.autoRunSpeed,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      aiHistory: aiHistory ?? this.aiHistory,
      suggestedPalette: clearSuggestedPalette
          ? null
          : (suggestedPalette ?? this.suggestedPalette),
      isSuggestingPalette: isSuggestingPalette ?? this.isSuggestingPalette,
      showPaletteSuggestion:
          showPaletteSuggestion ?? this.showPaletteSuggestion,
      nextFocus: clearNextFocus ? null : (nextFocus ?? this.nextFocus),
      modelReleaseStage: modelReleaseStage ?? this.modelReleaseStage,
      modelPreference: modelPreference ?? this.modelPreference,
      pendingDecompositionOptions:
          pendingDecompositionOptions ?? this.pendingDecompositionOptions,
      decomposedComponents: decomposedComponents ?? this.decomposedComponents,
      activeComponentIndex: activeComponentIndex ?? this.activeComponentIndex,
      confirmingComponentIndex: clearConfirmingComponent
          ? null
          : (confirmingComponentIndex ?? this.confirmingComponentIndex),
      decomposingComponentIndex: clearDecomposingComponent
          ? null
          : (decomposingComponentIndex ?? this.decomposingComponentIndex),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CanvasModel) return false;
    return gridSize == other.gridSize &&
        selectedColorIndex == other.selectedColorIndex &&
        selectedTool == other.selectedTool &&
        paletteName == other.paletteName &&
        userPrompt == other.userPrompt &&
        aiStatus == other.aiStatus &&
        isGenerating == other.isGenerating &&
        autoRun == other.autoRun &&
        autoRunSpeed == other.autoRunSpeed &&
        isSuggestingPalette == other.isSuggestingPalette &&
        showPaletteSuggestion == other.showPaletteSuggestion &&
        activeComponentIndex == other.activeComponentIndex &&
        decomposingComponentIndex == other.decomposingComponentIndex &&
        listEquals(palette, other.palette) &&
        listEquals(suggestedPalette, other.suggestedPalette) &&
        listEquals(referenceImage, other.referenceImage) &&
        listEquals(originalReferenceImage, other.originalReferenceImage) &&
        listEquals(aiHistory, other.aiHistory) &&
        listEquals(decomposedComponents, other.decomposedComponents) &&
        listEquals(
          pendingDecompositionOptions,
          other.pendingDecompositionOptions,
        );
  }

  @override
  int get hashCode => Object.hash(
    gridSize,
    selectedColorIndex,
    selectedTool,
    paletteName,
    userPrompt,
    aiStatus,
    isGenerating,
    autoRun,
    autoRunSpeed,
    isSuggestingPalette,
    showPaletteSuggestion,
    activeComponentIndex,
    decomposingComponentIndex,
    Object.hashAll(palette),
    suggestedPalette != null ? Object.hashAll(suggestedPalette!) : null,
    referenceImage != null ? Object.hashAll(referenceImage!) : null,
    originalReferenceImage != null
        ? Object.hashAll(originalReferenceImage!)
        : null,
    Object.hashAll(aiHistory),
    Object.hashAll(decomposedComponents),
    Object.hashAll(pendingDecompositionOptions),
  );
}

class CanvasNotifier extends StateNotifier<CanvasModel> implements AgentCanvas {
  final AiService _aiService;
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

  CanvasNotifier(this._aiService)
    : super(
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
      _aiService.onLog = (entry) {
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
    );

    try {
      final List<PixelArtComponent> updatedComponents = List.from(
        state.decomposedComponents,
      );
      var comp = updatedComponents[index];

      // Initialize grid with filled bounding box if not already present
      if (comp.grid == null) {
        final gridSize = state.gridSize;
        final List<List<int>> newGrid = List.generate(
          gridSize,
          (_) => List.filled(gridSize, 0),
        );
        final bbox = comp.relativeBoundingBox;
        final leftCol = (bbox.left * gridSize).round().clamp(0, gridSize - 1);
        final topRow = (bbox.top * gridSize).round().clamp(0, gridSize - 1);
        final rightCol = ((bbox.left + bbox.width) * gridSize).round().clamp(
          0,
          gridSize,
        );
        final bottomRow = ((bbox.top + bbox.height) * gridSize).round().clamp(
          0,
          gridSize,
        );

        for (int y = topRow; y < bottomRow; y++) {
          for (int x = leftCol; x < rightCol; x++) {
            newGrid[y][x] = 1;
          }
        }
        comp = comp.copyWith(grid: newGrid);
      }

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
        state = state.copyWith(decomposingComponentIndex: i);
        var comp = updatedComponents[i];

        if (comp.grid == null) {
          final gridSize = state.gridSize;
          final List<List<int>> newGrid = List.generate(
            gridSize,
            (_) => List.filled(gridSize, 0),
          );
          final bbox = comp.relativeBoundingBox;
          final leftCol = (bbox.left * gridSize).round().clamp(0, gridSize - 1);
          final topRow = (bbox.top * gridSize).round().clamp(0, gridSize - 1);
          final rightCol = ((bbox.left + bbox.width) * gridSize).round().clamp(
            0,
            gridSize,
          );
          final bottomRow = ((bbox.top + bbox.height) * gridSize).round().clamp(
            0,
            gridSize,
          );

          for (int y = topRow; y < bottomRow; y++) {
            for (int x = leftCol; x < rightCol; x++) {
              newGrid[y][x] = 1;
            }
          }
          comp = comp.copyWith(grid: newGrid);
        }

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
      }

      state = state.copyWith(
        decomposedComponents: updatedComponents,
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

    final targetColorIndex = state.selectedColorIndex > 0
        ? state.selectedColorIndex
        : 1;

    for (final comp in state.decomposedComponents) {
      final outline = comp.getOutlineGrid();
      if (outline != null) {
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

class LoggingAiService implements AiService {
  final AiService _delegate;
  void Function(AgentHistoryEntry entry)? onLog;

  LoggingAiService(this._delegate);

  @override
  Future<AiCoreStatus> checkStatus() => _delegate.checkStatus();

  @override
  Future<void> triggerDownload() => _delegate.triggerDownload();

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) => _delegate.setModelConfig(
    releaseStage: releaseStage,
    preference: preference,
  );

  @override
  Future<AiResponse?> generateContentRaw({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    try {
      final response = await _delegate.generateContentRaw(
        prompt: prompt,
        imageBytes: imageBytes,
        temperature: temperature,
        maxOutputTokens: maxOutputTokens,
      );

      onLog?.call(
        AgentHistoryEntry(
          timestamp: DateTime.now(),
          prompt: prompt,
          response: response?.text ?? '',
          isError: response == null,
          imageBytes: imageBytes,
        ),
      );
      return response;
    } catch (e) {
      onLog?.call(
        AgentHistoryEntry(
          timestamp: DateTime.now(),
          prompt: prompt,
          response: e.toString(),
          isError: true,
          imageBytes: imageBytes,
        ),
      );
      rethrow;
    }
  }

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    final res = await generateContentRaw(
      prompt: prompt,
      imageBytes: imageBytes,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
    );
    return res?.text;
  }
}

final loggingAiServiceProvider = Provider<AiService>((ref) {
  final baseService = ref.watch(aiServiceProvider);
  return LoggingAiService(baseService);
});

final canvasStateProvider = StateNotifierProvider<CanvasNotifier, CanvasModel>((
  ref,
) {
  final aiService = ref.watch(loggingAiServiceProvider);
  return CanvasNotifier(aiService);
});

final isDraggingCanvasProvider = StateProvider<bool>((ref) => false);
