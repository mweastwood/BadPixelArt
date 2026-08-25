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

    test('no-op when start coordinate is out of bounds', () {
      final grid = [
        [0, 0],
        [0, 0],
      ];
      FillCommand(-1, 0).execute(grid, 2, 2);
      FillCommand(0, 5).execute(grid, 2, 2);
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
        [2, 2],
        [2, 2],
      ];
      FillCommand(0, 0).execute(grid, 2, 2);
      expect(
        grid,
        equals([
          [2, 2],
          [2, 2],
        ]),
      );
    });

    test('fills entire uniform grid', () {
      final grid = [
        [1, 1, 1],
        [1, 1, 1],
        [1, 1, 1],
      ];
      FillCommand(1, 1).execute(grid, 5, 3);
      expect(
        grid,
        equals([
          [5, 5, 5],
          [5, 5, 5],
          [5, 5, 5],
        ]),
      );
    });
  });
}
