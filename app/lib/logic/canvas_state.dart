// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_service.dart';

enum CanvasTool { line, circle, fill, hatch }

class AiHistoryEntry {
  final DateTime timestamp;
  final String prompt;
  final String response;
  final bool isError;
  final Uint8List? canvasImage;

  const AiHistoryEntry({
    required this.timestamp,
    required this.prompt,
    required this.response,
    this.isError = false,
    this.canvasImage,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AiHistoryEntry) return false;
    return timestamp == other.timestamp &&
        prompt == other.prompt &&
        response == other.response &&
        isError == other.isError &&
        listEquals(canvasImage, other.canvasImage);
  }

  @override
  int get hashCode => Object.hash(
    timestamp,
    prompt,
    response,
    isError,
    canvasImage != null ? Object.hashAll(canvasImage!) : null,
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
          : palette[colorIndex];

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

@immutable
class CanvasModel {
  final List<List<int>> grid;
  final int selectedColorIndex;
  final CanvasTool selectedTool;
  final String paletteName;
  final List<Color> palette;
  final Uint8List? referenceImage;
  final String userPrompt;
  final AiCoreStatus aiStatus;
  final bool isGenerating;
  final bool autoRun;
  final double autoRunSpeed; // in seconds
  final List<List<List<int>>> undoStack;
  final List<List<List<int>>> redoStack;
  final List<AiHistoryEntry> aiHistory;

  const CanvasModel({
    required this.grid,
    required this.selectedColorIndex,
    required this.selectedTool,
    required this.paletteName,
    required this.palette,
    this.referenceImage,
    required this.userPrompt,
    required this.aiStatus,
    required this.isGenerating,
    required this.autoRun,
    required this.autoRunSpeed,
    required this.undoStack,
    required this.redoStack,
    required this.aiHistory,
  });

  CanvasModel copyWith({
    List<List<int>>? grid,
    int? selectedColorIndex,
    CanvasTool? selectedTool,
    String? paletteName,
    List<Color>? palette,
    Uint8List? referenceImage,
    String? userPrompt,
    AiCoreStatus? aiStatus,
    bool? isGenerating,
    bool? autoRun,
    double? autoRunSpeed,
    List<List<List<int>>>? undoStack,
    List<List<List<int>>>? redoStack,
    List<AiHistoryEntry>? aiHistory,
  }) {
    return CanvasModel(
      grid: grid ?? this.grid,
      selectedColorIndex: selectedColorIndex ?? this.selectedColorIndex,
      selectedTool: selectedTool ?? this.selectedTool,
      paletteName: paletteName ?? this.paletteName,
      palette: palette ?? this.palette,
      referenceImage: referenceImage ?? this.referenceImage,
      userPrompt: userPrompt ?? this.userPrompt,
      aiStatus: aiStatus ?? this.aiStatus,
      isGenerating: isGenerating ?? this.isGenerating,
      autoRun: autoRun ?? this.autoRun,
      autoRunSpeed: autoRunSpeed ?? this.autoRunSpeed,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      aiHistory: aiHistory ?? this.aiHistory,
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
        listEquals(palette, other.palette) &&
        listEquals(referenceImage, other.referenceImage) &&
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
    Object.hashAll(palette),
    referenceImage != null ? Object.hashAll(referenceImage!) : null,
    Object.hashAll(aiHistory),
  );
}

class CanvasNotifier extends StateNotifier<CanvasModel> {
  final AiService _aiService;
  Timer? _autoRunTimer;

  static const int gridSize = 64;

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
    if (index >= 0 && index < state.palette.length) {
      state = state.copyWith(selectedColorIndex: index);
    }
  }

  void selectTool(CanvasTool tool) {
    state = state.copyWith(selectedTool: tool);
  }

  void updatePrompt(String prompt) {
    state = state.copyWith(userPrompt: prompt);
  }

  void setReferenceImage(Uint8List? bytes) {
    state = state.copyWith(referenceImage: bytes);
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

  void applyLine(int x1, int y1, int x2, int y2) {
    _pushToUndo(state.grid);
    final newGrid = state.grid.map((row) => List<int>.from(row)).toList();
    _drawLineAlg(newGrid, x1, y1, x2, y2, state.selectedColorIndex);
    state = state.copyWith(grid: newGrid);
  }

  void applyCircle(int cx, int cy, int r) {
    _pushToUndo(state.grid);
    final newGrid = state.grid.map((row) => List<int>.from(row)).toList();
    _drawCircleAlg(newGrid, cx, cy, r, state.selectedColorIndex);
    state = state.copyWith(grid: newGrid);
  }

  void applyFill(int startX, int startY) {
    _pushToUndo(state.grid);
    final newGrid = state.grid.map((row) => List<int>.from(row)).toList();
    _floodFillAlg(newGrid, startX, startY, state.selectedColorIndex);
    state = state.copyWith(grid: newGrid);
  }

  void applyHatch(int startX, int startY) {
    _pushToUndo(state.grid);
    final newGrid = state.grid.map((row) => List<int>.from(row)).toList();
    _hatchFillAlg(newGrid, startX, startY, state.selectedColorIndex);
    state = state.copyWith(grid: newGrid);
  }

  // Core algorithms
  void _drawLineAlg(
    List<List<int>> grid,
    int x1,
    int y1,
    int x2,
    int y2,
    int color,
  ) {
    int dx = (x2 - x1).abs();
    int dy = (y2 - y1).abs();
    int sx = x1 < x2 ? 1 : -1;
    int sy = y1 < y2 ? 1 : -1;
    int err = dx - dy;

    while (true) {
      if (x1 >= 0 && x1 < gridSize && y1 >= 0 && y1 < gridSize) {
        grid[y1][x1] = color;
      }
      if (x1 == x2 && y1 == y2) break;
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x1 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y1 += sy;
      }
    }
  }

  void _drawCircleAlg(List<List<int>> grid, int xc, int yc, int r, int color) {
    int x = 0;
    int y = r;
    int d = 3 - 2 * r;

    void drawCirclePoints(int xc, int yc, int x, int y, int color) {
      void setPixel(int px, int py) {
        if (px >= 0 && px < gridSize && py >= 0 && py < gridSize) {
          grid[py][px] = color;
        }
      }

      setPixel(xc + x, yc + y);
      setPixel(xc - x, yc + y);
      setPixel(xc + x, yc - y);
      setPixel(xc - x, yc - y);
      setPixel(xc + y, yc + x);
      setPixel(xc - y, yc + x);
      setPixel(xc + y, yc - x);
      setPixel(xc - y, yc - x);
    }

    drawCirclePoints(xc, yc, x, y, color);
    while (y >= x) {
      x++;
      if (d > 0) {
        y--;
        d = d + 4 * (x - y) + 10;
      } else {
        d = d + 4 * x + 6;
      }
      drawCirclePoints(xc, yc, x, y, color);
    }
  }

  void _floodFillAlg(
    List<List<int>> grid,
    int startX,
    int startY,
    int newColor,
  ) {
    if (startX < 0 || startX >= gridSize || startY < 0 || startY >= gridSize) {
      return;
    }
    int targetColor = grid[startY][startX];
    if (targetColor == newColor) return;

    List<List<int>> queue = [
      [startX, startY],
    ];
    while (queue.isNotEmpty) {
      var curr = queue.removeLast();
      int cx = curr[0];
      int cy = curr[1];

      if (grid[cy][cx] == targetColor) {
        grid[cy][cx] = newColor;

        if (cx > 0) queue.add([cx - 1, cy]);
        if (cx < gridSize - 1) queue.add([cx + 1, cy]);
        if (cy > 0) queue.add([cx, cy - 1]);
        if (cy < gridSize - 1) queue.add([cx, cy + 1]);
      }
    }
  }

  void _hatchFillAlg(
    List<List<int>> grid,
    int startX,
    int startY,
    int newColor,
  ) {
    if (startX < 0 || startX >= gridSize || startY < 0 || startY >= gridSize) {
      return;
    }
    int targetColor = grid[startY][startX];
    if (targetColor == newColor) return;

    List<List<int>> queue = [
      [startX, startY],
    ];
    Set<String> visited = {};

    while (queue.isNotEmpty) {
      var curr = queue.removeLast();
      int cx = curr[0];
      int cy = curr[1];
      String key = "$cx,$cy";
      if (visited.contains(key)) continue;
      visited.add(key);

      if (grid[cy][cx] == targetColor) {
        if ((cx + cy) % 2 == 0) {
          grid[cy][cx] = newColor;
        }

        if (cx > 0) queue.add([cx - 1, cy]);
        if (cx < gridSize - 1) queue.add([cx + 1, cy]);
        if (cy > 0) queue.add([cx, cy - 1]);
        if (cy < gridSize - 1) queue.add([cx, cy + 1]);
      }
    }
  }

  // Triggering next stroke from AI service
  Future<void> triggerAiStroke() async {
    if (state.isGenerating) return;
    state = state.copyWith(isGenerating: true);

    final canvasBytes = Uint8List.fromList(utf8.encode(state.grid.toString()));
    final paletteHexes = state.palette
        .map((c) => '#${c.value.toRadixString(16).padLeft(8, '0')}')
        .toList();

    final canvasBmp = generateBmp(state.grid, state.palette);

    final isMultimodal = _aiService is MethodChannelAiService;
    final systemInstruction = formatSystemInstruction();
    final userTextPrompt = formatUserPrompt(
      referenceImage: state.referenceImage,
      canvasImage: canvasBytes,
      prompt: state.userPrompt,
      paletteColors: paletteHexes,
      isMultimodal: isMultimodal,
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

    final fullPrompt = '$systemInstruction\n\n$userTextPrompt$historyPrompt';
    String rawResponse = '';
    bool isError = false;

    try {
      final result = await _aiService.getNextStroke(
        referenceImage: state.referenceImage,
        canvasImage: canvasBytes,
        prompt: '${state.userPrompt}$historyPrompt',
        paletteColors: paletteHexes,
        canvasBmpBytes: canvasBmp,
      );

      if (result != null) {
        rawResponse = jsonEncode(result);
        final tool = result['tool'] as String?;
        final params = (result['params'] as List?)?.cast<int>();
        final colorIndex = result['color'] as int?;

        if (tool != null && params != null && colorIndex != null) {
          _applyAiStrokeCommand(tool, params, colorIndex);
        }
      } else {
        rawResponse = 'No stroke returned by the model.';
      }
    } catch (e) {
      isError = true;
      rawResponse = 'Error: $e';
      debugPrint('Error triggering AI stroke: $e');
    } finally {
      final newHistory = List<AiHistoryEntry>.from(state.aiHistory)
        ..add(
          AiHistoryEntry(
            timestamp: DateTime.now(),
            prompt: fullPrompt,
            response: rawResponse,
            isError: isError,
            canvasImage: canvasBmp,
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
    final boundedColorIndex = colorIndex.clamp(0, state.palette.length - 1);

    // Set notifier's current drawing color to match AI's stroke color
    state = state.copyWith(selectedColorIndex: boundedColorIndex);

    switch (toolName) {
      case 'line':
        if (params.length >= 4) {
          applyLine(params[0], params[1], params[2], params[3]);
        }
        break;
      case 'circle':
        if (params.length >= 3) {
          applyCircle(params[0], params[1], params[2]);
        }
        break;
      case 'fill':
        if (params.length >= 2) {
          applyFill(params[0], params[1]);
        }
        break;
      case 'hatch':
        if (params.length >= 2) {
          applyHatch(params[0], params[1]);
        }
        break;
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
