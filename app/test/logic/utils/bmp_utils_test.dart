import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/utils/bmp_utils.dart';

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

    test('combineBmps behaves correctly for different list sizes', () {
      final combinedEmpty = combineBmps([]);
      expect(
        combinedEmpty.length,
        equals(58),
      ); // 54 + 1 * 1 * 3 + 1 padding = 58

      final grid = List.generate(16, (_) => List.filled(16, 0));
      final bmp = generateBmp(grid, testPalette);
      final combinedSingle = combineBmps([bmp]);
      expect(combinedSingle.length, equals(822));
    });
  });
}
