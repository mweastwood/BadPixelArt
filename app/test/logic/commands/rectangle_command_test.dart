import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/rectangle_command.dart';

void main() {
  group('RectangleCommand Tests', () {
    test('draws outline rectangle', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      RectangleCommand(1, 1, 3, 3).execute(grid, 2, 4);

      expect(grid[1].sublist(1, 4), equals([2, 2, 2]));
      expect(grid[2].sublist(1, 4), equals([2, 0, 2]));
      expect(grid[3].sublist(1, 4), equals([2, 2, 2]));
    });

    test('inverted coordinate pairs produce identical outline', () {
      final baseGrid = List.generate(4, (_) => List.filled(4, 0));
      final invertedBoth = List.generate(4, (_) => List.filled(4, 0));
      final invertedMixed = List.generate(4, (_) => List.filled(4, 0));

      RectangleCommand(1, 1, 3, 3).execute(baseGrid, 2, 4);
      RectangleCommand(3, 3, 1, 1).execute(invertedBoth, 2, 4);
      RectangleCommand(3, 1, 1, 3).execute(invertedMixed, 2, 4);

      expect(invertedBoth, equals(baseGrid));
      expect(invertedMixed, equals(baseGrid));
    });

    test('draws a single-pixel rectangle', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      RectangleCommand(2, 2, 2, 2).execute(grid, 5, 4);

      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          if (x == 2 && y == 2) {
            expect(grid[y][x], equals(5));
          } else {
            expect(grid[y][x], equals(0));
          }
        }
      }
    });

    test('clips partially out-of-bounds rectangle safely within grid', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      RectangleCommand(-1, -1, 2, 2).execute(grid, 3, 4);

      // startX=-1, endX=2, startY=-1, endY=2
      // Outline at y=2 for x in [0, 2]: grid[2][0], grid[2][1], grid[2][2] are colored
      // Outline at x=2 for y in [0, 2]: grid[0][2], grid[1][2], grid[2][2] are colored
      expect(grid[0], equals([0, 0, 3, 0]));
      expect(grid[1], equals([0, 0, 3, 0]));
      expect(grid[2], equals([3, 3, 3, 0]));
      expect(grid[3], equals([0, 0, 0, 0]));
    });

    test(
      'leaves grid unaltered when rectangle is completely out of bounds',
      () {
        final grid = List.generate(4, (_) => List.filled(4, 0));
        RectangleCommand(-5, -5, -1, -1).execute(grid, 2, 4);
        RectangleCommand(5, 5, 8, 8).execute(grid, 2, 4);
        final empty = List.generate(4, (_) => List.filled(4, 0));
        expect(grid, equals(empty));
      },
    );
  });
}
