import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/ellipse_command.dart';

void main() {
  group('EllipseCommand Tests', () {
    test('draws outline ellipse', () {
      final grid = List.generate(7, (_) => List.filled(7, 0));
      EllipseCommand(3, 3, 3, 2).execute(grid, 6, 7);

      // Outline boundaries should be drawn
      expect(grid[3][0], equals(6));
      expect(grid[3][6], equals(6));
      expect(grid[1][3], equals(6));
      expect(grid[5][3], equals(6));
      // Center remains empty
      expect(grid[3][3], equals(0));
    });

    test(
      'ellipse outline with fractional center on 16x16 is left-right symmetric',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        // Fractional center ensures the rasterised outline is symmetric by
        // construction (both halves use the same Euclidean distance).
        EllipseCommand(7.5, 7.5, 5.5, 3.5).execute(grid, 1, 16);

        for (int y = 0; y < 16; y++) {
          for (int x = 0; x < 8; x++) {
            expect(
              grid[y][x],
              equals(grid[y][15 - x]),
              reason: 'Left-right mismatch at Y=$y: X=$x vs X=${15 - x}',
            );
          }
        }
      },
    );

    test(
      'ellipse outline with fractional center on 16x16 is top-bottom symmetric',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        EllipseCommand(7.5, 7.5, 5.5, 3.5).execute(grid, 1, 16);

        for (int y = 0; y < 8; y++) {
          for (int x = 0; x < 16; x++) {
            expect(
              grid[y][x],
              equals(grid[15 - y][x]),
              reason: 'Top-bottom mismatch at X=$x: Y=$y vs Y=${15 - y}',
            );
          }
        }
      },
    );

    test('handles non-positive gridSize safely', () {
      final grid = <List<int>>[];
      expect(
        () => EllipseCommand(3, 3, 3, 2).execute(grid, 6, 0),
        returnsNormally,
      );
      expect(
        () => EllipseCommand(3, 3, 3, 2).execute(grid, 6, -1),
        returnsNormally,
      );
    });

    test('handles radii smaller than 0.5 by clamping to 0.5', () {
      final gridSubHalf = List.generate(5, (_) => List.filled(5, 0));
      final gridHalf = List.generate(5, (_) => List.filled(5, 0));

      expect(
        () => EllipseCommand(2, 2, 0.1, 0.2).execute(gridSubHalf, 9, 5),
        returnsNormally,
      );
      EllipseCommand(2, 2, 0.5, 0.5).execute(gridHalf, 9, 5);

      expect(gridSubHalf, equals(gridHalf));
    });

    test('handles ellipse partially outside grid boundaries', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      expect(
        () => EllipseCommand(-1, -1, 4, 4).execute(grid, 3, 8),
        returnsNormally,
      );
      // Ensure in-bounds pixels of the outline got drawn
      bool hasDrawnPixel = false;
      for (final row in grid) {
        if (row.contains(3)) {
          hasDrawnPixel = true;
          break;
        }
      }
      expect(hasDrawnPixel, isTrue);
    });

    test(
      'handles ellipse completely outside grid boundaries without error or modification',
      () {
        final grid = List.generate(8, (_) => List.filled(8, 0));
        expect(
          () => EllipseCommand(25, 25, 3, 3).execute(grid, 7, 8),
          returnsNormally,
        );
        for (final row in grid) {
          for (final pixel in row) {
            expect(pixel, equals(0));
          }
        }
      },
    );

    test(
      'handles ellipse completely outside grid horizontally or vertically without drawing pixels',
      () {
        // Far right
        final gridRight = List.generate(8, (_) => List.filled(8, 0));
        EllipseCommand(20, 4, 3, 3).execute(gridRight, 7, 8);
        for (final row in gridRight) {
          for (final pixel in row) {
            expect(pixel, equals(0));
          }
        }

        // Far left
        final gridLeft = List.generate(8, (_) => List.filled(8, 0));
        EllipseCommand(-15, 4, 3, 3).execute(gridLeft, 7, 8);
        for (final row in gridLeft) {
          for (final pixel in row) {
            expect(pixel, equals(0));
          }
        }

        // Far top
        final gridTop = List.generate(8, (_) => List.filled(8, 0));
        EllipseCommand(4, -15, 3, 3).execute(gridTop, 7, 8);
        for (final row in gridTop) {
          for (final pixel in row) {
            expect(pixel, equals(0));
          }
        }

        // Far bottom
        final gridBottom = List.generate(8, (_) => List.filled(8, 0));
        EllipseCommand(4, 25, 3, 3).execute(gridBottom, 7, 8);
        for (final row in gridBottom) {
          for (final pixel in row) {
            expect(pixel, equals(0));
          }
        }
      },
    );

    test(
      'preserves cardinal pole pixels for radii >= 7 without bounding box clipping',
      () {
        final grid = List.generate(32, (_) => List.filled(32, 0));
        EllipseCommand(15, 15, 13, 13).execute(grid, 5, 32);

        // Cardinal poles at distance 15 from center (15, 15):
        // Left pole (x = 0, y = 14..16)
        expect(grid[14][0], equals(5));
        expect(grid[15][0], equals(5));
        expect(grid[16][0], equals(5));

        // Right pole (x = 30, y = 14..16)
        expect(grid[14][30], equals(5));
        expect(grid[15][30], equals(5));
        expect(grid[16][30], equals(5));

        // Top pole (y = 0, x = 14..16)
        expect(grid[0][14], equals(5));
        expect(grid[0][15], equals(5));
        expect(grid[0][16], equals(5));

        // Bottom pole (y = 30, x = 14..16)
        expect(grid[30][14], equals(5));
        expect(grid[30][15], equals(5));
        expect(grid[30][16], equals(5));
      },
    );

    test(
      'renders boundary intersection for ellipse centered outside canvas without premature early return',
      () {
        final grid = List.generate(8, (_) => List.filled(8, 0));
        // Center is at (-15, 0), rx=13, ry=13. Pixel (0, 0) satisfies dist = (15/13)^2 ≈ 1.331 <= 1.35
        EllipseCommand(-15, 0, 13, 13).execute(grid, 4, 8);

        expect(grid[0][0], equals(4));
      },
    );
  });
}
