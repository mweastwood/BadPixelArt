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
