// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_agent/local_agent.dart';
import 'prompts.dart';
import 'drawing_commands.dart';

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

Uint8List generateBmp(List<List<int>> grid, List<Color> palette) {
  final int height = grid.length;
  final int width = grid.isNotEmpty ? grid[0].length : 0;
  if (width == 0 || height == 0) {
    return generateBmpFromRgba(Uint8List.fromList([0, 0, 0, 255]), 1, 1);
  }
  const int bytesPerPixel = 3;
  final int rowPadding = (4 - (width * bytesPerPixel) % 4) % 4;
  final int rowStride = width * bytesPerPixel + rowPadding;
  final int pixelDataSize = rowStride * height;
  final int fileSize = 54 + pixelDataSize;

  final Uint8List bmp = Uint8List(fileSize);
  final ByteData bd = ByteData.sublistView(bmp);

  // BMP Header
  bmp[0] = 0x42; // 'B'
  bmp[1] = 0x4D; // 'M'
  bd.setUint32(2, fileSize, Endian.little);
  bd.setUint32(6, 0, Endian.little);
  bd.setUint32(10, 54, Endian.little);

  // DIB Header (BITMAPINFOHEADER)
  bd.setUint32(14, 40, Endian.little);
  bd.setUint32(18, width, Endian.little);
  bd.setUint32(22, height, Endian.little);
  bd.setUint16(26, 1, Endian.little);
  bd.setUint16(28, 24, Endian.little); // 24-bit BGR
  bd.setUint32(30, 0, Endian.little);
  bd.setUint32(34, pixelDataSize, Endian.little);
  bd.setUint32(38, 2835, Endian.little); // 72 DPI
  bd.setUint32(42, 2835, Endian.little); // 72 DPI
  bd.setUint32(46, 0, Endian.little);
  bd.setUint32(50, 0, Endian.little);

  int offset = 54;
  for (int y = height - 1; y >= 0; y--) {
    for (int x = 0; x < width; x++) {
      final colorIndex = grid[y][x];
      final color = colorIndex == 0
          ? ((x + y) % 2 == 0
                ? const Color(0xFF262626)
                : const Color(0xFF1E1E1E))
          : palette[colorIndex - 1];

      bmp[offset] = color.blue;
      bmp[offset + 1] = color.green;
      bmp[offset + 2] = color.red;
      offset += 3;
    }
    for (int p = 0; p < rowPadding; p++) {
      bmp[offset++] = 0;
    }
  }

  return bmp;
}

