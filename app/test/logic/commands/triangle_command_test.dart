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
  });
}
