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
  const int width = 64;
  const int height = 64;
  const int bytesPerPixel = 3;
  const int rowPadding = (4 - (width * bytesPerPixel) % 4) % 4;
  const int rowStride = width * bytesPerPixel + rowPadding;
  const int pixelDataSize = rowStride * height;
  const int fileSize = 54 + pixelDataSize;

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

const Map<int, List<String>> _digitFont = {
  0: ['###', '#.#', '#.#', '#.#', '###'],
  1: ['..#', '..#', '..#', '..#', '..#'],
  2: ['###', '..#', '###', '#..', '###'],
  3: ['###', '..#', '###', '..#', '###'],
  4: ['#.#', '#.#', '###', '..#', '..#'],
  5: ['###', '#..', '###', '..#', '###'],
  6: ['###', '#..', '###', '#.#', '###'],
  7: ['###', '..#', '..#', '..#', '..#'],
  8: ['###', '#.#', '###', '#.#', '###'],
  9: ['###', '#.#', '###', '..#', '###'],
};

void _drawText(
  List<List<Color>> grid,
  String text,
  int startX,
  int startY,
  Color color,
) {
  int curX = startX;
  for (int i = 0; i < text.length; i++) {
    final char = text[i];
    final digit = int.tryParse(char);
    if (digit == null || !_digitFont.containsKey(digit)) continue;
    final pattern = _digitFont[digit]!;
    for (int dy = 0; dy < 5; dy++) {
      for (int dx = 0; dx < 3; dx++) {
        if (pattern[dy][dx] == '#') {
          final targetY = startY + dy;
          final targetX = curX + dx;
          if (targetY >= 0 &&
              targetY < grid.length &&
              targetX >= 0 &&
              targetX < grid[0].length) {
            grid[targetY][targetX] = color;
          }
        }
      }
    }
    curX += 4; // 3 width + 1 spacing
  }
}

List<List<Color>> _padAndLabelPanel(Uint8List bmpBytes, List<Color> palette) {
  final List<List<Color>> srcGrid = List.generate(
    64,
    (_) => List.filled(64, const Color(0xFF000000)),
  );

  if (bmpBytes.length >= 54 + 64 * 64 * 3) {
    int offset = 54;
    for (int y = 63; y >= 0; y--) {
      for (int x = 0; x < 64; x++) {
        final b = bmpBytes[offset];
        final g = bmpBytes[offset + 1];
        final r = bmpBytes[offset + 2];
        srcGrid[y][x] = Color(0xFF000000 | (r << 16) | (g << 8) | b);
        offset += 3;
      }
    }
  }

  final List<List<Color>> destGrid = List.generate(
    80,
    (_) => List.filled(80, const Color(0xFF000000)),
  );

  for (int y = 0; y < 64; y++) {
    for (int x = 0; x < 64; x++) {
      destGrid[y + 16][x + 16] = srcGrid[y][x];
    }
  }

  const separatorColor = Color(0xFF333333);
  for (int i = 0; i < 80; i++) {
    destGrid[15][i] = separatorColor;
    destGrid[i][15] = separatorColor;
  }

  const tickColor = Color(0xFF888888);
  const textColor = Color(0xFFCCCCCC);

  final coords = [0, 16, 32, 48, 63];
  for (final c in coords) {
    // X-axis (top ruler)
    final px = 16 + c;
    destGrid[14][px] = tickColor;

    final String labelStr = c.toString();
    int labelX;
    if (c == 0) {
      labelX = px - 1;
    } else if (c == 63) {
      labelX = px - 5;
    } else {
      labelX = px - 3;
    }
    _drawText(destGrid, labelStr, labelX, 5, textColor);

    // Y-axis (left ruler)
    final py = 16 + c;
    destGrid[py][14] = tickColor;

    final int labelXLeft = (labelStr.length == 1) ? 6 : 2;
    _drawText(destGrid, labelStr, labelXLeft, py - 2, textColor);
  }

  return destGrid;
}

