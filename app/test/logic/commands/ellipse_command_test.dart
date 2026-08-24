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
  });
}
