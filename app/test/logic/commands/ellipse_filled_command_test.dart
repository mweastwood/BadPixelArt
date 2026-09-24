import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/ellipse_filled_command.dart';

void main() {
  group('EllipseFilledCommand Tests', () {
    test('fills ellipse', () {
      final grid = List.generate(7, (_) => List.filled(7, 0));
      EllipseFilledCommand(3, 3, 3, 2).execute(grid, 5, 7);

      expect(grid[3][3], equals(5));
      expect(grid[3][0], equals(5));
      expect(grid[3][6], equals(5));
    });

    test(
      'filled ellipse with fractional center on 16x16 is left-right symmetric',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        EllipseFilledCommand(7.5, 7.5, 5.5, 3.5).execute(grid, 1, 16);

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
      'filled ellipse with fractional center on 16x16 is top-bottom symmetric',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        EllipseFilledCommand(7.5, 7.5, 5.5, 3.5).execute(grid, 1, 16);

        for (int y = 0; y < 8; y++) {
          for (int x = 0; x < 16; x++) {
            expect(
              grid[15 - y][x],
              equals(grid[y][x]),
              reason: 'Top-bottom mismatch at X=$x: Y=$y vs Y=${15 - y}',
            );
          }
        }
      },
    );

    test('handles non-positive gridSize safely', () {
      final grid = <List<int>>[];
      expect(
        () => EllipseFilledCommand(3, 3, 3, 2).execute(grid, 5, 0),
        returnsNormally,
      );
      expect(
        () => EllipseFilledCommand(3, 3, 3, 2).execute(grid, 5, -1),
        returnsNormally,
      );
    });

    test('handles radii smaller than 0.5 by clamping to 0.5', () {
      final grid = List.generate(5, (_) => List.filled(5, 0));
      EllipseFilledCommand(2, 2, 0.1, 0.2).execute(grid, 9, 5);

      // Clamped to 0.5, so at (2, 2) dx=0, dy=0, dist=0 <= 1.0 -> fills pixel (2, 2)
      expect(grid[2][2], equals(9));
      // Adjacent pixels are at distance 1.0 / 0.5 = 2.0 > 1.0
      expect(grid[2][1], equals(0));
      expect(grid[2][3], equals(0));
      expect(grid[1][2], equals(0));
      expect(grid[3][2], equals(0));
    });

    test('handles ellipse partially outside grid boundaries', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      expect(
        () => EllipseFilledCommand(-2, -1, 5, 4).execute(grid, 3, 8),
        returnsNormally,
      );
      // Ensure in-bounds pixels of the ellipse got drawn
      expect(grid[0][0], equals(3));
      // Ensure right/bottom unaffected
      expect(grid[7][7], equals(0));
    });

    test(
      'handles ellipse completely outside grid boundaries without error',
      () {
        final grid = List.generate(8, (_) => List.filled(8, 0));
        expect(
          () => EllipseFilledCommand(20, 20, 3, 3).execute(grid, 7, 8),
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
      'handles ellipse completely outside grid horizontally without filling pixels',
      () {
        final gridRight = List.generate(8, (_) => List.filled(8, 0));
        EllipseFilledCommand(20, 4, 3, 3).execute(gridRight, 7, 8);
        for (final row in gridRight) {
          for (final pixel in row) {
            expect(pixel, equals(0));
          }
        }

        final gridLeft = List.generate(8, (_) => List.filled(8, 0));
        EllipseFilledCommand(-10, 4, 2, 2).execute(gridLeft, 7, 8);
        for (final row in gridLeft) {
          for (final pixel in row) {
            expect(pixel, equals(0));
          }
        }
      },
    );

    test('correctly fills asymmetric ellipse on 16x16 grid', () {
      final grid = List.generate(16, (_) => List.filled(16, 0));
      EllipseFilledCommand(8, 8, 6, 3).execute(grid, 2, 16);

      // Check center
      expect(grid[8][8], equals(2));
      // Check horizontal extrema: rx=6 -> x from 2 to 14 at y=8
      expect(grid[8][2], equals(2));
      expect(grid[8][14], equals(2));
      expect(grid[8][1], equals(0));
      expect(grid[8][15], equals(0));
      // Check vertical extrema: ry=3 -> y from 5 to 11 at x=8
      expect(grid[5][8], equals(2));
      expect(grid[11][8], equals(2));
      expect(grid[4][8], equals(0));
      expect(grid[12][8], equals(0));
    });
  });
}
