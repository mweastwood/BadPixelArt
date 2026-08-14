import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockBmpAiService extends AiService {
  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

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
    if (prompt.contains('pixel art describer') ||
        prompt.contains('reference image depicts')) {
      return 'Mock description of reference image';
    }
    return null;
  }

  @override
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    return 100;
  }
}

void main() {
  group('BMP Utils Tests', () {
    final List<Color> testPalette = [
      const Color(0xFF000000), // Black
      const Color(0xFFFFFFFF), // White
      const Color(0xFFFF0000), // Red
      const Color(0xFF00FF00), // Green
      const Color(0xFF0000FF), // Blue
    ];

    test('generateBmp produces valid 24-bit BMP header and data', () {
      final grid = List.generate(16, (_) => List.filled(16, 0));
      grid[0][0] = 2; // maps to palette[1] = White

      final bmp = generateBmp(grid, testPalette);

      expect(bmp.length, equals(822)); // 54 header + 16 * 16 * 3 = 822
      expect(bmp[0], equals(0x42)); // 'B'
      expect(bmp[1], equals(0x4D)); // 'M'

      final ByteData bd = ByteData.sublistView(bmp);
      expect(bd.getUint32(10, Endian.little), equals(54)); // offset
      expect(bd.getUint32(18, Endian.little), equals(16)); // width
      expect(bd.getUint32(22, Endian.little), equals(16)); // height
      expect(bd.getUint16(28, Endian.little), equals(24)); // bits per pixel
    });

    test('generateBmpFromRgba builds correct BMP bytes', () {
      final rgba = Uint8List.fromList([
        255, 0, 0, 255, // Red
        0, 255, 0, 255, // Green
        0, 0, 255, 255, // Blue
        255, 255, 255, 255, // White
      ]);

      final bmp = generateBmpFromRgba(rgba, 2, 2);

      // 2x2 grid. Stride with padding: 2 * 3 = 6 bytes per row. Padding to 4-byte boundary: 2 bytes padding.
      // Total stride = 8 bytes.
      // Total size = 54 + 2 * 8 = 70 bytes.
      expect(bmp.length, equals(70));
      expect(bmp[0], equals(0x42));
      expect(bmp[1], equals(0x4D));
    });

    test('bmpToColorGrid and bmpFromColorGrid are symmetrical', () {
      final grid = List.generate(
        4,
        (y) => List.generate(
          4,
          (x) => (x + y) % 2 == 0 ? Colors.red : Colors.blue,
        ),
      );

      final bmp = bmpFromColorGrid(grid);
      final parsedGrid = bmpToColorGrid(bmp);

      expect(parsedGrid.length, equals(4));
      expect(parsedGrid[0][0].toARGB32(), equals(Colors.red.toARGB32()));
      expect(parsedGrid[0][1].toARGB32(), equals(Colors.blue.toARGB32()));
    });

    test('applyGaussianBlur blurs grid colors', () {
      final grid = List.generate(3, (_) => List.filled(3, Colors.black));
      grid[1][1] = Colors.white; // Single white pixel in center

      final blurred = applyGaussianBlur(grid);
      expect(blurred[1][1].toARGB32(), isNot(Colors.white.toARGB32()));
      expect(
        blurred[0][0].toARGB32(),
        isNot(Colors.black.toARGB32()),
      ); // corner got some blur weight
    });

    test('applyColorQuantization maps colors to closest palette color', () {
      final src = [
        [const Color(0xFFFF1010), const Color(0xFF0510FE)],
        [const Color(0xFF0510FE), const Color(0xFFFF1010)],
      ];
      final palette = [const Color(0xFFFF0000), const Color(0xFF0000FF)];

      final quantized = applyColorQuantization(src, palette);
      expect(
        quantized[0][0].toARGB32(),
        equals(const Color(0xFFFF0000).toARGB32()),
      );
      expect(
        quantized[0][1].toARGB32(),
        equals(const Color(0xFF0000FF).toARGB32()),
      );
    });

    test('canvasToTextGrid outputs readable text grid', () {
      final grid = [
        [0, 1, 2],
        [9, 10, 35],
        [0, 0, 0],
      ];
      final textGrid = canvasToTextGrid(grid);
      expect(textGrid, contains('.'));
      expect(textGrid, contains('1'));
      expect(textGrid, contains('2'));
      expect(textGrid, contains('9'));
      expect(textGrid, contains('A')); // index 10 maps to 'A'
      expect(textGrid, contains('Z')); // index 35 maps to 'Z'
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

    test('convertToPngBytes converts BMP image bytes to PNG format', () async {
      final grid = List.generate(4, (_) => List.filled(4, 1));
      final bmpBytes = generateBmp(grid, testPalette);
      expect(bmpBytes[0], equals(0x42)); // BMP magic 'B'
      expect(bmpBytes[1], equals(0x4D)); // BMP magic 'M'

      final pngBytes = await convertToPngBytes(bmpBytes);
      expect(pngBytes.length, greaterThan(0));
      expect(pngBytes[0], equals(0x89));
      expect(pngBytes[1], equals(0x50)); // 'P'
      expect(pngBytes[2], equals(0x4E)); // 'N'
      expect(pngBytes[3], equals(0x47)); // 'G'
    });

    test(
      'convertToPngBytes returns original bytes if already PNG or empty',
      () async {
        final empty = Uint8List(0);
        final resultEmpty = await convertToPngBytes(empty);
        expect(resultEmpty.length, equals(0));

        final mockPng = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]);
        final resultPng = await convertToPngBytes(mockPng);
        expect(resultPng, equals(mockPng));
      },
    );

    test(
      'setReferenceImage with originalBytes sets both referenceImage and originalReferenceImage',
      () {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(MockBmpAiService())],
        );
        addTearDown(container.dispose);

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
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(MockBmpAiService())],
      );
      addTearDown(container.dispose);

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

    test('suggestDescriptionFromReference updates userPrompt', () async {
      final mockAiService = MockBmpAiService();
      final notifier = CanvasNotifier(mockAiService);

      notifier.setReferenceImage(Uint8List.fromList([1, 2, 3]));
      await notifier.suggestDescriptionFromReference();

      expect(notifier.state.userPrompt, isNotEmpty);
    });
  });
}
