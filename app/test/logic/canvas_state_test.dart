import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_agent/local_agent.dart';
import 'package:bad_pixel_art/logic/prompts.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';

class MockTestAiService extends AiService {
  AiCoreStatus status = AiCoreStatus.available;
  bool triggerDownloadCalled = false;
  Uint8List? lastCanvasImage;
  String? lastPrompt;
  Map<String, dynamic>? mockResult;
  int callCount = 0;

  @override
  Future<AiCoreStatus> checkStatus() async => status;

  @override
  Future<void> triggerDownload() async {
    triggerDownloadCalled = true;
    status = AiCoreStatus.available;
  }

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    if (prompt.contains('pixel art describer')) {
      return 'Mock description of the canvas';
    }
    if (temperature <= 0.5 &&
        (prompt.contains('16 colors') || prompt.contains('8 colors'))) {
      final List<String> mockPalette = List.generate(8, (i) {
        final val = (i * 0x22).toRadixString(16).padLeft(2, '0');
        return '#$val$val$val';
      });
      return '["${mockPalette.join('", "')}"]';
    }

    if (prompt.contains('evaluating candidate drawings')) {
      return jsonEncode({
        'choice': 1,
        'reasoning': 'Critic picked 1',
        'nextFocus': 'Critic suggestion',
      });
    }

    lastCanvasImage = imageBytes;
    lastPrompt = prompt;

    if (prompt.contains('decomposer') || prompt.contains('Decompose')) {
      return '''
      [
        {
          "name": "blade",
          "description": "vertical blade",
          "relativeBoundingBox": { "left": 0.4, "top": 0.1, "width": 0.2, "height": 0.6 },
          "colorIndex": 1
        }
      ]
      ''';
    }

    if (mockResult == null) return null;

    if (mockResult!['tool'] == 'undo') {
      int turn = 1;
      if (prompt.contains('- {')) {
        turn = RegExp(r'- \{').allMatches(prompt).length + 1;
      }
      if (turn == 1) {
        return jsonEncode({
          'tool': 'pixel',
          'params': [10, 10],
          'color': 2,
        });
      } else {
        return jsonEncode({'tool': 'undo', 'params': []});
      }
    }

    return jsonEncode(mockResult);
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
      expect(model.grid.length, equals(CanvasNotifier.gridSize));
      expect(model.grid[0].length, equals(CanvasNotifier.gridSize));
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
      notifier.drawPixel(10, 12);

      final model = container.read(canvasStateProvider);
      expect(model.grid[12][10], equals(2));
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

    test(
      'triggerDecomposition runs DecomposerAgent and populates pendingDecompositionOptions',
      () async {
        final notifier = container.read(canvasStateProvider.notifier);
        expect(
          container.read(canvasStateProvider).decomposedComponents,
          isEmpty,
        );

        await notifier.triggerDecomposition();

        var model = container.read(canvasStateProvider);
        expect(model.pendingDecompositionOptions, hasLength(4));
        expect(model.decomposedComponents, isEmpty);

        // Apply Option 1
        notifier.applyDecompositionOption(0);
        model = container.read(canvasStateProvider);

        expect(model.pendingDecompositionOptions, isEmpty);
        expect(model.decomposedComponents, hasLength(1));
        expect(model.decomposedComponents.first.name, equals('blade'));
        expect(
          model.decomposedComponents.first.description,
          equals('vertical blade'),
        );
        // Snapped bounds verification:
        // After scaling and centering relative to the center of mass
        expect(
          model.decomposedComponents.first.relativeBoundingBox,
          equals(const Rect.fromLTWH(0.375, 0.0625, 0.25, 0.875)),
        );
      },
    );

