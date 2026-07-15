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
  });
}
