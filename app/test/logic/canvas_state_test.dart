import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bad_pixel_art/logic/ai_service.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';

class MockTestAiService implements AiService {
  AiCoreStatus status = AiCoreStatus.available;
  Map<String, dynamic>? mockResult;
  bool triggerDownloadCalled = false;

  @override
  Future<AiCoreStatus> checkStatus() async => status;

  @override
  Future<void> triggerDownload() async {
    triggerDownloadCalled = true;
    status = AiCoreStatus.available;
  }

  @override
  Future<Map<String, dynamic>?> getNextStroke({
    required Uint8List? referenceImage,
    required Uint8List canvasImage,
    required String prompt,
    required List<String> paletteColors,
    Uint8List? canvasBmpBytes,
  }) async {
    return mockResult;
  }
}

void main() {
  group('CanvasNotifier Unit Tests', () {
    late MockTestAiService mockAiService;
    late ProviderContainer container;

    setUp(() {
      mockAiService = MockTestAiService();
      container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(mockAiService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is correct', () {
      final model = container.read(canvasStateProvider);
      expect(model.selectedColorIndex, equals(1));
      expect(model.selectedTool, equals(CanvasTool.line));
      expect(model.paletteName, equals('primary'));
      expect(model.isGenerating, isFalse);
      expect(model.autoRun, isFalse);
      expect(model.undoStack, isEmpty);
      expect(model.redoStack, isEmpty);
      expect(model.grid.length, equals(64));
      expect(model.grid[0].length, equals(64));
    });

    test('selectPalette resets canvas and changes palette', () {
      final notifier = container.read(canvasStateProvider.notifier);

      notifier.drawPixel(5, 5); // Draw a pixel
      expect(container.read(canvasStateProvider).undoStack, isNotEmpty);

      notifier.selectPalette('grayscale');
      final model = container.read(canvasStateProvider);
      expect(model.paletteName, equals('grayscale'));
      expect(model.palette.length, equals(4));
      expect(model.grid[5][5], equals(0)); // Reset canvas check
      expect(model.undoStack, isEmpty);
    });

    test('selectColor updates selectedColorIndex', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(3);
      expect(container.read(canvasStateProvider).selectedColorIndex, equals(3));

      // Invalid color index should be ignored
      notifier.selectColor(99);
      expect(container.read(canvasStateProvider).selectedColorIndex, equals(3));
    });

    test('selectTool updates selectedTool', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectTool(CanvasTool.circle);
      expect(
        container.read(canvasStateProvider).selectedTool,
        equals(CanvasTool.circle),
      );
    });

    test('drawPixel draws on grid and saves to undo stack', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(2);
      notifier.drawPixel(10, 20);

      final model = container.read(canvasStateProvider);
      expect(model.grid[20][10], equals(2));
      expect(model.undoStack.length, equals(1));
      expect(model.redoStack, isEmpty);
    });

    test('undo and redo work correctly', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);

      notifier.drawPixel(5, 5); // Stroke 1
      notifier.drawPixel(10, 10); // Stroke 2

      expect(container.read(canvasStateProvider).grid[5][5], equals(1));
      expect(container.read(canvasStateProvider).grid[10][10], equals(1));

      // Undo Stroke 2
      notifier.undo();
      expect(container.read(canvasStateProvider).grid[5][5], equals(1));
      expect(container.read(canvasStateProvider).grid[10][10], equals(0));

      // Undo Stroke 1
      notifier.undo();
      expect(container.read(canvasStateProvider).grid[5][5], equals(0));
      expect(container.read(canvasStateProvider).grid[10][10], equals(0));

      // Redo Stroke 1
      notifier.redo();
      expect(container.read(canvasStateProvider).grid[5][5], equals(1));
      expect(container.read(canvasStateProvider).grid[10][10], equals(0));

      // Redo Stroke 2
      notifier.redo();
      expect(container.read(canvasStateProvider).grid[5][5], equals(1));
      expect(container.read(canvasStateProvider).grid[10][10], equals(1));
    });

    test('applyLine draws line on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(3);
      notifier.applyLine(0, 0, 5, 0); // Horizontal line

      final grid = container.read(canvasStateProvider).grid;
      for (int i = 0; i <= 5; i++) {
        expect(grid[0][i], equals(3));
      }
    });

    test('applyCircle draws circle outline on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(2);
      notifier.applyCircle(10, 10, 3);

      final grid = container.read(canvasStateProvider).grid;
      // Midpoint circle should set xc + r, yc which is (13, 10)
      expect(grid[10][13], equals(2));
      expect(grid[10][7], equals(2));
      expect(grid[13][10], equals(2));
      expect(grid[7][10], equals(2));
    });

    test('applyFill fills region with color', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyLine(5, 5, 5, 10);
      notifier.applyLine(5, 5, 10, 5);
      notifier.applyLine(10, 5, 10, 10);
      notifier.applyLine(5, 10, 10, 10); // Simple 5x5 bounding square

      notifier.selectColor(2);
      notifier.applyFill(7, 7); // Fill center

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[7][7], equals(2));
      expect(grid[6][6], equals(2));
      expect(grid[0][0], equals(0)); // Outside bounds remains unfilled
    });

    test('applyHatch fills region with checkerboard hatch pattern', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyHatch(10, 10);

      final grid = container.read(canvasStateProvider).grid;
      // Checks alternate pixels
      expect(grid[10][10], equals(1));
      expect(grid[10][11], equals(0));
      expect(grid[11][10], equals(0));
      expect(grid[11][11], equals(1));
    });

    test('triggerAiStroke applies strokes returned by AI', () async {
      mockAiService.mockResult = {
        'tool': 'circle',
        'params': [15, 15, 5],
        'color': 2,
      };

      final notifier = container.read(canvasStateProvider.notifier);
      await notifier.triggerAiStroke();

      final model = container.read(canvasStateProvider);
      expect(model.selectedColorIndex, equals(2));
      expect(model.grid[15][20], equals(2)); // xc+r = 15+5 = 20
    });

    test('triggerDownload calls AI service download', () async {
      mockAiService.status = AiCoreStatus.downloadable;
      final notifier = container.read(canvasStateProvider.notifier);

      await notifier.triggerDownload();
      expect(mockAiService.triggerDownloadCalled, isTrue);
      expect(
        container.read(canvasStateProvider).aiStatus,
        equals(AiCoreStatus.available),
      );
    });

    test('triggerAiStroke logs prompt and response in history', () async {
      mockAiService.mockResult = {
        'tool': 'line',
        'params': [0, 0, 5, 5],
        'color': 2,
      };

      final notifier = container.read(canvasStateProvider.notifier);
      expect(container.read(canvasStateProvider).aiHistory, isEmpty);

      await notifier.triggerAiStroke();

      final model = container.read(canvasStateProvider);
      expect(model.aiHistory, hasLength(1));
      expect(model.aiHistory.first.isError, isFalse);
      expect(model.aiHistory.first.prompt, contains('AI pixel art assistant'));
      expect(model.aiHistory.first.response, contains('"tool":"line"'));
    });

    test('clearAiHistory clears the logs', () async {
      mockAiService.mockResult = {
        'tool': 'line',
        'params': [0, 0, 5, 5],
        'color': 2,
      };

      final notifier = container.read(canvasStateProvider.notifier);
      await notifier.triggerAiStroke();
      expect(container.read(canvasStateProvider).aiHistory, isNotEmpty);

      notifier.clearAiHistory();
      expect(container.read(canvasStateProvider).aiHistory, isEmpty);
    });
  });
}
