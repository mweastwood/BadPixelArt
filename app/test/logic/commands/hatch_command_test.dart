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
  });
}
