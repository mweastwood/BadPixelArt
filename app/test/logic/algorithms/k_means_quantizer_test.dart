import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/algorithms/k_means_quantizer.dart';

void main() {
  group('K-Means Color Quantizer Unit Tests', () {
    test('quantizes grid with fewer unique colors than k', () {
      const red = Color(0xFFFF0000);
      const green = Color(0xFF00FF00);

      final grid = [
        [red, green],
        [red, green],
      ];

      final palette = kMeansQuantize(grid, 4);
      expect(palette.length, equals(4));

      // Should contain the original unique colors
      expect(palette.any((c) => c.toARGB32() == red.toARGB32()), isTrue);
      expect(palette.any((c) => c.toARGB32() == green.toARGB32()), isTrue);
    });

    test('extracts dominant color clusters from grid', () {
      const red = Color(0xFFFF0000);
      const green = Color(0xFF00FF00);
      const blue = Color(0xFF0000FF);

      final grid = [
        [red, red, green],
        [blue, blue, green],
        [blue, red, green],
      ];

      final palette = kMeansQuantize(grid, 3);
      expect(palette.length, equals(3));

      // Should extract colors representing red, green, and blue clusters
      bool hasRed = false;
      bool hasGreen = false;
      bool hasBlue = false;

      for (final color in palette) {
        if (color.r > 0.8 && color.g < 0.1 && color.b < 0.1) hasRed = true;
        if (color.g > 0.8 && color.r < 0.1 && color.b < 0.1) hasGreen = true;
        if (color.b > 0.8 && color.r < 0.1 && color.g < 0.1) hasBlue = true;
      }

      expect(hasRed, isTrue, reason: 'Palette should contain a red cluster');
      expect(
        hasGreen,
        isTrue,
        reason: 'Palette should contain a green cluster',
      );
      expect(hasBlue, isTrue, reason: 'Palette should contain a blue cluster');
    });

    test(
      'weights high frequency colors more heavily during centroid computation',
      () {
        const darkRed = Color(0xFF800000);
        const brightRed = Color(0xFFFF0000);

        // Grid with 9 dark reds and 1 bright red
        final grid = [
          [darkRed, darkRed, darkRed],
          [darkRed, darkRed, darkRed],
          [darkRed, darkRed, brightRed],
        ];

        final palette = kMeansQuantize(grid, 1);
        expect(palette.length, equals(1));

        // Weighted average: (8 * 128 + 1 * 255) / 9 = (1024 + 255) / 9 = 1279 / 9 = 142
        // Channel R should be close to 142
        final redChannel = (palette.first.r * 255.0).round();
        expect(redChannel, inInclusiveRange(140, 145));
      },
    );

    test('returns exact colors when uniqueColors count matches k', () {
      const c1 = Color(0xFF112233);
      const c2 = Color(0xFF445566);
      const c3 = Color(0xFF778899);

      final grid = [
        [c1, c2, c3],
      ];

      final palette = kMeansQuantize(grid, 3);
      expect(palette.length, equals(3));
      expect(
        palette.map((c) => c.toARGB32()).toSet(),
        equals({c1.toARGB32(), c2.toARGB32(), c3.toARGB32()}),
      );
    });

    test(
      'returns empty list when k is 0 on non-empty grid without exception',
      () {
        const red = Color(0xFFFF0000);
        const green = Color(0xFF00FF00);
        final grid = [
          [red, green],
          [red, green],
        ];

        final palette = kMeansQuantize(grid, 0);
        expect(palette, isEmpty);
      },
    );

    test('returns empty list when k is negative', () {
      const red = Color(0xFFFF0000);
      final grid = [
        [red, red],
      ];

      expect(kMeansQuantize(grid, -1), isEmpty);
      expect(kMeansQuantize(grid, -4), isEmpty);
    });

    test('returns empty list when colorGrid is empty', () {
      expect(kMeansQuantize([], 4), isEmpty);
      expect(kMeansQuantize([], 0), isEmpty);
      expect(kMeansQuantize([], -1), isEmpty);
    });
  });
}
