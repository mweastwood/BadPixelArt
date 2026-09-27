import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/rotated_rectangle_command.dart';

void main() {
  group('RotatedRectangleCommand Tests', () {
    test('draws axis-aligned rectangle (0 degrees)', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      // Draw 6x2 rectangle with 0 degree rotation (horizontal)
      RotatedRectangleCommand(4, 4, 6, 2, 0.0).execute(grid, 3, 8);

      expect(grid[4][4], equals(3));
      expect(grid[4][1], equals(3));
      expect(grid[4][7], equals(3));
      expect(grid[4][0], equals(0)); // beyond width
      expect(grid[2][4], equals(0)); // beyond height
    });

    test('draws rotated rectangle (90 degrees)', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      // Draw 6x2 rectangle rotated by 90 degrees (becomes 2x6 vertically)
      RotatedRectangleCommand(4, 4, 6, 2, 90.0).execute(grid, 2, 8);

      // Verify it is aligned vertically now
      expect(grid[4][4], equals(2));
      expect(grid[2][4], equals(2));
      expect(grid[6][4], equals(2));
      expect(grid[4][2], equals(0)); // wider horizontally should be empty
    });

    test(
      'draws rotated rectangle at 180 and 270 degrees producing symmetrical shapes',
      () {
        final grid180 = List.generate(9, (_) => List.filled(9, 0));
        final grid270 = List.generate(9, (_) => List.filled(9, 0));

        RotatedRectangleCommand(4, 4, 6, 2, 180.0).execute(grid180, 1, 9);
        RotatedRectangleCommand(4, 4, 6, 2, 270.0).execute(grid270, 1, 9);

        // Verify 180 degrees produces point-symmetric rasterization around center (4, 4)
        for (int y = 0; y < 9; y++) {
          for (int x = 0; x < 9; x++) {
            expect(grid180[y][x], equals(grid180[8 - y][8 - x]));
          }
        }
        expect(grid180[4][4], equals(1));

        // Verify 270 degrees produces point-symmetric rasterization around center (4, 4)
        for (int y = 0; y < 9; y++) {
          for (int x = 0; x < 9; x++) {
            expect(grid270[y][x], equals(grid270[8 - y][8 - x]));
          }
        }
        expect(grid270[4][4], equals(1));
      },
    );

    test(
      'handles negative angles and angles > 360 degrees equivalent to modular equivalents',
      () {
        final gridNeg = List.generate(8, (_) => List.filled(8, 0));
        final gridPos = List.generate(8, (_) => List.filled(8, 0));
        final gridOver360 = List.generate(8, (_) => List.filled(8, 0));

        RotatedRectangleCommand(4, 4, 6, 2, -45.0).execute(gridNeg, 1, 8);
        RotatedRectangleCommand(4, 4, 6, 2, 315.0).execute(gridPos, 1, 8);
        RotatedRectangleCommand(4, 4, 6, 2, 405.0).execute(gridOver360, 1, 8);

        expect(gridNeg, equals(gridPos));
        final grid45 = List.generate(8, (_) => List.filled(8, 0));
        RotatedRectangleCommand(4, 4, 6, 2, 45.0).execute(grid45, 1, 8);
        expect(gridOver360, equals(grid45));
      },
    );

    test('draws 45 degree diamond-like rotated rectangle symmetrically', () {
      final grid = List.generate(9, (_) => List.filled(9, 0));
      RotatedRectangleCommand(4, 4, 4, 4, 45.0).execute(grid, 5, 9);

      expect(grid[4][4], equals(5)); // center
      expect(grid[4][2], equals(5)); // left
      expect(grid[4][6], equals(5)); // right
      expect(grid[2][4], equals(5)); // top
      expect(grid[6][4], equals(5)); // bottom
      // Check symmetry
      for (int y = 0; y < 9; y++) {
        for (int x = 0; x < 9; x++) {
          expect(grid[y][x], equals(grid[8 - y][x]));
          expect(grid[y][x], equals(grid[y][8 - x]));
        }
      }
    });

    test(
      'elongated rectangle (8x2) draws interior pixels correctly within tight bounds',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        RotatedRectangleCommand(8, 8, 8, 2, 45.0).execute(grid, 7, 16);

        expect(grid[8][8], equals(7));
        // Pixels far away from diagonal should remain 0
        expect(grid[0][0], equals(0));
        expect(grid[15][15], equals(0));
        expect(grid[0][15], equals(0));
        expect(grid[15][0], equals(0));
      },
    );

    test('completely off-grid rectangles exit early without altering grid', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      // Completely to the left
      RotatedRectangleCommand(-20, 4, 6, 2, 45.0).execute(grid, 1, 8);
      // Completely to the right
      RotatedRectangleCommand(30, 4, 6, 2, 45.0).execute(grid, 1, 8);
      // Completely above
      RotatedRectangleCommand(4, -20, 6, 2, 45.0).execute(grid, 1, 8);
      // Completely below
      RotatedRectangleCommand(4, 30, 6, 2, 45.0).execute(grid, 1, 8);

      for (final row in grid) {
        for (final pixel in row) {
          expect(pixel, equals(0));
        }
      }
    });

    test('partially off-grid rectangles rasterize in-bounds pixels safely', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      // Center at top-left corner (0, 0)
      RotatedRectangleCommand(0, 0, 6, 6, 45.0).execute(grid, 4, 8);

      expect(grid[0][0], equals(4));
      // Center at bottom-right corner (7, 7)
      RotatedRectangleCommand(7, 7, 6, 6, 45.0).execute(grid, 4, 8);
      expect(grid[7][7], equals(4));
    });

    test('handles 1x1 rectangle', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      RotatedRectangleCommand(3, 3, 1, 1, 0.0).execute(grid, 9, 8);

      expect(grid[3][3], equals(9));
      expect(grid[3][2], equals(0));
      expect(grid[3][4], equals(0));
      expect(grid[2][3], equals(0));
      expect(grid[4][3], equals(0));
    });

    test('handles non-positive gridSize safely', () {
      final grid = <List<int>>[];
      expect(
        () => RotatedRectangleCommand(4, 4, 6, 2, 90.0).execute(grid, 1, 0),
        returnsNormally,
      );
      expect(
        () => RotatedRectangleCommand(4, 4, 6, 2, 90.0).execute(grid, 1, -1),
        returnsNormally,
      );
    });

    test(
      'handles zero or negative dimensions safely without modifying grid',
      () {
        final grid = List.generate(8, (_) => List.filled(8, 0));
        RotatedRectangleCommand(4, 4, 0, 4, 0.0).execute(grid, 1, 8);
        RotatedRectangleCommand(4, 4, 4, 0, 0.0).execute(grid, 1, 8);
        RotatedRectangleCommand(4, 4, -4, 4, 0.0).execute(grid, 1, 8);
        RotatedRectangleCommand(4, 4, 4, -4, 0.0).execute(grid, 1, 8);

        for (final row in grid) {
          for (final pixel in row) {
            expect(pixel, equals(0));
          }
        }
      },
    );
  });
}
