import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bad_pixel_art/logic/ai_service.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';

class MockTestAiService implements AiService {
  AiCoreStatus status = AiCoreStatus.available;
  bool triggerDownloadCalled = false;
  Uint8List? lastCanvasImage;
  String? lastPrompt;
  Map<String, dynamic>? mockResult;

  @override
  Future<AiCoreStatus> checkStatus() async => status;

  @override
  Future<void> triggerDownload() async {
    triggerDownloadCalled = true;
    status = AiCoreStatus.available;
  }

  @override
  Future<Map<String, dynamic>?> getNextStroke({
    required Uint8List canvasImage,
    required String prompt,
  }) async {
    lastCanvasImage = canvasImage;
    lastPrompt = prompt;
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

    test('applyCircleFilled draws filled circle on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyCircleFilled(10, 10, 2);

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[10][10], equals(1));
      expect(grid[10][12], equals(1)); // border
      expect(grid[10][11], equals(1)); // inside
    });

    test('applyCircleHatched draws hatched circle on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyCircleHatched(10, 10, 2);

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[10][10], equals(1)); // (10+10)%2 == 0
      expect(grid[10][11], equals(0)); // (10+11)%2 == 1
    });

    test('applyRectangle draws outlined rectangle on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyRectangle(10, 10, 15, 15);

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[10][10], equals(1));
      expect(grid[10][15], equals(1));
      expect(grid[15][10], equals(1));
      expect(grid[15][15], equals(1));
      expect(grid[12][12], equals(0)); // inside should be empty
    });

    test('applyRectangleFilled draws filled rectangle on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyRectangleFilled(10, 10, 15, 15);

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[10][10], equals(1));
      expect(grid[15][15], equals(1));
      expect(grid[12][12], equals(1)); // inside should be filled
    });

    test('applyRectangleHatched draws hatched rectangle on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyRectangleHatched(10, 10, 15, 15);

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[10][10], equals(1)); // (10+10)%2 == 0
      expect(grid[10][11], equals(0)); // (10+11)%2 == 1
      expect(grid[12][12], equals(1)); // (12+12)%2 == 0
    });

    test('triggerAiStroke handles undo tool successfully', () async {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.drawPixel(10, 10); // make a stroke

      expect(container.read(canvasStateProvider).grid[10][10], equals(1));

      mockAiService.mockResult = {'tool': 'undo', 'params': <int>[]};

      await notifier.triggerAiStroke();
      expect(
        container.read(canvasStateProvider).grid[10][10],
        equals(0),
      ); // reverted
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

    test('generateBmp produces valid 24-bit BMP header and data', () {
      final grid = List.generate(64, (_) => List.filled(64, 0));
      grid[0][0] = 2;

      final bmp = generateBmp(grid, CanvasNotifier.primaryPalette);

      // Verify file size is 12342 bytes (54 header + 64 * 64 * 3)
      expect(bmp.length, equals(12342));

      // BM signature
      expect(bmp[0], equals(0x42)); // 'B'
      expect(bmp[1], equals(0x4D)); // 'M'

      final ByteData bd = ByteData.sublistView(bmp);

      // Offset to pixel data
      expect(bd.getUint32(10, Endian.little), equals(54));

      // DIB header size (40)
      expect(bd.getUint32(14, Endian.little), equals(40));

      // Width and Height (64)
      expect(bd.getUint32(18, Endian.little), equals(64));
      expect(bd.getUint32(22, Endian.little), equals(64));

      // Color planes (1)
      expect(bd.getUint16(26, Endian.little), equals(1));

      // Bits per pixel (24)
      expect(bd.getUint16(28, Endian.little), equals(24));

      // Compression (0 = BI_RGB)
      expect(bd.getUint32(30, Endian.little), equals(0));
    });

    group('combineBmps tests', () {
      test('combineBmps with empty list returns 1x1 dummy BMP', () {
        final combined = combineBmps([]);
        expect(
          combined.length,
          equals(58),
        ); // 54 header + 1 * 1 * 3 bytes + 1 padding byte = 58
        final ByteData bd = ByteData.sublistView(combined);
        expect(bd.getUint32(18, Endian.little), equals(1)); // width
        expect(bd.getUint32(22, Endian.little), equals(1)); // height
      });

      test('combineBmps with single BMP returns the original BMP', () {
        final grid = List.generate(64, (_) => List.filled(64, 0));
        final bmp = generateBmp(grid, CanvasNotifier.primaryPalette);
        final combined = combineBmps([bmp]);
        expect(combined, equals(bmp));
      });

      test('combineBmps with two BMPs concatenates side-by-side correctly', () {
        final grid1 = List.generate(
          64,
          (_) => List.filled(64, 2),
        ); // Filled with red (index 2)
        final grid2 = List.generate(
          64,
          (_) => List.filled(64, 4),
        ); // Filled with blue (index 4)

        final bmp1 = generateBmp(grid1, CanvasNotifier.primaryPalette);
        final bmp2 = generateBmp(grid2, CanvasNotifier.primaryPalette);

        final combined = combineBmps([bmp1, bmp2]);

        // File size should be 24630 (54 header + 128 * 64 * 3)
        expect(combined.length, equals(24630));

        final ByteData bd = ByteData.sublistView(combined);
        expect(bd.getUint32(18, Endian.little), equals(128)); // width
        expect(bd.getUint32(22, Endian.little), equals(64)); // height

        // Stride is 128 * 3 = 384. Pixel (10, 10) in left panel (grid1)
        final offsetLeft = 54 + 10 * 384 + 10 * 3;
        expect(combined[offsetLeft], equals(0)); // blue
        expect(combined[offsetLeft + 1], equals(0)); // green
        expect(combined[offsetLeft + 2], equals(255)); // red

        // Pixel (10, 10) in right panel (grid2), combined coordinate x = 74
        final offsetRight = 54 + 10 * 384 + 74 * 3;
        expect(combined[offsetRight], equals(255)); // blue
        expect(combined[offsetRight + 1], equals(0)); // green
        expect(combined[offsetRight + 2], equals(0)); // red
      });

      test(
        'combineBmps with three BMPs concatenates side-by-side correctly',
        () {
          final grid1 = List.generate(
            64,
            (_) => List.filled(64, 2),
          ); // Red (index 2)
          final grid2 = List.generate(
            64,
            (_) => List.filled(64, 3),
          ); // Green (index 3)
          final grid3 = List.generate(
            64,
            (_) => List.filled(64, 4),
          ); // Blue (index 4)

          final bmp1 = generateBmp(grid1, CanvasNotifier.primaryPalette);
          final bmp2 = generateBmp(grid2, CanvasNotifier.primaryPalette);
          final bmp3 = generateBmp(grid3, CanvasNotifier.primaryPalette);

          final combined = combineBmps([bmp1, bmp2, bmp3]);

          // File size should be 36918 (54 header + 192 * 64 * 3)
          expect(combined.length, equals(36918));

          final ByteData bd = ByteData.sublistView(combined);
          expect(bd.getUint32(18, Endian.little), equals(192)); // width
          expect(bd.getUint32(22, Endian.little), equals(64)); // height

          // Stride is 192 * 3 = 576.
          // Left panel (grid1): pixel (10, 10) -> combined x = 10
          final offsetLeft = 54 + 10 * 576 + 10 * 3;
          expect(combined[offsetLeft], equals(0)); // blue
          expect(combined[offsetLeft + 1], equals(0)); // green
          expect(combined[offsetLeft + 2], equals(255)); // red

          // Middle panel (grid2): pixel (10, 10) -> combined x = 74
          final offsetMiddle = 54 + 10 * 576 + 74 * 3;
          expect(combined[offsetMiddle], equals(0)); // blue
          expect(combined[offsetMiddle + 1], equals(255)); // green
          expect(combined[offsetMiddle + 2], equals(0)); // red

          // Right panel (grid3): pixel (10, 10) -> combined x = 138
          final offsetRight = 54 + 10 * 576 + 138 * 3;
          expect(combined[offsetRight], equals(255)); // blue
          expect(combined[offsetRight + 1], equals(0)); // green
          expect(combined[offsetRight + 2], equals(0)); // red
        },
      );
    });

    test(
      'triggerAiStroke formats paletteColors as 6-character hex values (RGB)',
      () async {
        mockAiService.mockResult = {
          'tool': 'line',
          'params': [0, 0, 5, 5],
          'color': 2,
        };

        final notifier = container.read(canvasStateProvider.notifier);
        await notifier.triggerAiStroke();

        expect(mockAiService.lastPrompt, isNotNull);
        final hexRegex = RegExp(r'#([0-9a-fA-F]{6})');
        final matches = hexRegex.allMatches(mockAiService.lastPrompt!);
        expect(matches.isNotEmpty, isTrue);
        for (final match in matches) {
          final hex = match.group(0)!;
          expect(hex, startsWith('#'));
          expect(hex.length, equals(7)); // #RRGGBB
          final hexValue = hex.substring(1);
          expect(int.tryParse(hexValue, radix: 16), isNotNull);
        }
      },
    );

    test(
      'setReferenceImage with originalBytes sets both referenceImage and originalReferenceImage',
      () {
        final notifier = container.read(canvasStateProvider.notifier);
        final rawPngBytes = Uint8List.fromList([0, 1, 2, 3]);
        final modelBmpBytes = Uint8List.fromList([4, 5, 6, 7]);

        notifier.setReferenceImage(modelBmpBytes, originalBytes: rawPngBytes);

        final state = container.read(canvasStateProvider);
        expect(state.originalReferenceImage, equals(rawPngBytes));
        expect(state.referenceImage, equals(modelBmpBytes));
      },
    );

    test(
      'triggerAiStroke passes combined canvas containing previous canvas to AI service if undo stack is not empty',
      () async {
        final notifier = container.read(canvasStateProvider.notifier);
        notifier.selectColor(1);
        notifier.drawPixel(10, 10); // push one stroke to undo stack

        mockAiService.mockResult = {
          'tool': 'line',
          'params': [0, 0, 5, 5],
          'color': 2,
        };

        await notifier.triggerAiStroke();
        expect(mockAiService.lastCanvasImage, isNotNull);
        expect(
          mockAiService.lastCanvasImage!.length,
          equals(24630), // 128x64 bmp length (previous + current canvas)
        );
      },
    );

    test('setting reference image to null clears both images', () {
      final notifier = container.read(canvasStateProvider.notifier);
      final rawPngBytes = Uint8List.fromList([0, 1, 2, 3]);
      final modelBmpBytes = Uint8List.fromList([4, 5, 6, 7]);

      notifier.setReferenceImage(modelBmpBytes, originalBytes: rawPngBytes);
      expect(container.read(canvasStateProvider).referenceImage, isNotNull);
      expect(
        container.read(canvasStateProvider).originalReferenceImage,
        isNotNull,
      );

      notifier.setReferenceImage(null);
      expect(container.read(canvasStateProvider).referenceImage, isNull);
      expect(
        container.read(canvasStateProvider).originalReferenceImage,
        isNull,
      );
    });
  });
}
