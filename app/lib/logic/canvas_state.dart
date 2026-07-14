// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' show pow, Random;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_agent/local_agent.dart';
import 'prompts.dart';
import 'drawing_commands.dart';
import 'agents/base_agent.dart';
import 'agents/agent_orchestrator.dart';
import 'commands/algorithmic_helpers.dart';
import 'bmp_helper.dart';
export 'bmp_helper.dart';

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
  final List<List<int>> grid;
  final int gridSize;
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
  final String aiProvider; // 'aicore' or 'ollama'
  final String ollamaBaseUrl;
  final String ollamaModelName;

  const CanvasModel({
    required this.grid,
    this.gridSize = 16,
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
    this.aiProvider = 'aicore',
    this.ollamaBaseUrl = 'http://127.0.0.1:11434',
    this.ollamaModelName = 'gemma4:e4b',
  });

  CanvasModel copyWith({
    List<List<int>>? grid,
    int? gridSize,
    int? selectedColorIndex,
    CanvasTool? selectedTool,
    String? paletteName,
    List<Color>? palette,
    Uint8List? referenceImage,
    Uint8List? originalReferenceImage,
    bool clearReference = false,
    String? userPrompt,
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
    String? aiProvider,
    String? ollamaBaseUrl,
    String? ollamaModelName,
  }) {
    return CanvasModel(
      grid: grid ?? this.grid,
      gridSize: gridSize ?? this.gridSize,
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
      aiProvider: aiProvider ?? this.aiProvider,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      ollamaModelName: ollamaModelName ?? this.ollamaModelName,
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
        listEquals(palette, other.palette) &&
        listEquals(suggestedPalette, other.suggestedPalette) &&
        listEquals(referenceImage, other.referenceImage) &&
        listEquals(originalReferenceImage, other.originalReferenceImage) &&
        listEquals(aiHistory, other.aiHistory);
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
    Object.hashAll(palette),
    suggestedPalette != null ? Object.hashAll(suggestedPalette!) : null,
    referenceImage != null ? Object.hashAll(referenceImage!) : null,
    originalReferenceImage != null
        ? Object.hashAll(originalReferenceImage!)
        : null,
    Object.hashAll(aiHistory),
  );
}

class CanvasNotifier extends StateNotifier<CanvasModel> implements AgentCanvas {
  final AiService _aiService;
  Timer? _autoRunTimer;
  OllamaAiService? _cachedOllamaService;

  AiService get activeAiService {
    if (state.aiProvider == 'ollama') {
      if (_cachedOllamaService == null ||
          _cachedOllamaService!.baseUrl != state.ollamaBaseUrl ||
          _cachedOllamaService!.modelName != state.ollamaModelName) {
        _cachedOllamaService = OllamaAiService(
          baseUrl: state.ollamaBaseUrl,
          modelName: state.ollamaModelName,
        );
      }
      return _cachedOllamaService!;
    }
    return _aiService;
  }

  static const int gridSize = 16;

  @override
  List<List<int>> get grid => state.grid;

  @override
  List<Color> get palette => state.palette;

  @override
  void applyCommand(String toolName, List<int> params, int colorIndex) {
    _applyAiStrokeCommand(toolName, params, colorIndex);
  }

  @override
  Uint8List generateCombinedVisualInput(
    Uint8List? referenceBmp,
    Uint8List? previousBmp,
  ) {
    final currentBmp = previousBmp ?? generateBmp(state.grid, state.palette);
    final List<Uint8List> bmpsToCombine = [];
    if (referenceBmp != null && referenceBmp.isNotEmpty) {
      bmpsToCombine.add(referenceBmp);
    }
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
    const Color(0xFF7C7C7C),
    const Color(0xFF0000FC),
    const Color(0xFF0000BC),
    const Color(0xFF4428BC),
    const Color(0xFF940084),
    const Color(0xFFA80020),
    const Color(0xFFA81000),
    const Color(0xFF881400),
    const Color(0xFF503000),
    const Color(0xFF007800),
    const Color(0xFF006800),
    const Color(0xFF005800),
    const Color(0xFF004058),
    const Color(0xFF000000),
    const Color(0xFF000000),
    const Color(0xFF000000),
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
          grid: List.generate(gridSize, (_) => List.filled(gridSize, 0)),
          gridSize: 16,
          selectedColorIndex: 1,
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
    if (!mounted) return;
    state = state.copyWith(aiStatus: status);
  }