Uint8List combineBmps(List<Uint8List> bmps) {
  final activeBmps = bmps.where((b) => b.isNotEmpty).toList();
  if (activeBmps.isEmpty) {
    return generateBmpFromRgba(Uint8List.fromList([0, 0, 0, 255]), 1, 1);
  }

  final int n = activeBmps.length;
  final ByteData firstBd = ByteData.sublistView(activeBmps[0]);
  final int panelSize = firstBd.getUint32(18, Endian.little);
  final int cols = n <= 1 ? 1 : 2;
  final int rows = n <= 1 ? 1 : 2;

  final int combinedWidth = panelSize * cols;
  final int combinedHeight = panelSize * rows;
  const int bytesPerPixel = 3;
  final int rowPadding = (4 - (combinedWidth * bytesPerPixel) % 4) % 4;
  final int rowStride = combinedWidth * bytesPerPixel + rowPadding;
  final int pixelDataSize = rowStride * combinedHeight;
  final int fileSize = 54 + pixelDataSize;

  final Uint8List combined = Uint8List(fileSize);
  final ByteData bd = ByteData.sublistView(combined);

  // BMP Header
  combined[0] = 0x42; // 'B'
  combined[1] = 0x4D; // 'M'
  bd.setUint32(2, fileSize, Endian.little);
  bd.setUint32(6, 0, Endian.little);
  bd.setUint32(10, 54, Endian.little);

  // DIB Header (BITMAPINFOHEADER)
  bd.setUint32(14, 40, Endian.little);
  bd.setUint32(18, combinedWidth, Endian.little);
  bd.setUint32(22, combinedHeight, Endian.little);
  bd.setUint16(26, 1, Endian.little);
  bd.setUint16(28, 24, Endian.little); // 24-bit BGR
  bd.setUint32(30, 0, Endian.little);
  bd.setUint32(34, pixelDataSize, Endian.little);
  bd.setUint32(38, 2835, Endian.little); // 72 DPI
  bd.setUint32(42, 2835, Endian.little); // 72 DPI
  bd.setUint32(46, 0, Endian.little);
  bd.setUint32(50, 0, Endian.little);

  int offset = 54;
  for (int y = combinedHeight - 1; y >= 0; y--) {
    final int gridRow = y ~/ panelSize;
    final int panelY = (gridRow + 1) * panelSize - 1 - y;

    for (int gridCol = 0; gridCol < cols; gridCol++) {
      final int panelIndex = gridRow * cols + gridCol;
      if (panelIndex < n) {
        final bmpBytes = activeBmps[panelIndex];
        final int srcRowOffset = 54 + panelY * panelSize * 3;
        for (int x = 0; x < panelSize; x++) {
          final int pixelOffset = srcRowOffset + x * 3;
          combined[offset] = bmpBytes[pixelOffset]; // blue
          combined[offset + 1] = bmpBytes[pixelOffset + 1]; // green
          combined[offset + 2] = bmpBytes[pixelOffset + 2]; // red
          offset += 3;
        }
      } else {
        // Write black filler pixels
        for (int x = 0; x < panelSize; x++) {
          combined[offset] = 0;
          combined[offset + 1] = 0;
          combined[offset + 2] = 0;
          offset += 3;
        }
      }
    }

    for (int pad = 0; pad < rowPadding; pad++) {
      combined[offset++] = 0;
    }
  }

  return combined;
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
    final List<Uint8List> bmpsToCombine = [];

    if (referenceBmp != null) {
      final refGrid = _bmpToColorGrid(referenceBmp);
      final blurredGrid = _applyGaussianBlur(refGrid);
      final quantizedGrid = _applyColorQuantization(blurredGrid, state.palette);
      final quantizedBmp = _bmpFromColorGrid(quantizedGrid);
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
    final newPalette = name == 'grayscale' ? grayscalePalette : primaryPalette;
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
    if (state.isGenerating) return;
    state = state.copyWith(isGenerating: true);

    final paletteHexes = state.palette
        .map(
          (c) => '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        )
        .toList();

    final startingGrid = state.grid;
    final startingBmp = generateBmp(startingGrid, state.palette);
    final isMultimodal = _aiService is MethodChannelAiService;

    String rawResponse = '';
    bool isError = false;
    Uint8List loggedBmp = startingBmp;
    final String promptLog =
        'Co-creative Multi-Agent Drawing Step (AI pixel art assistant):\n'
        '- 3 Painter Agent Runs each ran for 5 turns starting from the current canvas.\n'
        '- Critic evaluated all three candidates on a 2x2 comparison grid and selected the best progression.';

    try {
      // 1. Get textual description of the reference image using Describer
      final refBmp = state.referenceImage;
      final Map<String, String>? refDescResult = refBmp != null
          ? await _aiService.describeCanvas(canvasImage: refBmp)
          : null;
      final String referenceDescription =
          refDescResult?['response'] ??
          (refBmp != null
              ? 'A pixel art reference image.'
              : 'An empty canvas.');

      // Run the 3 painters in parallel using Future.wait
      final results = await Future.wait([
        _runPainterAgent(
          agentNumber: 1,
          startingGrid: startingGrid,
          palette: state.palette,
          paletteHexes: paletteHexes,
          referenceDescription: referenceDescription,
          isMultimodal: isMultimodal,
        ),
        _runPainterAgent(
          agentNumber: 2,
          startingGrid: startingGrid,
          palette: state.palette,
          paletteHexes: paletteHexes,
          referenceDescription: referenceDescription,
          isMultimodal: isMultimodal,
        ),
        _runPainterAgent(
          agentNumber: 3,
          startingGrid: startingGrid,
          palette: state.palette,
          paletteHexes: paletteHexes,
          referenceDescription: referenceDescription,
          isMultimodal: isMultimodal,
        ),
      ]);

      // Convert candidate grids to BMPs
      final candidate1Bmp = generateBmp(
        results[0]['grid'] as List<List<int>>,
        state.palette,
      );
      final candidate2Bmp = generateBmp(
        results[1]['grid'] as List<List<int>>,
        state.palette,
      );
      final candidate3Bmp = generateBmp(
        results[3 - 1]['grid'] as List<List<int>>,
        state.palette,
      );

      // Describe the starting canvas and candidates
      final startDescResult = await _aiService.describeCanvas(
        canvasImage: startingBmp,
      );
      final String startingCanvasDescription =
          startDescResult?['response'] ?? 'Starting state.';

      final cand1DescResult = await _aiService.describeCanvas(
        canvasImage: candidate1Bmp,
      );
      final String candidate1Description =
          cand1DescResult?['response'] ?? 'Candidate 1 progression.';

      final cand2DescResult = await _aiService.describeCanvas(
        canvasImage: candidate2Bmp,
      );
      final String candidate2Description =
          cand2DescResult?['response'] ?? 'Candidate 2 progression.';

      final cand3DescResult = await _aiService.describeCanvas(
        canvasImage: candidate3Bmp,
      );
      final String candidate3Description =
          cand3DescResult?['response'] ?? 'Candidate 3 progression.';

      // Stitch the 2x2 comparison grid for the visual log in the UI
      final criticCombinedBmp = combineBmps([
        refBmp ?? startingBmp,
        candidate1Bmp,
        candidate2Bmp,
        candidate3Bmp,
      ]);
      loggedBmp = criticCombinedBmp;

      final String criticPrompt = formatCriticTextOnlyPrompt(
        userPrompt: state.userPrompt,
        referenceDescription: referenceDescription,
        startingCanvasDescription: startingCanvasDescription,
        candidate1Description: candidate1Description,
        candidate2Description: candidate2Description,
        candidate3Description: candidate3Description,
      );

      final describersLog = {
        'reference': {
          'description': referenceDescription,
          'rawPrompt': refDescResult?['prompt'] ?? 'N/A',
          'rawResponse': refDescResult?['response'] ?? 'N/A',
          'imageBytes': refBmp != null ? base64Encode(refBmp) : null,
        },
        'starting': {
          'description': startingCanvasDescription,
          'rawPrompt': startDescResult?['prompt'] ?? 'N/A',
          'rawResponse': startDescResult?['response'] ?? 'N/A',
          'imageBytes': base64Encode(startingBmp),
        },
        'candidate1': {
          'description': candidate1Description,
          'rawPrompt': cand1DescResult?['prompt'] ?? 'N/A',
          'rawResponse': cand1DescResult?['response'] ?? 'N/A',
          'imageBytes': base64Encode(candidate1Bmp),
        },
        'candidate2': {
          'description': candidate2Description,
          'rawPrompt': cand2DescResult?['prompt'] ?? 'N/A',
          'rawResponse': cand2DescResult?['response'] ?? 'N/A',
          'imageBytes': base64Encode(candidate2Bmp),
        },
        'candidate3': {
          'description': candidate3Description,
          'rawPrompt': cand3DescResult?['prompt'] ?? 'N/A',
          'rawResponse': cand3DescResult?['response'] ?? 'N/A',
          'imageBytes': base64Encode(candidate3Bmp),
        },
      };

      // Ask Critic to evaluate candidate descriptions (text-only)
      final criticResult = await _aiService.evaluateCandidates(
        userPrompt: state.userPrompt,
        referenceDescription: referenceDescription,
        startingCanvasDescription: startingCanvasDescription,
        candidate1Description: candidate1Description,
        candidate2Description: candidate2Description,
        candidate3Description: candidate3Description,
      );

      if (criticResult != null) {
        final choice = criticResult['choice'];
        final criticReasoning = criticResult['reasoning'] as String?;
        final nextFocus = criticResult['nextFocus'] as String?;

        // Extract chosen painter index (1, 2, or 3) and clamp safely
        int choiceInt = 1;
        if (choice is int) {
          choiceInt = choice.clamp(1, 3);
        } else if (choice is String) {
          choiceInt = (int.tryParse(choice) ?? 1).clamp(1, 3);
        }

        final chosenIndex = choiceInt - 1;
        final chosenGrid = results[chosenIndex]['grid'] as List<List<int>>;
        final chosenStrokes =
            results[chosenIndex]['strokes'] as List<Map<String, dynamic>>;

        int finalColorIndex = state.selectedColorIndex;
        if (chosenStrokes.isNotEmpty) {
          finalColorIndex =
              (chosenStrokes.last['color'] as int?) ?? finalColorIndex;
        }
        final boundedColorIndex = finalColorIndex.clamp(
          0,
          state.palette.length,
        );

        // Update the official canvas state to the chosen grid
        _pushToUndo(startingGrid);
        state = state.copyWith(
          grid: chosenGrid,
          selectedColorIndex: boundedColorIndex,
          redoStack: const [],
          nextFocus: nextFocus,
        );

        rawResponse = jsonEncode({
          'criticChoice': choiceInt,
          'criticReasoning':
              criticReasoning ?? 'Selected candidate $choiceInt.',
          'criticNextFocus': nextFocus ?? 'N/A',
          'criticRawPrompt': criticPrompt,
          'criticRawResponse': jsonEncode(criticResult),
          'painter1Strokes': results[0]['strokes'],
          'painter2Strokes': results[1]['strokes'],
          'painter3Strokes': results[2]['strokes'],
          'describers': describersLog,
        });
      } else {
        // Fallback: default to Painter 1
        final chosenGrid = results[0]['grid'] as List<List<int>>;
        final chosenStrokes =
            results[0]['strokes'] as List<Map<String, dynamic>>;

        int finalColorIndex = state.selectedColorIndex;
        if (chosenStrokes.isNotEmpty) {
          finalColorIndex =
              (chosenStrokes.last['color'] as int?) ?? finalColorIndex;
        }
        final boundedColorIndex = finalColorIndex.clamp(
          0,
          state.palette.length,
        );

        _pushToUndo(startingGrid);
        state = state.copyWith(
          grid: chosenGrid,
          selectedColorIndex: boundedColorIndex,
          redoStack: const [],
          clearNextFocus: true,
        );
        rawResponse = jsonEncode({
          'criticChoice': 1,
          'criticReasoning':
              'Critic response unavailable, defaulted to Painter 1.',
          'criticNextFocus': 'N/A',
          'criticRawPrompt': criticPrompt,
          'criticRawResponse': 'Critic response was null.',
          'painter1Strokes': results[0]['strokes'],
          'painter2Strokes': results[1]['strokes'],
          'painter3Strokes': results[2]['strokes'],
          'describers': describersLog,
        });
      }
    } catch (e) {
      isError = true;
      rawResponse = 'Error in tournament execution: $e';
      debugPrint('Error running multi-agent drawing cycle: $e');
    } finally {
      final newHistory = List<AgentHistoryEntry>.from(state.aiHistory)
        ..add(
          AgentHistoryEntry(
            timestamp: DateTime.now(),
            prompt: promptLog,
            response: rawResponse,
            isError: isError,
            imageBytes: loggedBmp,
          ),
        );
      state = state.copyWith(isGenerating: false, aiHistory: newHistory);
    }
  }

  Future<Map<String, dynamic>> _runPainterAgent({
    required int agentNumber,
    required List<List<int>> startingGrid,
    required List<Color> palette,
    required List<String> paletteHexes,
    required String referenceDescription,
    required bool isMultimodal,
  }) async {
    final List<List<int>> tempGrid = List.generate(
      startingGrid.length,
      (y) => List<int>.from(startingGrid[y]),
    );

    final List<Map<String, dynamic>> strokesHistory = [];
    final List<List<List<int>>> localUndoStack = [];

    for (int turn = 1; turn <= 5; turn++) {
      final previousBmp = generateBmp(tempGrid, palette);

      final systemInstruction = formatSystemInstruction();

      final String currentCanvasTextGrid = canvasToTextGrid(tempGrid);

      final userTextPrompt = formatUserPrompt(
        canvasImage: previousBmp,
        prompt: state.userPrompt,
        paletteColors: paletteHexes,
        isMultimodal: isMultimodal,
        hasPreviousImage: true,
        referenceDescription: referenceDescription,
        currentCanvasTextGrid: currentCanvasTextGrid,
        nextFocus: state.nextFocus,
      );

      String historyPrompt = '';
      if (strokesHistory.isNotEmpty) {
        final historyItems = strokesHistory
            .map((entry) {
              final Map<String, dynamic> cleanEntry = {
                'tool': entry['tool'],
                'params': entry['params'],
                'color': entry['color'],
              };
              final cleanResponse = jsonEncode(
                cleanEntry,
              ).replaceAll(RegExp(r'\s+'), ' ');
              return '- $cleanResponse';
            })
            .join('\n');
        historyPrompt =
            '\n\nYour recent moves in this 5-turn sequence:\n$historyItems\n'
            'Continue building on top of your recent moves to paint the final image.';
      }

      final fullPrompt =
          '$systemInstruction\n\n$userTextPrompt\n\n$historyPrompt';

      final double temperature = agentNumber == 1
          ? 0.25
          : (agentNumber == 2 ? 0.5 : 1.0);

      try {
        final painterResult = await _aiService.getNextStroke(
          canvasImage: previousBmp,
          prompt: fullPrompt,
          temperature: temperature,
        );

        if (painterResult != null) {
          if (painterResult.containsKey('rawResponse') ||
              painterResult.containsKey('error')) {
            strokesHistory.add({
              'tool': 'error',
              'params': <int>[],
              'color': 0,
              'rawPrompt': fullPrompt,
              'rawResponse': painterResult['rawResponse'] ?? 'N/A',
              'error': painterResult['error'] ?? 'JSON parsing failed',
              'rawImageBase64': base64Encode(previousBmp),
            });
            continue;
          }

          final tool = painterResult['tool'] as String?;
          final params = (painterResult['params'] as List?)?.cast<int>();
          final colorIndex = painterResult['color'] as int?;

          if (tool != null &&
              params != null &&
              (colorIndex != null || tool == 'undo')) {
            _applyStrokeToGrid(
              tempGrid,
              tool,
              params,
              colorIndex ?? 0,
              localUndoStack,
            );

            final strokeLog = Map<String, dynamic>.from(painterResult);
            strokeLog['rawPrompt'] = fullPrompt;
            strokeLog['rawResponse'] = jsonEncode(painterResult);
            strokeLog['rawImageBase64'] = base64Encode(previousBmp);
            strokesHistory.add(strokeLog);
          } else {
            strokesHistory.add({
              'tool': 'error',
              'params': <int>[],
              'color': 0,
              'rawPrompt': fullPrompt,
              'rawResponse': jsonEncode(painterResult),
              'error': 'Missing required JSON keys: tool, params, or color',
              'rawImageBase64': base64Encode(previousBmp),
            });
            continue;
          }
        } else {
          strokesHistory.add({
            'tool': 'error',
            'params': <int>[],
            'color': 0,
            'rawPrompt': fullPrompt,
            'rawResponse': 'N/A',
            'error':
                'AI service returned null response (possible connection issue, safety block, or rate limit)',
            'rawImageBase64': base64Encode(previousBmp),
          });
          continue;
        }
      } catch (e) {
        debugPrint(
          'Painter Agent $agentNumber encountered error on turn $turn: $e',
        );
        strokesHistory.add({
          'tool': 'error',
          'params': <int>[],
          'color': 0,
          'rawPrompt': fullPrompt,
          'rawResponse': 'N/A',
          'error': 'Exception caught: $e',
          'rawImageBase64': base64Encode(previousBmp),
        });
        continue;
      }
    }

    return {'grid': tempGrid, 'strokes': strokesHistory};
  }

  void _applyStrokeToGrid(
    List<List<int>> tempGrid,
    String toolName,
    List<int> params,
    int colorIndex,
    List<List<List<int>>> localUndoStack,
  ) {
    final boundedColorIndex = colorIndex.clamp(0, state.palette.length);

    if (toolName == 'undo') {
      if (localUndoStack.isNotEmpty) {
        final prev = localUndoStack.removeLast();
        for (int y = 0; y < tempGrid.length; y++) {
          tempGrid[y] = List<int>.from(prev[y]);
        }
      }
      return;
    }

    // Save state for undo support only for drawing commands
    localUndoStack.add(
      List.generate(tempGrid.length, (y) => List<int>.from(tempGrid[y])),
    );

    final command = DrawingCommandFactory.create(toolName, params);
    if (command != null) {
      command.execute(tempGrid, boundedColorIndex, tempGrid.length);
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
    // Keep color index bounded
    final boundedColorIndex = colorIndex.clamp(0, state.palette.length);

    // Set notifier's current drawing color to match AI's stroke color
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

Uint8List generateBmpFromRgba(Uint8List rgbaBytes, int width, int height) {
  const int bytesPerPixel = 3;
  final int rowPadding = (4 - (width * bytesPerPixel) % 4) % 4;
  final int rowStride = width * bytesPerPixel + rowPadding;
  final int pixelDataSize = rowStride * height;
  final int fileSize = 54 + pixelDataSize;

  final Uint8List bmp = Uint8List(fileSize);
  final ByteData bd = ByteData.sublistView(bmp);

  // BMP Header
  bmp[0] = 0x42; // 'B'
  bmp[1] = 0x4D; // 'M'
  bd.setUint32(2, fileSize, Endian.little);
  bd.setUint32(6, 0, Endian.little);
  bd.setUint32(10, 54, Endian.little);

  // DIB Header (BITMAPINFOHEADER)
  bd.setUint32(14, 40, Endian.little);
  bd.setUint32(18, width, Endian.little);
  bd.setUint32(22, height, Endian.little);
  bd.setUint16(26, 1, Endian.little);
  bd.setUint16(28, 24, Endian.little); // 24-bit BGR
  bd.setUint32(30, 0, Endian.little);
  bd.setUint32(34, pixelDataSize, Endian.little);
  bd.setUint32(38, 2835, Endian.little); // 72 DPI
  bd.setUint32(42, 2835, Endian.little); // 72 DPI
  bd.setUint32(46, 0, Endian.little);
  bd.setUint32(50, 0, Endian.little);

  int offset = 54;
  for (int y = height - 1; y >= 0; y--) {
    for (int x = 0; x < width; x++) {
      final int rgbaOffset = (y * width + x) * 4;
      final int r = rgbaBytes[rgbaOffset];
      final int g = rgbaBytes[rgbaOffset + 1];
      final int b = rgbaBytes[rgbaOffset + 2];

      bmp[offset] = b;
      bmp[offset + 1] = g;
      bmp[offset + 2] = r;
      offset += 3;
    }
    for (int p = 0; p < rowPadding; p++) {
      bmp[offset++] = 0;
    }
  }

  return bmp;
}

List<List<Color>> _bmpToColorGrid(Uint8List bmpBytes) {
  final ByteData bd = ByteData.sublistView(bmpBytes);
  final int size = bd.getUint32(18, Endian.little);
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

Uint8List _bmpFromColorGrid(List<List<Color>> grid) {
  final int height = grid.length;
  final int width = grid.isNotEmpty ? grid[0].length : 0;
  const int bytesPerPixel = 3;
  final int rowPadding = (4 - (width * bytesPerPixel) % 4) % 4;
  final int rowStride = width * bytesPerPixel + rowPadding;
  final int pixelDataSize = rowStride * height;
  final int fileSize = 54 + pixelDataSize;

  final Uint8List bmp = Uint8List(fileSize);
  final ByteData bd = ByteData.sublistView(bmp);

  bmp[0] = 0x42; // 'B'
  bmp[1] = 0x4D; // 'M'
  bd.setUint32(2, fileSize, Endian.little);
  bd.setUint32(6, 0, Endian.little);
  bd.setUint32(10, 54, Endian.little);

  bd.setUint32(14, 40, Endian.little);
  bd.setUint32(18, width, Endian.little);
  bd.setUint32(22, height, Endian.little);
  bd.setUint16(26, 1, Endian.little);
  bd.setUint16(28, 24, Endian.little);
  bd.setUint32(30, 0, Endian.little);
  bd.setUint32(34, pixelDataSize, Endian.little);
  bd.setUint32(38, 2835, Endian.little);
  bd.setUint32(42, 2835, Endian.little);
  bd.setUint32(46, 0, Endian.little);
  bd.setUint32(50, 0, Endian.little);

  int offset = 54;
  for (int y = height - 1; y >= 0; y--) {
    for (int x = 0; x < width; x++) {
      final color = grid[y][x];
      bmp[offset] = color.blue;
      bmp[offset + 1] = color.green;
      bmp[offset + 2] = color.red;
      offset += 3;
    }
    for (int p = 0; p < rowPadding; p++) {
      bmp[offset++] = 0;
    }
  }
  return bmp;
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

List<List<Color>> _applyColorQuantization(
  List<List<Color>> src,
  List<Color> palette,
) {
  final int size = src.length;
  final List<List<Color>> dest = List.generate(
    size,
    (_) => List.filled(size, const Color(0xFF000000)),
  );
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final color = src[y][x];
      Color closestColor = palette.first;
      double minDistance = double.infinity;
      for (final pColor in palette) {
        final dr = color.red - pColor.red;
        final dg = color.green - pColor.green;
        final db = color.blue - pColor.blue;
        final dist = dr * dr + dg * dg + db * db;
        if (dist < minDistance) {
          minDistance = dist.toDouble();
          closestColor = pColor;
        }
      }
      dest[y][x] = closestColor;
    }
  }
  return dest;
}

List<List<int>> getQuantizedIndexGrid(Uint8List bmpBytes, List<Color> palette) {
  final ByteData bd = ByteData.sublistView(bmpBytes);
  final int size = bd.getUint32(18, Endian.little);
  final List<List<int>> grid = List.generate(size, (_) => List.filled(size, 0));
  if (bmpBytes.length >= 54 + size * size * 3) {
    final refGrid = _bmpToColorGrid(bmpBytes);
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

  // Header: 10s digits
  buffer.write('    ');
  for (int x = 0; x < size; x++) {
    buffer.write(x >= 10 ? '${x ~/ 10}' : ' ');
  }
  buffer.write('\n');

  // Header: 1s digits
  buffer.write('    ');
  for (int x = 0; x < size; x++) {
    buffer.write('${x % 10}');
  }
  buffer.write('\n');

  // Rows
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
