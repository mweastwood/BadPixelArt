import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/hatch_command.dart';

void main() {
  group('HatchCommand Tests', () {
    test('flood fills checkerboard pattern', () {
      final grid = [
        [0, 1, 0, 0],
        [0, 1, 0, 0],
        [0, 1, 1, 0],
        [0, 0, 0, 0],
      ];

      // Hatch starting at (0, 0)
      HatchCommand(0, 0).execute(grid, 3, 4);

      // (0,0) -> filled
      // (0,1) -> (0+1)%2 == 1 -> empty
      // (0,2) -> (0+2)%2 == 0 -> filled
      expect(grid[0], equals([3, 1, 3, 0]));
      expect(grid[1], equals([0, 1, 0, 3]));
      expect(grid[2], equals([3, 1, 1, 0]));
      expect(grid[3], equals([0, 3, 0, 3]));
    });

    test('no-op when start coordinate is out of bounds', () {
      final grid = [
        [0, 0],
        [0, 0],
      ];
      HatchCommand(-1, 0).execute(grid, 3, 2);
      HatchCommand(0, 5).execute(grid, 3, 2);
      expect(
        grid,
        equals([
          [0, 0],
          [0, 0],
        ]),
      );
    });

    test('no-op when target color is already destination color', () {
      final grid = [
        [3, 3],
        [3, 3],
      ];
      HatchCommand(0, 0).execute(grid, 3, 2);
      expect(
        grid,
        equals([
          [3, 3],
          [3, 3],
        ]),
      );
    });

    test('hatches uniform 3x3 grid properly', () {
      final grid = [
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
      ];
      HatchCommand(0, 0).execute(grid, 7, 3);
      expect(
        grid,
        equals([
          [7, 0, 7],
          [0, 7, 0],
          [7, 0, 7],
        ]),
      );
    });
  });
}