Uint8List combineBmps(List<Uint8List> bmps) {
  final activeBmps = bmps.where((b) => b.isNotEmpty).toList();
  if (activeBmps.isEmpty) {
    return generateBmpFromRgba(Uint8List.fromList([0, 0, 0, 255]), 1, 1);
  }

  final List<Color> dummyPalette = List.generate(
    256,
    (_) => const Color(0xFF000000),
  );

  final int n = activeBmps.length;
  final List<List<List<Color>>> paddedPanels = [];
  for (int i = 0; i < n; i++) {
    paddedPanels.add(_padAndLabelPanel(activeBmps[i], dummyPalette));
  }

  final int combinedWidth = 80 * n;
  const int combinedHeight = 80;
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
    for (int p = 0; p < n; p++) {
      final panel = paddedPanels[p];
      for (int x = 0; x < 80; x++) {
        final color = panel[y][x];
        combined[offset] = color.blue;
        combined[offset + 1] = color.green;
        combined[offset + 2] = color.red;
        offset += 3;
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

  const CanvasModel({
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
  });

  CanvasModel copyWith({
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
  }) {
    return CanvasModel(
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
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CanvasModel) return false;
    return selectedColorIndex == other.selectedColorIndex &&
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

  static const int gridSize = 64;

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
    final currentBmp = generateBmp(state.grid, state.palette);

    if (referenceBmp != null) {
      bmpsToCombine.add(referenceBmp);
      final refGrid = _bmpToColorGrid(referenceBmp);

      final edgesGrid = _applyEdgeDetection(refGrid);
      final edgesBmp = _bmpFromColorGrid(edgesGrid);
      bmpsToCombine.add(edgesBmp);

      final blurredGrid = _applyGaussianBlur(refGrid);
      final quantizedGrid = _applyColorQuantization(blurredGrid, state.palette);
      final quantizedBmp = _bmpFromColorGrid(quantizedGrid);
      bmpsToCombine.add(quantizedBmp);
    }
    if (previousBmp != null) {
      bmpsToCombine.add(previousBmp);
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

  CanvasNotifier(this._aiService)
    : super(
        CanvasModel(
          grid: List.generate(gridSize, (_) => List.filled(gridSize, 0)),
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
        ),
      ) {
    checkAiStatus();
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
    final bmp = await resizeAndConvertToBmp(rawBytes);
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
      grid: List.generate(gridSize, (_) => List.filled(gridSize, 0)),
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
    if (x < 0 || x >= gridSize || y < 0 || y >= gridSize) return;
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
    command.execute(newGrid, state.selectedColorIndex, gridSize);
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

    final canvasBytes = Uint8List.fromList(utf8.encode(state.grid.toString()));
    final paletteHexes = state.palette
        .map(
          (c) => '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        )
        .toList();

    final previousBmp = state.undoStack.isNotEmpty
        ? generateBmp(state.undoStack.last, state.palette)
        : null;

    final combinedBmp = generateCombinedVisualInput(
      state.referenceImage,
      previousBmp,
    );

    // 1. Normal drawing action turn
    final isMultimodal = _aiService is MethodChannelAiService;
    final systemInstruction = formatSystemInstruction();
    final String currentCanvasTextGrid = canvasToTextGrid(state.grid);
    String? quantizedReferenceTextGrid;
    if (state.referenceImage != null) {
      final quantizedGrid = getQuantizedIndexGrid(
        state.referenceImage!,
        state.palette,
      );
      quantizedReferenceTextGrid = canvasToTextGrid(quantizedGrid);
    }

    final userTextPrompt = formatUserPrompt(
      canvasImage: canvasBytes,
      prompt: state.userPrompt,
      paletteColors: paletteHexes,
      isMultimodal: isMultimodal,
      hasPreviousImage: previousBmp != null,
      hasReferenceImage: state.referenceImage != null,
      currentCanvasTextGrid: currentCanvasTextGrid,
      quantizedReferenceTextGrid: quantizedReferenceTextGrid,
    );

    // Append recent action history to break repetition loops
    String historyPrompt = '';
    if (state.aiHistory.isNotEmpty) {
      final recentHistory = state.aiHistory.length > 5
          ? state.aiHistory.skip(state.aiHistory.length - 5).toList()
          : state.aiHistory;
      final historyItems = recentHistory
          .map((entry) {
            final cleanResponse = entry.response.replaceAll(
              RegExp(r'\s+'),
              ' ',
            );
            return '- $cleanResponse';
          })
          .join('\n');
      historyPrompt =
          '\n\nRecent suggestions history:\n$historyItems\n'
          'Avoid repeating these exact strokes and coordinates. Try drawing something new or in a different location.';
    }

    final fullPrompt =
        '$systemInstruction\n\n$userTextPrompt\n\n$historyPrompt';
    String rawResponse = '';
    bool isError = false;
    Uint8List? loggedBmp = combinedBmp;

    try {
      final painterResult = await _aiService.getNextStroke(
        canvasImage: combinedBmp,
        prompt: fullPrompt,
      );

      if (painterResult != null) {
        if (painterResult.containsKey('rawResponse')) {
          rawResponse = painterResult['rawResponse'] as String;
          isError = true;
        } else {
          final tool = painterResult['tool'] as String?;
          final params = (painterResult['params'] as List?)?.cast<int>();
          final colorIndex = painterResult['color'] as int?;

          if (tool != null &&
              params != null &&
              (colorIndex != null || tool == 'undo')) {
            // Apply the Painter's suggested stroke
            _applyAiStrokeCommand(tool, params, colorIndex ?? 0);

            // Generate the post-stroke visual input for the Critic to evaluate
            final postStrokePreviousBmp = state.undoStack.isNotEmpty
                ? generateBmp(state.undoStack.last, state.palette)
                : null;
            final postStrokeCombinedBmp = generateCombinedVisualInput(
              state.referenceImage,
              postStrokePreviousBmp,
            );
            loggedBmp = postStrokeCombinedBmp;

            // Run the Critic Agent to evaluate the stroke
            final criticResult = await _aiService.evaluateStroke(
              canvasImage: postStrokeCombinedBmp,
            );

            if (criticResult != null) {
              final criticAction = criticResult['action'] as String?;
              final criticReasoning = criticResult['reasoning'] as String?;

              if (criticAction == 'undo') {
                // Critic rejected the stroke. Revert it.
                undo();
                rawResponse = jsonEncode({
                  'painter': painterResult,
                  'critic': {
                    'action': 'undo',
                    'reasoning': criticReasoning ?? 'Rejected by critic.',
                  },
                });
              } else {
                // Critic accepted the stroke. Keep it.
                rawResponse = jsonEncode({
                  'painter': painterResult,
                  'critic': {
                    'action': 'keep',
                    'reasoning': criticReasoning ?? 'Approved.',
                  },
                });
              }
            } else {
              // Critic failed or returned null, default to keep
              rawResponse = jsonEncode({
                'painter': painterResult,
                'critic': {
                  'action': 'keep',
                  'reasoning': 'Critic evaluation unavailable, keeping stroke.',
                },
              });
            }
          } else {
            isError = true;
            rawResponse =
                'Invalid painter response: ${jsonEncode(painterResult)}';
          }
        }
      } else {
        isError = true;
        rawResponse = 'No stroke returned by the painter model.';
      }
    } catch (e) {
      isError = true;
      rawResponse = 'Error: $e';
      debugPrint('Error triggering AI stroke: $e');
    } finally {
      final newHistory = List<AgentHistoryEntry>.from(state.aiHistory)
        ..add(
          AgentHistoryEntry(
            timestamp: DateTime.now(),
            prompt: fullPrompt,
            response: rawResponse,
            isError: isError,
            imageBytes: loggedBmp,
          ),
        );
      state = state.copyWith(isGenerating: false, aiHistory: newHistory);
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
          await triggerAiStroke();
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

Future<Uint8List?> resizeAndConvertToBmp(Uint8List imageBytes) async {
  try {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frameInfo = await codec.getNextFrame();
    final originalImage = frameInfo.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(0, 0, 64, 64),
      image: originalImage,
      fit: BoxFit.cover,
    );

    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(64, 64);

    final byteData = await resizedImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return null;

    final rgbaBytes = byteData.buffer.asUint8List();
    return generateBmpFromRgba(rgbaBytes, 64, 64);
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
  final List<List<Color>> grid = List.generate(
    64,
    (_) => List.filled(64, const Color(0xFF000000)),
  );
  if (bmpBytes.length >= 54 + 64 * 64 * 3) {
    int offset = 54;
    for (int y = 63; y >= 0; y--) {
      for (int x = 0; x < 64; x++) {
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
  const int width = 64;
  const int height = 64;
  const int bytesPerPixel = 3;
  const int rowPadding = (4 - (width * bytesPerPixel) % 4) % 4;
  const int rowStride = width * bytesPerPixel + rowPadding;
  const int pixelDataSize = rowStride * height;
  const int fileSize = 54 + pixelDataSize;

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
  final List<List<Color>> dest = List.generate(
    64,
    (_) => List.filled(64, const Color(0xFF000000)),
  );
  final List<int> kernel = [1, 2, 1, 2, 4, 2, 1, 2, 1];
  const int kernelWeight = 16;

  for (int y = 0; y < 64; y++) {
    for (int x = 0; x < 64; x++) {
      int sumR = 0;
      int sumG = 0;
      int sumB = 0;

      for (int ky = -1; ky <= 1; ky++) {
        for (int kx = -1; kx <= 1; kx++) {
          final px = (x + kx).clamp(0, 63);
          final py = (y + ky).clamp(0, 63);
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
  final List<List<Color>> dest = List.generate(
    64,
    (_) => List.filled(64, const Color(0xFF000000)),
  );
  for (int y = 0; y < 64; y++) {
    for (int x = 0; x < 64; x++) {
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

List<List<Color>> _applyEdgeDetection(List<List<Color>> src) {
  final List<List<Color>> dest = List.generate(
    64,
    (_) => List.filled(64, const Color(0xFF000000)),
  );
  final List<List<int>> gray = List.generate(64, (_) => List.filled(64, 0));
  for (int y = 0; y < 64; y++) {
    for (int x = 0; x < 64; x++) {
      final color = src[y][x];
      gray[y][x] =
          (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue)
              .round();
    }
  }

  for (int y = 1; y < 63; y++) {
    for (int x = 1; x < 63; x++) {
      final val00 = gray[y - 1][x - 1];
      final val01 = gray[y - 1][x];
      final val02 = gray[y - 1][x + 1];
      final val10 = gray[y][x - 1];
      final val12 = gray[y][x + 1];
      final val20 = gray[y + 1][x - 1];
      final val21 = gray[y + 1][x];
      final val22 = gray[y + 1][x + 1];

      final gx = (val02 + 2 * val12 + val22) - (val00 + 2 * val10 + val20);
      final gy = (val20 + 2 * val21 + val22) - (val00 + 2 * val01 + val02);
      final magnitude = (gx * gx + gy * gy);
      if (magnitude > 900) {
        dest[y][x] = const Color(0xFFFFFFFF);
      } else {
        dest[y][x] = const Color(0xFF000000);
      }
    }
  }
  return dest;
}

List<List<int>> getQuantizedIndexGrid(Uint8List bmpBytes, List<Color> palette) {
  final List<List<int>> grid = List.generate(64, (_) => List.filled(64, 0));
  if (bmpBytes.length >= 54 + 64 * 64 * 3) {
    final refGrid = _bmpToColorGrid(bmpBytes);
    final blurredGrid = _applyGaussianBlur(refGrid);
    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
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

  // Header: 10s digits
  buffer.write('    ');
  for (int x = 0; x < 64; x++) {
    buffer.write(x >= 10 ? '${x ~/ 10}' : ' ');
  }
  buffer.write('\n');

  // Header: 1s digits
  buffer.write('    ');
  for (int x = 0; x < 64; x++) {
    buffer.write('${x % 10}');
  }
  buffer.write('\n');

  // Rows
  for (int y = 0; y < 64; y++) {
    buffer.write('${y.toString().padLeft(3)} ');
    for (int x = 0; x < 64; x++) {
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
