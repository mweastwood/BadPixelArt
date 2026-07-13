import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/fill_command.dart';

void main() {
  group('FillCommand Tests', () {
    test('flood fills empty sector', () {
      final grid = [
        [0, 1, 0, 0],
        [0, 1, 0, 0],
        [0, 1, 1, 0],
        [0, 0, 0, 0],
      ];

      // Fill starting at (0, 0)
      FillCommand(0, 0).execute(grid, 2, 4);

      expect(grid[0], equals([2, 1, 2, 2]));
      expect(grid[1], equals([2, 1, 2, 2]));
      expect(grid[2], equals([2, 1, 1, 2]));
      expect(grid[3], equals([2, 2, 2, 2]));
    });
  });
}
