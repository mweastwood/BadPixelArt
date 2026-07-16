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
import 'orchestrators/sketch_orchestrator.dart';
import 'utils/bmp_utils.dart';

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

  @override
  Uint8List generateCombinedVisualInput(
    Uint8List? referenceBmp,
    Uint8List? previousBmp,
  ) {
    final List<Uint8List> bmpsToCombine = [];

    if (referenceBmp != null) {
      final refGrid = bmpToColorGrid(referenceBmp);
      final blurredGrid = applyGaussianBlur(refGrid);
      final quantizedGrid = applyColorQuantization(blurredGrid, state.palette);
      final quantizedBmp = bmpFromColorGrid(quantizedGrid);
      bmpsToCombine.add(quantizedBmp);
    }

    final currentBmp = previousBmp ?? generateBmp(state.grid, state.palette);
    bmpsToCombine.add(currentBmp);

    return combineBmps(bmpsToCombine);
  }

  static final List<Color> grayscalePalette = [
    const Color(0xFF000000), // Black
    const Color(0xFF555555), // Dark Gray
    const Color(0xFFAAAAAA), // Light Gray
    const Color(0xFFFFFFFF), // White
  ];

  static final List<Color> primaryPalette = [
    const Color(0xFF000000), // Black
    const Color(0xFFFFFFFF), // White
    const Color(0xFFFF0000), // Red
    const Color(0xFF00FF00), // Green
    const Color(0xFF0000FF), // Blue
    const Color(0xFFFFFF00), // Yellow
    const Color(0xFFFF00FF), // Magenta
    const Color(0xFF00FFFF), // Cyan
  ];

  static final List<Color> gameboyPalette = [
    const Color(0xFF0F380F),
    const Color(0xFF306230),
    const Color(0xFF8BAC0F),
    const Color(0xFF9BBC0F),
  ];

  static final List<Color> nesPalette = [
    const Color(0xFF000000), // Black
    const Color(0xFFFCBCB0), // Peach/Skin
    const Color(0xFFF06800), // Red/Orange
    const Color(0xFFF8B800), // Yellow
    const Color(0xFF00A800), // Green
    const Color(0xFF0058F8), // Blue
    const Color(0xFFD800CC), // Purple
    const Color(0xFFFFFFFF), // White
  ];

  static final List<Color> pico8Palette = [
    const Color(0xFF000000),
    const Color(0xFF1D2B53),
    const Color(0xFF7E2553),
    const Color(0xFF008751),
    const Color(0xFFAB5236),
    const Color(0xFF5F574F),
    const Color(0xFFC2C3C7),
    const Color(0xFFFFF1E8),
    const Color(0xFFFF004D),
    const Color(0xFFFFA300),
    const Color(0xFFFFEC27),
    const Color(0xFF00E436),
    const Color(0xFF29ADFF),
    const Color(0xFF83769C),
    const Color(0xFFFF77A8),
    const Color(0xFFFFCCAA),
  ];

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
    List<Color> newPalette = primaryPalette;
    if (name == 'grayscale') {
      newPalette = grayscalePalette;
    } else if (name == 'gameboy') {
      newPalette = gameboyPalette;
    } else if (name == 'nes') {
      newPalette = nesPalette;
    } else if (name == 'pico8') {
      newPalette = pico8Palette;
    }

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
    final bmp = await resizeAndConvertToBmp(rawBytes, state.gridSize);
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
      );

      // Perform 4 concurrent calls to the AI service
      final results = await Future.wait([
        agent.decompose(_aiService, context),
        agent.decompose(_aiService, context),
        agent.decompose(_aiService, context),
        agent.decompose(_aiService, context),
      ]);

      final List<List<PixelArtComponent>> options = [];
      final List<AgentHistoryEntry> newHistory = List.from(state.aiHistory);

      for (int i = 0; i < results.length; i++) {
        final res = results[i];
        options.add(res.components);

        newHistory.add(
          AgentHistoryEntry(
            timestamp: DateTime.now(),
            prompt: 'Decompose Option ${i + 1} Prompt:\n${res.rawPrompt}',
            response: 'Decompose Option ${i + 1} Response:\n${res.rawResponse}',
            isError: false,
            imageBytes: null,
          ),
        );
      }

      state = state.copyWith(
        pendingDecompositionOptions: options,
        aiHistory: newHistory,
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

final canvasStateProvider = StateNotifierProvider<CanvasNotifier, CanvasModel>((
  ref,
) {
  final aiService = ref.watch(aiServiceProvider);
  return CanvasNotifier(aiService);
});