  Future<void> triggerDownload() async {
    state = state.copyWith(aiStatus: AiCoreStatus.downloading);
    await _aiService.triggerDownload();
    await checkAiStatus();
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
      );
    } else {
      state = state.copyWith(
        referenceImage: bytes,
        originalReferenceImage: originalBytes,
      );
      suggestPaletteFromReference();
    }
  }

  Future<void> setUploadedReferenceImage(Uint8List rawBytes) async {
    final bmp = await resizeAndConvertToBmp(rawBytes, state.gridSize);
    if (bmp != null) {
      state = state.copyWith(
        referenceImage: bmp,
        originalReferenceImage: rawBytes,
      );
      await suggestPaletteFromReference();
    }
  }

  Future<void> suggestPaletteFromReference({bool algorithmic = false}) async {
    final refImg = state.referenceImage;
    if (refImg == null) return;

    state = state.copyWith(
      isSuggestingPalette: true,
      showPaletteSuggestion: false,
    );

    try {
      if (algorithmic) {
        final colors = extractPaletteKMeans(refImg, 8);
        if (!mounted) return;
        state = state.copyWith(
          suggestedPalette: colors,
          showPaletteSuggestion: true,
        );
      } else {
        final colors = await _aiService.suggestPalette(refImg);
        if (colors != null) {
          if (!mounted) return;
          state = state.copyWith(
            suggestedPalette: colors,
            showPaletteSuggestion: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error suggesting palette: $e');
    } finally {
      if (mounted) {
        state = state.copyWith(isSuggestingPalette: false);
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
    state = state.copyWith(undoStack: newUndo, redoStack: []);
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

  void drawPixel(int x, int y, {bool preview = false}) {
    final size = state.gridSize;
    if (x < 0 || x >= size || y < 0 || y >= size) return;
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

  // Triggering next stroke using new multi-agent orchestrator pipeline
  Future<void> triggerAiStroke() async {
    if (state.isGenerating) return;
    state = state.copyWith(isGenerating: true);

    try {
      final orchestrator = AgentOrchestrator(aiService: activeAiService);

      // Step 3: Decompose the prompt into components
      final components = await orchestrator.decomposePrompt(
        state.gridSize,
        state.palette,
        state.userPrompt,
        referenceImage: state.referenceImage,
      );

      // Run Painter/Eraser/Evaluator outlines loop
      final sketchResult = await orchestrator.runMultiAgentSketch(
        state.gridSize,
        state.palette,
        state.userPrompt,
        components,
        state.referenceImage,
        (msg) {
          debugPrint('[Orchestrator] $msg');
        },
      );
      final sketchGrid = sketchResult.grid;

      // Step 4: Algorithmic detection & Evaluator-directed jaggies correction
      final issues = AlgorithmicHelpers.detectOutlineIssues(
        sketchGrid,
        state.gridSize,
      );
      if (issues.isNotEmpty) {
        debugPrint(
          'Detected ${issues.length} outline issues. Proposing solutions...',
        );
        final issue = issues.first;
        final solutions = AlgorithmicHelpers.proposeSolutions(
          sketchGrid,
          issue,
          state.gridSize,
        );
        if (solutions.isNotEmpty) {
          int bestIdx = 0;
          double bestScore = 0;

          for (int i = 0; i < solutions.length; i++) {
            final evalContext = AgentContext(
              gridSize: state.gridSize,
              activePalette: state.palette,
              userPrompt: state.userPrompt,
              targetComponent: PixelArtComponent(
                name: 'outlines',
                description: 'Refined outline candidate.',
                relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
                proposedBaseColor: state.palette[0],
              ),
              currentGrid: solutions[i],
              referenceImage: state.referenceImage,
            );

            final system = orchestrator.evaluator.getSystemInstruction(
              evalContext,
            );
            final user = orchestrator.evaluator.getFormattedUserPrompt(
              evalContext,
              [],
            );
            final evalResult = await activeAiService.generateJson(
              prompt: '$system\n\n$user',
              imageBytes: generateBmp(solutions[i], state.palette),
            );
            if (evalResult is Map<String, dynamic>) {
              final score = (evalResult['score'] as num? ?? 0.0).toDouble();
              if (score > bestScore) {
                bestScore = score;
                bestIdx = i;
              }
            }
          }

          // Apply chosen solution
          for (int y = 0; y < state.gridSize; y++) {
            for (int x = 0; x < state.gridSize; x++) {
              sketchGrid[y][x] = solutions[bestIdx][y][x];
            }
          }
        }
      }

      // Step 5: Flat coloring
      for (final comp in components) {
        final bbox = comp.relativeBoundingBox;
        final startX = (bbox.left * state.gridSize).round().clamp(
          0,
          state.gridSize - 1,
        );
        final endX = ((bbox.left + bbox.width) * state.gridSize).round().clamp(
          0,
          state.gridSize - 1,
        );
        final startY = (bbox.top * state.gridSize).round().clamp(
          0,
          state.gridSize - 1,
        );
        final endY = ((bbox.top + bbox.height) * state.gridSize).round().clamp(
          0,
          state.gridSize - 1,
        );

        Point? fillPoint;
        for (int y = startY + 1; y < endY; y++) {
          int firstOutlineX = -1;
          int secondOutlineX = -1;
          for (int x = startX; x <= endX; x++) {
            if (sketchGrid[y][x] != 0) {
              if (firstOutlineX == -1) {
                firstOutlineX = x;
              } else {
                secondOutlineX = x;
                break;
              }
            }
          }
          if (firstOutlineX != -1 &&
              secondOutlineX != -1 &&
              secondOutlineX - firstOutlineX > 1) {
            fillPoint = Point((firstOutlineX + secondOutlineX) ~/ 2, y);
            break;
          }
        }

        if (fillPoint != null) {
          final colorIdx = state.palette.indexOf(comp.proposedBaseColor) + 1;
          final fillCommand = FillCommand(fillPoint.x, fillPoint.y);
          fillCommand.execute(
            sketchGrid,
            colorIdx.clamp(1, state.palette.length),
            state.gridSize,
          );
        }
      }

      _pushToUndo(state.grid);
      state = state.copyWith(
        grid: sketchGrid,
        selectedColorIndex: sketchResult.lastColorIndex.clamp(
          0,
          state.palette.length,
        ),
        aiHistory: [
          ...state.aiHistory,
          AgentHistoryEntry(
            timestamp: DateTime.now(),
            prompt: sketchResult.rawPrompt,
            response: sketchResult.rawResponse,
            isError: false,
          ),
        ],
      );
    } catch (e) {
      debugPrint('Error in triggerAiStroke: $e');
    } finally {
      state = state.copyWith(isGenerating: false);
    }
  }

  Future<void> runPolishingAction(String actionName) async {
    if (state.isGenerating) return;
    state = state.copyWith(isGenerating: true);

    try {
      final orchestrator = AgentOrchestrator(aiService: activeAiService);
      final List<List<int>> currentGrid = state.grid
          .map((row) => List<int>.from(row))
          .toList();

      await orchestrator.runPolishing(
        currentGrid,
        state.gridSize,
        state.palette,
        actionName,
        state.referenceImage,
        (msg) => debugPrint(msg),
      );

      _pushToUndo(state.grid);
      state = state.copyWith(
        grid: currentGrid,
        aiHistory: [
          ...state.aiHistory,
          AgentHistoryEntry(
            timestamp: DateTime.now(),
            prompt: 'Trigger Polish Action: "$actionName"',
            response: 'Completed polishing filters.',
            isError: false,
          ),
        ],
      );
    } catch (e) {
      debugPrint('Error in runPolishingAction: $e');
    } finally {
      state = state.copyWith(isGenerating: false);
    }
  }

  void clearAiHistory() {
    state = state.copyWith(aiHistory: const []);
  }

  void _applyAiStrokeCommand(
    String toolName,
    List<int> params,
    int colorIndex,
  ) {
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

List<Color> extractPaletteKMeans(Uint8List bmpBytes, int colorCount) {
  if (bmpBytes.length <= 54) {
    return List.filled(colorCount, Colors.grey);
  }

  final List<Color> pixels = [];
  int offset = 54;
  while (offset + 2 < bmpBytes.length) {
    final b = bmpBytes[offset];
    final g = bmpBytes[offset + 1];
    final r = bmpBytes[offset + 2];
    pixels.add(Color.fromARGB(255, r, g, b));
    offset += 3;
  }

  if (pixels.isEmpty) {
    return List.filled(colorCount, Colors.grey);
  }

  final List<Color> centroids = [];
  final random = Random(42);
  for (int i = 0; i < colorCount; i++) {
    centroids.add(pixels[random.nextInt(pixels.length)]);
  }

  for (int iter = 0; iter < 5; iter++) {
    final List<List<Color>> clusters = List.generate(colorCount, (_) => []);

    for (final pixel in pixels) {
      double minDistance = double.maxFinite;
      int closestCentroid = 0;

      for (int i = 0; i < colorCount; i++) {
        final cent = centroids[i];
        final dist =
            pow(pixel.red - cent.red, 2) +
            pow(pixel.green - cent.green, 2) +
            pow(pixel.blue - cent.blue, 2);
        if (dist < minDistance) {
          minDistance = dist.toDouble();
          closestCentroid = i;
        }
      }
      clusters[closestCentroid].add(pixel);
    }

    for (int i = 0; i < colorCount; i++) {
      final cluster = clusters[i];
      if (cluster.isEmpty) continue;

      int sumR = 0, sumG = 0, sumB = 0;
      for (final p in cluster) {
        sumR += p.red;
        sumG += p.green;
        sumB += p.blue;
      }
      centroids[i] = Color.fromARGB(
        255,
        (sumR / cluster.length).round(),
        (sumG / cluster.length).round(),
        (sumB / cluster.length).round(),
      );
    }
  }

  return centroids;
}

List<List<Color>> _bmpToColorGrid(Uint8List bmpBytes, int size) {
  final List<List<Color>> grid = List.generate(
    size,
    (_) => List.filled(size, const Color(0xFF000000)),
  );
  if (bmpBytes.length >= 54 + size * size * 3) {
    int offset = 54;
    for (int y = size - 1; y >= 0; y--) {
      for (int x = 0; x < size; x++) {
        final b = bmpBytes[offset];
        final g = bmpBytes[offset + 1];
        final r = bmpBytes[offset + 2];
        grid[y][x] = Color(0xFF000000 | (r << 16) | (g << 8) | b);
        offset += 3;
      }
    }
  }
  return grid;
}

List<List<Color>> _applyGaussianBlur(List<List<Color>> src) {
  final int size = src.length;
  final List<List<Color>> dest = List.generate(
    size,
    (_) => List.filled(size, const Color(0xFF000000)),
  );
  final List<int> kernel = [1, 2, 1, 2, 4, 2, 1, 2, 1];
  const int kernelWeight = 16;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      int sumR = 0;
      int sumG = 0;
      int sumB = 0;

      for (int ky = -1; ky <= 1; ky++) {
        for (int kx = -1; kx <= 1; kx++) {
          final px = (x + kx).clamp(0, size - 1);
          final py = (y + ky).clamp(0, size - 1);
          final color = src[py][px];
          final weight = kernel[(ky + 1) * 3 + (kx + 1)];
          sumR += color.red * weight;
          sumG += color.green * weight;
          sumB += color.blue * weight;
        }
      }

      dest[y][x] = Color.fromARGB(
        255,
        (sumR ~/ kernelWeight).clamp(0, 255),
        (sumG ~/ kernelWeight).clamp(0, 255),
        (sumB ~/ kernelWeight).clamp(0, 255),
      );
    }
  }
  return dest;
}

List<List<int>> getQuantizedIndexGrid(
  Uint8List bmpBytes,
  List<Color> palette,
  int size,
) {
  final List<List<int>> grid = List.generate(size, (_) => List.filled(size, 0));
  if (bmpBytes.length >= 54 + size * size * 3) {
    final refGrid = _bmpToColorGrid(bmpBytes, size);
    final blurredGrid = _applyGaussianBlur(refGrid);
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final color = blurredGrid[y][x];
        int closestIndex = 0;
        double minDistance = double.infinity;
        for (int i = 0; i < palette.length; i++) {
          final pColor = palette[i];
          final dr = color.red - pColor.red;
          final dg = color.green - pColor.green;
          final db = color.blue - pColor.blue;
          final dist = dr * dr + dg * dg + db * db;
          if (dist < minDistance) {
            minDistance = dist.toDouble();
            closestIndex = i;
          }
        }
        grid[y][x] = closestIndex + 1;
      }
    }
  }
  return grid;
}

String canvasToTextGrid(List<List<int>> grid) {
  final buffer = StringBuffer();
  final int size = grid.length;

  buffer.write('    ');
  for (int x = 0; x < size; x++) {
    buffer.write(x >= 10 ? '${x ~/ 10}' : ' ');
  }
  buffer.write('\n');

  buffer.write('    ');
  for (int x = 0; x < size; x++) {
    buffer.write('${x % 10}');
  }
  buffer.write('\n');

  for (int y = 0; y < size; y++) {
    buffer.write('${y.toString().padLeft(3)} ');
    for (int x = 0; x < size; x++) {
      final val = grid[y][x];
      if (val == 0) {
        buffer.write('.');
      } else if (val < 10) {
        buffer.write('$val');
      } else if (val < 36) {
        buffer.write(String.fromCharCode(65 + val - 10)); // A-Z
      } else {
        buffer.write('#');
      }
    }
    buffer.write('\n');
  }

  return buffer.toString();
}

final canvasStateProvider = StateNotifierProvider<CanvasNotifier, CanvasModel>((
  ref,
) {
  final aiService = ref.watch(aiServiceProvider);
  return CanvasNotifier(aiService);
});

Future<Uint8List?> resizeAndConvertToBmp(
  Uint8List imageBytes,
  int gridSize,
) async {
  try {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frameInfo = await codec.getNextFrame();
    final originalImage = frameInfo.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, gridSize.toDouble(), gridSize.toDouble()),
      image: originalImage,
      fit: BoxFit.cover,
    );

    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(gridSize, gridSize);

    final byteData = await resizedImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return null;

    final rgbaBytes = byteData.buffer.asUint8List();
    return generateBmpFromRgba(rgbaBytes, gridSize, gridSize);
  } catch (e) {
    debugPrint('Error resizing image: $e');
    return null;
  }
}
