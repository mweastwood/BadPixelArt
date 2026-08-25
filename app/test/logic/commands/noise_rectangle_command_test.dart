import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/noise_rectangle_command.dart';

void main() {
  group('NoiseRectangleCommand Tests', () {
    test('noise fills rectangle area', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      NoiseRectangleCommand(0, 0, 3, 3, 42).execute(grid, 5, 4);

      // Verify that some pixels are filled with 5, and some remain transparent (0)
      bool hasColor = false;
      bool hasBackground = false;
      for (final row in grid) {
        for (final val in row) {
          if (val == 5) hasColor = true;
          if (val == 0) hasBackground = true;
        }
      }
      expect(hasColor, isTrue);
      expect(hasBackground, isTrue);
    });

    test(
      'does not modify grid when rectangle is completely out of bounds (negative)',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        NoiseRectangleCommand(-10, -10, -5, -5, 42).execute(grid, 1, 16);

        for (final row in grid) {
          for (final val in row) {
            expect(val, equals(0));
          }
        }
      },
    );

    test(
      'does not modify grid when rectangle is completely out of bounds (positive)',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        NoiseRectangleCommand(20, 20, 25, 25, 42).execute(grid, 1, 16);

        for (final row in grid) {
          for (final val in row) {
            expect(val, equals(0));
          }
        }
      },
    );

    test('partially out of bounds only draws within grid bounds', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      NoiseRectangleCommand(-2, -2, 1, 1, 42).execute(grid, 3, 4);

      // Pixels strictly outside (x > 1 or y > 1) must remain 0
      for (int y = 2; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          expect(grid[y][x], equals(0));
        }
      }
      for (int y = 0; y < 4; y++) {
        for (int x = 2; x < 4; x++) {
          expect(grid[y][x], equals(0));
        }
      }
    });

    test('handles inverted coordinates properly', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      NoiseRectangleCommand(3, 3, 0, 0, 42).execute(grid, 2, 4);

      bool hasDrawn = false;
      for (final row in grid) {
        for (final val in row) {
          if (val == 2) hasDrawn = true;
        }
      }
      expect(hasDrawn, isTrue);
    });

    test('handles non-positive gridSize safely', () {
      final grid = <List<int>>[];
      expect(
        () => NoiseRectangleCommand(0, 0, 2, 2, 42).execute(grid, 1, 0),
        returnsNormally,
      );
      expect(
        () => NoiseRectangleCommand(0, 0, 2, 2, 42).execute(grid, 1, -5),
        returnsNormally,
      );
    });
  });
}
