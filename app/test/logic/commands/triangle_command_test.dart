import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/triangle_command.dart';

void main() {
  group('TriangleCommand Tests', () {
    test('draws solid triangle', () {
      final grid = List.generate(6, (_) => List.filled(6, 0));
      TriangleCommand(0, 0, 4, 0, 0, 4).execute(grid, 3, 6);

      // Verify some points inside the triangle bounds
      expect(grid[0][0], equals(3));
      expect(grid[1][1], equals(3));
      expect(grid[2][2], equals(3));
      expect(grid[4][0], equals(3));
      // Point outside bounds
      expect(grid[5][5], equals(0));
    });

    test(
      'does not modify grid when triangle is completely out of bounds (negative)',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        TriangleCommand(-10, -10, -5, -5, -10, -5).execute(grid, 3, 16);

        for (final row in grid) {
          for (final val in row) {
            expect(val, equals(0));
          }
        }
      },
    );

    test(
      'does not modify grid when triangle is completely out of bounds (positive)',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        TriangleCommand(20, 20, 25, 25, 20, 25).execute(grid, 3, 16);

        for (final row in grid) {
          for (final val in row) {
            expect(val, equals(0));
          }
        }
      },
    );

    test('partially out of bounds only draws within grid bounds', () {
      final grid = List.generate(6, (_) => List.filled(6, 0));
      TriangleCommand(-2, -2, 4, -2, -2, 4).execute(grid, 3, 6);

      // Point (0, 0) is inside triangle and in grid bounds
      expect(grid[0][0], equals(3));
      // Points far away outside the triangle remain 0
      expect(grid[5][5], equals(0));
      expect(grid[4][4], equals(0));
    });

    test('handles non-positive gridSize safely', () {
      final grid = <List<int>>[];
      expect(
        () => TriangleCommand(0, 0, 2, 0, 0, 2).execute(grid, 1, 0),
        returnsNormally,
      );
      expect(
        () => TriangleCommand(0, 0, 2, 0, 0, 2).execute(grid, 1, -5),
        returnsNormally,
      );
    });

    test('draws identically regardless of vertex winding order', () {
      final gridCw = List.generate(6, (_) => List.filled(6, 0));
      final gridCcw = List.generate(6, (_) => List.filled(6, 0));
      TriangleCommand(0, 0, 4, 0, 0, 4).execute(gridCw, 3, 6);
      TriangleCommand(0, 0, 0, 4, 4, 0).execute(gridCcw, 3, 6);

      for (int y = 0; y < 6; y++) {
        for (int x = 0; x < 6; x++) {
          expect(gridCw[y][x], equals(gridCcw[y][x]));
        }
      }
    });

    test(
      'handles degenerate triangle with identical vertices (single point)',
      () {
        final grid = List.generate(6, (_) => List.filled(6, 0));
        TriangleCommand(2, 2, 2, 2, 2, 2).execute(grid, 5, 6);

        for (int y = 0; y < 6; y++) {
          for (int x = 0; x < 6; x++) {
            if (x == 2 && y == 2) {
              expect(grid[y][x], equals(5));
            } else {
              expect(grid[y][x], equals(0));
            }
          }
        }
      },
    );

    test('handles degenerate collinear triangle along horizontal line', () {
      final grid = List.generate(6, (_) => List.filled(6, 0));
      TriangleCommand(1, 3, 4, 3, 2, 3).execute(grid, 4, 6);

      for (int y = 0; y < 6; y++) {
        for (int x = 0; x < 6; x++) {
          if (y == 3 && x >= 1 && x <= 4) {
            expect(grid[y][x], equals(4));
          } else {
            expect(grid[y][x], equals(0));
          }
        }
      }
    });

    test('handles degenerate collinear triangle along diagonal', () {
      final grid = List.generate(6, (_) => List.filled(6, 0));
      TriangleCommand(1, 1, 3, 3, 2, 2).execute(grid, 4, 6);

      for (int y = 0; y < 6; y++) {
        for (int x = 0; x < 6; x++) {
          if (x == y && x >= 1 && x <= 3) {
            expect(grid[y][x], equals(4));
          } else {
            expect(grid[y][x], equals(0));
          }
        }
      }
    });
  });
}