    test('triggerDecomposition logs components in history', () async {
      final notifier = container.read(canvasStateProvider.notifier);
      expect(container.read(canvasStateProvider).aiHistory, isEmpty);

      await notifier.triggerDecomposition();

      final model = container.read(canvasStateProvider);
      expect(model.aiHistory, hasLength(4));
      expect(model.aiHistory.first.isError, isFalse);
      expect(
        model.aiHistory.first.prompt,
        contains('Decompose the drawing instruction'),
      );
      expect(model.aiHistory.first.response, contains('"name": "blade"'));
      expect(
        model.aiHistory.first.response,
        contains('"description": "vertical blade"'),
      );
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

    test('clearAiHistory clears the logs', () async {
      final notifier = container.read(canvasStateProvider.notifier);
      await notifier.triggerDecomposition();
      expect(container.read(canvasStateProvider).aiHistory, isNotEmpty);

      notifier.clearAiHistory();
      expect(container.read(canvasStateProvider).aiHistory, isEmpty);
    });

    test('generateBmp produces valid 24-bit BMP header and data', () {
      final grid = List.generate(
        CanvasNotifier.gridSize,
        (_) => List.filled(CanvasNotifier.gridSize, 0),
      );
      grid[0][0] = 2;

      final bmp = generateBmp(grid, CanvasNotifier.primaryPalette);

      // Verify file size is 822 bytes (54 header + 16 * 16 * 3)
      expect(bmp.length, equals(822));

      // BM signature
      expect(bmp[0], equals(0x42)); // 'B'
      expect(bmp[1], equals(0x4D)); // 'M'

      final ByteData bd = ByteData.sublistView(bmp);

      // Offset to pixel data
      expect(bd.getUint32(10, Endian.little), equals(54));

      // DIB header size (40)
      expect(bd.getUint32(14, Endian.little), equals(40));

      // Width and Height (16)
      expect(bd.getUint32(18, Endian.little), equals(CanvasNotifier.gridSize));
      expect(bd.getUint32(22, Endian.little), equals(CanvasNotifier.gridSize));

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

      test('combineBmps with single BMP returns 16x16 BMP', () {
        final grid = List.generate(
          CanvasNotifier.gridSize,
          (_) => List.filled(CanvasNotifier.gridSize, 0),
        );
        final bmp = generateBmp(grid, CanvasNotifier.primaryPalette);
        final combined = combineBmps([bmp]);
        expect(combined.length, equals(822)); // 54 header + 16 * 16 * 3 = 822
        final ByteData bd = ByteData.sublistView(combined);
        expect(bd.getUint32(18, Endian.little), equals(16)); // width
        expect(bd.getUint32(22, Endian.little), equals(16)); // height
      });

      test('combineBmps with two BMPs concatenates side-by-side correctly', () {
        final grid1 = List.generate(
          CanvasNotifier.gridSize,
          (_) => List.filled(CanvasNotifier.gridSize, 3),
        ); // Filled with red (index 3, maps to palette[2])
        final grid2 = List.generate(
          CanvasNotifier.gridSize,
          (_) => List.filled(CanvasNotifier.gridSize, 5),
        ); // Filled with blue (index 5, maps to palette[4])

        final bmp1 = generateBmp(grid1, CanvasNotifier.primaryPalette);
        final bmp2 = generateBmp(grid2, CanvasNotifier.primaryPalette);

        final combined = combineBmps([bmp1, bmp2]);

        // File size should be 3126 (54 header + 32 * 32 * 3)
        expect(combined.length, equals(3126));

        final ByteData bd = ByteData.sublistView(combined);
        expect(bd.getUint32(18, Endian.little), equals(32)); // width
        expect(bd.getUint32(22, Endian.little), equals(32)); // height

        // Stride is 32 * 3 = 96. Pixel (10, 10) in left panel (grid1) starts at y_bmp=26, x_bmp=10.
        final offsetLeft = 54 + 26 * 96 + 10 * 3;
        expect(combined[offsetLeft], equals(0)); // blue
        expect(combined[offsetLeft + 1], equals(0)); // green
        expect(combined[offsetLeft + 2], equals(255)); // red

        // Pixel (10, 10) in right panel (grid2) starts at y_bmp=26, x_bmp=16+10=26
        final offsetRight = 54 + 26 * 96 + 26 * 3;
        expect(combined[offsetRight], equals(255)); // blue
        expect(combined[offsetRight + 1], equals(0)); // green
        expect(combined[offsetRight + 2], equals(0)); // red
      });

      test(
        'combineBmps with three BMPs concatenates side-by-side correctly',
        () {
          final grid1 = List.generate(
            CanvasNotifier.gridSize,
            (_) => List.filled(CanvasNotifier.gridSize, 3),
          ); // Red (index 3, maps to palette[2])
          final grid2 = List.generate(
            CanvasNotifier.gridSize,
            (_) => List.filled(CanvasNotifier.gridSize, 4),
          ); // Green (index 4, maps to palette[3])
          final grid3 = List.generate(
            CanvasNotifier.gridSize,
            (_) => List.filled(CanvasNotifier.gridSize, 5),
          ); // Blue (index 5, maps to palette[4])

          final bmp1 = generateBmp(grid1, CanvasNotifier.primaryPalette);
          final bmp2 = generateBmp(grid2, CanvasNotifier.primaryPalette);
          final bmp3 = generateBmp(grid3, CanvasNotifier.primaryPalette);

          final combined = combineBmps([bmp1, bmp2, bmp3]);

          // File size should be 3126 (54 header + 32 * 32 * 3)
          expect(combined.length, equals(3126));

          final ByteData bd = ByteData.sublistView(combined);
          expect(bd.getUint32(18, Endian.little), equals(32)); // width
          expect(bd.getUint32(22, Endian.little), equals(32)); // height

          // Stride is 32 * 3 = 96.
          // Left panel (grid1): pixel (10, 10) -> padded y_bmp=26, x_bmp=10
          final offsetLeft = 54 + 26 * 96 + 10 * 3;
          expect(combined[offsetLeft], equals(0)); // blue
          expect(combined[offsetLeft + 1], equals(0)); // green
          expect(combined[offsetLeft + 2], equals(255)); // red

          // Middle panel (grid2): pixel (10, 10) -> padded y_bmp=26, x_bmp=26
          final offsetMiddle = 54 + 26 * 96 + 26 * 3;
          expect(combined[offsetMiddle], equals(0)); // blue
          expect(combined[offsetMiddle + 1], equals(255)); // green
          expect(combined[offsetMiddle + 2], equals(0)); // red

          // Right panel (grid3): pixel (10, 10) -> padded y_bmp=10, x_bmp=10
          final offsetRight = 54 + 10 * 96 + 10 * 3;
          expect(combined[offsetRight], equals(255)); // blue
          expect(combined[offsetRight + 1], equals(0)); // green
          expect(combined[offsetRight + 2], equals(0)); // red
        },
      );
    });

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

    group('AI Suggested Palette tests', () {
      test('parsePaletteColors parses clean JSON list correctly', () {
        const jsonResponse = '["#ff0000", "#00ff00", "#0000ff"]';
        final colors = parsePaletteColors(jsonResponse);
        expect(colors.length, equals(8));
        expect(colors[0], equals(const Color(0xFFFF0000)));
        expect(colors[1], equals(const Color(0xFF00FF00)));
        expect(colors[2], equals(const Color(0xFF0000FF)));
      });

      test('parsePaletteColors extracts colors via regex fallback', () {
        const textResponse =
            'Here are the suggested colors: #ff55aa and #00bbcc.';
        final colors = parsePaletteColors(textResponse);
        expect(colors.length, equals(8));
        expect(colors[0], equals(const Color(0xFFFF55AA)));
        expect(colors[1], equals(const Color(0xFF00BBCC)));
      });

      test(
        'suggestPaletteFromReference triggers suggestion and shows palette',
        () async {
          final notifier = container.read(canvasStateProvider.notifier);
          final refBmp = Uint8List.fromList([1, 2, 3]);
          notifier.setReferenceImage(refBmp);

          await notifier.suggestPaletteFromReference();

          final state = container.read(canvasStateProvider);
          expect(state.suggestedPalette, isNotNull);
          expect(state.suggestedPalette!.length, equals(8));
          expect(state.showPaletteSuggestion, isTrue);
        },
      );

      test('acceptSuggestedPalette updates palette and resets canvas', () {
        final notifier = container.read(canvasStateProvider.notifier);
        final suggested = List.generate(8, (i) => Color(0xFF000000 + i));

        notifier.state = notifier.state.copyWith(
          suggestedPalette: suggested,
          showPaletteSuggestion: true,
        );

        notifier.acceptSuggestedPalette();

        final state = container.read(canvasStateProvider);
        expect(state.paletteName, equals('suggested'));
        expect(state.palette, equals(suggested));
        expect(state.showPaletteSuggestion, isFalse);
        expect(state.selectedColorIndex, equals(0));
      });

      test('rejectSuggestedPalette clears suggestion', () {
        final notifier = container.read(canvasStateProvider.notifier);
        final suggested = List.generate(16, (i) => Color(0xFF000000 + i));

        notifier.state = notifier.state.copyWith(
          suggestedPalette: suggested,
          showPaletteSuggestion: true,
        );

        notifier.rejectSuggestedPalette();

        final state = container.read(canvasStateProvider);
        expect(state.showPaletteSuggestion, isFalse);
        expect(state.suggestedPalette, isNull);
      });

      test(
        'changeResolution switches grid size and clears history/undo/redo stacks',
        () {
          final notifier = container.read(canvasStateProvider.notifier);

          expect(notifier.state.gridSize, equals(16));
          expect(notifier.state.grid.length, equals(16));

          notifier.drawPixel(0, 0);
          expect(notifier.state.undoStack.isNotEmpty, isTrue);

          notifier.changeResolution(8);

          final updatedState = container.read(canvasStateProvider);
          expect(updatedState.gridSize, equals(8));
          expect(updatedState.grid.length, equals(8));
          expect(updatedState.grid[0].length, equals(8));
          expect(updatedState.undoStack.isEmpty, isTrue);
          expect(updatedState.redoStack.isEmpty, isTrue);

          notifier.changeResolution(12);
          expect(container.read(canvasStateProvider).gridSize, equals(8));
        },
      );
    });
  });
}
