import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../test_helper.dart';

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

    test('bmpToColorGrid handles empty and truncated headers gracefully', () {
      expect(bmpToColorGrid(Uint8List(0)), isEmpty);
      expect(bmpToColorGrid(Uint8List(10)), isEmpty);
      expect(bmpToColorGrid(Uint8List(53)), isEmpty);

      // Invalid magic bytes
      final invalidMagic = Uint8List(54);
      invalidMagic[0] = 0x00;
      invalidMagic[1] = 0x00;
      expect(bmpToColorGrid(invalidMagic), isEmpty);

      // Valid header magic, but zero width/height
      final zeroDims = Uint8List(54);
      zeroDims[0] = 0x42;
      zeroDims[1] = 0x4D;
      final bd = ByteData.sublistView(zeroDims);
      bd.setUint32(18, 0, Endian.little);
      bd.setUint32(22, 0, Endian.little);
      expect(bmpToColorGrid(zeroDims), isEmpty);

      // Truncated pixel data
      final truncatedData = Uint8List(54 + 4);
      truncatedData[0] = 0x42;
      truncatedData[1] = 0x4D;
      final bdTrunc = ByteData.sublistView(truncatedData);
      bdTrunc.setUint32(18, 4, Endian.little);
      bdTrunc.setUint32(22, 4, Endian.little);
      expect(bmpToColorGrid(truncatedData), isEmpty);
    });

    test(
      'getQuantizedIndexGrid handles empty and malformed inputs gracefully',
      () {
        expect(getQuantizedIndexGrid(Uint8List(0), testPalette), isEmpty);
        expect(getQuantizedIndexGrid(Uint8List(20), testPalette), isEmpty);
        expect(getQuantizedIndexGrid(Uint8List(54), []), isEmpty);
      },
    );

    test(
      'bmpToColorGrid and bmpFromColorGrid are symmetrical across all row padding sizes',
      () {
        final testDimensions = [
          (1, 1), // width 1 (3 bytes + 1 pad = 4 bytes)
          (2, 2), // width 2 (6 bytes + 2 pad = 8 bytes)
          (3, 3), // width 3 (9 bytes + 3 pad = 12 bytes)
          (4, 4), // width 4 (12 bytes + 0 pad = 12 bytes)
          (5, 5), // width 5 (15 bytes + 1 pad = 16 bytes)
          (6, 6), // width 6 (18 bytes + 2 pad = 20 bytes)
          (7, 7), // width 7 (21 bytes + 3 pad = 24 bytes)
          (8, 8), // width 8 (24 bytes + 0 pad = 24 bytes)
          (3, 5), // width 3, height 5
          (5, 2), // width 5, height 2
        ];

        final sampleColors = [
          const Color(0xFFFF0000),
          const Color(0xFF00FF00),
          const Color(0xFF0000FF),
          const Color(0xFFFFFF00),
          const Color(0xFF00FFFF),
          const Color(0xFFFF00FF),
          const Color(0xFFFFFFFF),
          const Color(0xFF000000),
        ];

        for (final (w, h) in testDimensions) {
          final grid = List.generate(
            h,
            (y) => List.generate(
              w,
              (x) => sampleColors[(y * w + x) % sampleColors.length],
            ),
          );

          final bmp = bmpFromColorGrid(grid);
          final parsedGrid = bmpToColorGrid(bmp);

          expect(
            parsedGrid.length,
            equals(h),
            reason: 'Height mismatch for ${w}x$h',
          );
          expect(
            parsedGrid[0].length,
            equals(w),
            reason: 'Width mismatch for ${w}x$h',
          );

          for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
              expect(
                parsedGrid[y][x].toARGB32(),
                equals(grid[y][x].toARGB32()),
                reason: 'Color mismatch at ($x, $y) for ${w}x$h',
              );
            }
          }
        }
      },
    );

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

      test(
        'combineBmps ignores malformed BMP elements and handles non-multiple-of-4 panel sizes',
        () {
          // Create 3x3 panels (width 3: row padding 3 bytes per row)
          final redGrid = List.generate(
            3,
            (_) => List.filled(3, const Color(0xFFFF0000)),
          );
          final greenGrid = List.generate(
            3,
            (_) => List.filled(3, const Color(0xFF00FF00)),
          );

          final bmpRed = bmpFromColorGrid(redGrid);
          final bmpGreen = bmpFromColorGrid(greenGrid);

          final malformedBmp = Uint8List.fromList([1, 2, 3, 4]); // Ignored
          final combined = combineBmps([bmpRed, malformedBmp, bmpGreen]);

          // Combined should have cols=2, rows=2, combinedWidth=6, combinedHeight=6
          // Stride: 6 * 3 = 18 bytes + 2 pad = 20 bytes
          final parsedCombined = bmpToColorGrid(combined);
          expect(parsedCombined.length, equals(6));
          expect(parsedCombined[0].length, equals(6));

          // Top-left panel: Red
          expect(
            parsedCombined[0][0].toARGB32(),
            equals(const Color(0xFFFF0000).toARGB32()),
          );
          expect(
            parsedCombined[2][2].toARGB32(),
            equals(const Color(0xFFFF0000).toARGB32()),
          );

          // Top-right panel: Green
          expect(
            parsedCombined[0][3].toARGB32(),
            equals(const Color(0xFF00FF00).toARGB32()),
          );
          expect(
            parsedCombined[2][5].toARGB32(),
            equals(const Color(0xFF00FF00).toARGB32()),
          );

          // Bottom panels: Black fillers
          expect(
            parsedCombined[3][0].toARGB32(),
            equals(const Color(0xFF000000).toARGB32()),
          );
          expect(
            parsedCombined[5][5].toARGB32(),
            equals(const Color(0xFF000000).toARGB32()),
          );
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

    test('resizeAndConvertToBmp handles invalid bytes gracefully', () async {
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4]);
      final result = await resizeAndConvertToBmp(invalidBytes, 16);
      expect(result, isNull);
    });

    test(
      'resizeAndConvertToBmp resizes valid image bytes to specified grid size BMP',
      () async {
        final grid = List.generate(4, (_) => List.filled(4, 1));
        final bmpBytes = generateBmp(grid, testPalette);
        final pngBytes = await convertToPngBytes(bmpBytes);

        final resizedBmp = await resizeAndConvertToBmp(pngBytes, 8);
        expect(resizedBmp, isNotNull);
        expect(resizedBmp![0], equals(0x42)); // 'B'
        expect(resizedBmp[1], equals(0x4D)); // 'M'

        final bd = ByteData.sublistView(resizedBmp);
        expect(bd.getUint32(18, Endian.little), equals(8)); // width
        expect(bd.getUint32(22, Endian.little), equals(8)); // height
      },
    );

    test(
      'setReferenceImage with originalBytes sets both referenceImage and originalReferenceImage',
      () {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(TestMockAiService())],
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
        overrides: [aiServiceProvider.overrideWithValue(TestMockAiService())],
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
      final mockAiService = TestMockAiService();
      final notifier = CanvasNotifier(mockAiService);

      notifier.setReferenceImage(Uint8List.fromList([1, 2, 3]));
      await notifier.suggestDescriptionFromReference();

      expect(notifier.state.userPrompt, isNotEmpty);
    });

    group('bmpToDownscaledColorGrid and downscaleColorGrid tests', () {
      test('bmpToDownscaledColorGrid handles invalid and truncated inputs', () {
        expect(bmpToDownscaledColorGrid(Uint8List(0), 16), isEmpty);
        expect(bmpToDownscaledColorGrid(Uint8List(10), 16), isEmpty);
        expect(bmpToDownscaledColorGrid(Uint8List(53), 16), isEmpty);
        expect(bmpToDownscaledColorGrid(Uint8List(100), 0), isEmpty);
        expect(bmpToDownscaledColorGrid(Uint8List(100), -5), isEmpty);

        // Invalid magic bytes
        final invalidMagic = Uint8List(54);
        invalidMagic[0] = 0x00;
        invalidMagic[1] = 0x00;
        expect(bmpToDownscaledColorGrid(invalidMagic, 16), isEmpty);

        // Zero dimensions
        final zeroDims = Uint8List(54);
        zeroDims[0] = 0x42;
        zeroDims[1] = 0x4D;
        final bd = ByteData.sublistView(zeroDims);
        bd.setUint32(18, 0, Endian.little);
        bd.setUint32(22, 0, Endian.little);
        expect(bmpToDownscaledColorGrid(zeroDims, 16), isEmpty);

        // Truncated data
        final truncData = Uint8List(54 + 4);
        truncData[0] = 0x42;
        truncData[1] = 0x4D;
        final bdTrunc = ByteData.sublistView(truncData);
        bdTrunc.setUint32(18, 16, Endian.little);
        bdTrunc.setUint32(22, 16, Endian.little);
        expect(bmpToDownscaledColorGrid(truncData, 16), isEmpty);
      });

      test('downscaleColorGrid handles empty inputs gracefully', () {
        expect(downscaleColorGrid([], 16), isEmpty);
        expect(downscaleColorGrid([[]], 16), isEmpty);
        expect(
          downscaleColorGrid([
            [Colors.red],
          ], 0),
          isEmpty,
        );
      });

      test(
        'bmpToDownscaledColorGrid produces identical output to downscaleColorGrid(bmpToColorGrid) across dimensions',
        () {
          final testSizes = [
            (8, 8, 4), // 8x8 -> 4x4
            (16, 16, 8), // 16x16 -> 8x8
            (32, 32, 16), // 32x32 -> 16x16
            (64, 64, 16), // 64x64 -> 16x16
            (64, 64, 24), // 64x64 -> 24x24
            (64, 64, 32), // 64x64 -> 32x32
            (15, 7, 8), // Odd widths with padding: 15x7 -> 8x8
            (7, 19, 16), // Odd dimensions: 7x19 -> 16x16
            (5, 5, 3), // 5x5 -> 3x3
            (128, 128, 16), // 128x128 -> 16x16
          ];

          for (final (w, h, targetSize) in testSizes) {
            final grid = List.generate(
              h,
              (y) => List.generate(
                w,
                (x) => Color.fromARGB(
                  255,
                  (x * 37 + y * 53) % 256,
                  (x * 97 + y * 13) % 256,
                  (x * 19 + y * 79) % 256,
                ),
              ),
            );

            final bmp = bmpFromColorGrid(grid);

            final directDownscaled = bmpToDownscaledColorGrid(bmp, targetSize);
            final intermediateDownscaled = downscaleColorGrid(
              bmpToColorGrid(bmp),
              targetSize,
            );

            expect(
              directDownscaled.length,
              equals(targetSize),
              reason: 'Height mismatch for ${w}x$h -> $targetSize',
            );
            expect(
              directDownscaled[0].length,
              equals(targetSize),
              reason: 'Width mismatch for ${w}x$h -> $targetSize',
            );

            for (int y = 0; y < targetSize; y++) {
              for (int x = 0; x < targetSize; x++) {
                expect(
                  directDownscaled[y][x].toARGB32(),
                  equals(intermediateDownscaled[y][x].toARGB32()),
                  reason:
                      'Pixel mismatch at ($x, $y) for ${w}x$h -> $targetSize',
                );
              }
            }
          }
        },
      );

      test('generateCombinedVisualInput downscales reference BMP directly', () {
        final mockAiService = TestMockAiService();
        final notifier = CanvasNotifier(mockAiService);

        final refGrid = List.generate(
          64,
          (y) => List.generate(
            64,
            (x) => (x + y) % 2 == 0 ? Colors.red : Colors.blue,
          ),
        );
        final refBmp = bmpFromColorGrid(refGrid);

        final combined = notifier.generateCombinedVisualInput(refBmp, null);
        expect(combined.isNotEmpty, isTrue);

        final parsed = bmpToColorGrid(combined);
        // Canvas size is 16x16, combined with ref image -> 32x32
        expect(parsed.length, equals(32));
        expect(parsed[0].length, equals(32));
      });
    });
  });
}
