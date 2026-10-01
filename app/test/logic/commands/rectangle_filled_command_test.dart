import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/rectangle_filled_command.dart';

void main() {
  group('RectangleFilledCommand Tests', () {
    test('draws solid rectangle within canvas bounds', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      RectangleFilledCommand(1, 1, 3, 3).execute(grid, 3, 4);

      expect(grid[0], equals([0, 0, 0, 0]));
      expect(grid[1], equals([0, 3, 3, 3]));
      expect(grid[2], equals([0, 3, 3, 3]));
      expect(grid[3], equals([0, 3, 3, 3]));
    });

    test('draws correctly with inverted coordinates (x1 > x2 and y1 > y2)', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      RectangleFilledCommand(3, 3, 1, 1).execute(grid, 5, 4);

      expect(grid[0], equals([0, 0, 0, 0]));
      expect(grid[1], equals([0, 5, 5, 5]));
      expect(grid[2], equals([0, 5, 5, 5]));
      expect(grid[3], equals([0, 5, 5, 5]));
    });

    test('draws single cell 1x1 rectangle', () {
      final grid = List.generate(3, (_) => List.filled(3, 0));
      RectangleFilledCommand(1, 1, 1, 1).execute(grid, 7, 3);

      expect(grid[0], equals([0, 0, 0]));
      expect(grid[1], equals([0, 7, 0]));
      expect(grid[2], equals([0, 0, 0]));
    });

    test('clips partially out-of-bounds rectangle on all edges', () {
      // Partially clipped: extends past left and top (-1, -1) to (1, 1) on a 3x3 grid
      final gridTopLeft = List.generate(3, (_) => List.filled(3, 0));
      RectangleFilledCommand(-1, -1, 1, 1).execute(gridTopLeft, 2, 3);

      expect(gridTopLeft[0], equals([2, 2, 0]));
      expect(gridTopLeft[1], equals([2, 2, 0]));
      expect(gridTopLeft[2], equals([0, 0, 0]));

      // Partially clipped: extends past right and bottom (1, 1) to (4, 4) on a 3x3 grid
      final gridBottomRight = List.generate(3, (_) => List.filled(3, 0));
      RectangleFilledCommand(1, 1, 4, 4).execute(gridBottomRight, 4, 3);

      expect(gridBottomRight[0], equals([0, 0, 0]));
      expect(gridBottomRight[1], equals([0, 4, 4]));
      expect(gridBottomRight[2], equals([0, 4, 4]));

      // Covering beyond all four boundaries: (-2, -2) to (5, 5)
      final gridFull = List.generate(3, (_) => List.filled(3, 0));
      RectangleFilledCommand(-2, -2, 5, 5).execute(gridFull, 9, 3);

      expect(gridFull[0], equals([9, 9, 9]));
      expect(gridFull[1], equals([9, 9, 9]));
      expect(gridFull[2], equals([9, 9, 9]));
    });

    test('returns early without modifying grid when completely off-screen', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));

      // Completely above
      RectangleFilledCommand(0, -5, 3, -1).execute(grid, 1, 4);
      // Completely below
      RectangleFilledCommand(0, 5, 3, 10).execute(grid, 1, 4);
      // Completely to the left
      RectangleFilledCommand(-10, 0, -1, 3).execute(grid, 1, 4);
      // Completely to the right
      RectangleFilledCommand(5, 0, 8, 3).execute(grid, 1, 4);

      for (final row in grid) {
        expect(row, equals([0, 0, 0, 0]));
      }
    });

    test('returns early without modifying grid when gridSize <= 0', () {
      final emptyGrid = <List<int>>[];
      // Should not throw
      RectangleFilledCommand(0, 0, 2, 2).execute(emptyGrid, 1, 0);
      RectangleFilledCommand(0, 0, 2, 2).execute(emptyGrid, 1, -1);
      expect(emptyGrid.isEmpty, isTrue);
    });

    test('inverted coordinate pairs produce identical solid fill', () {
      final baseGrid = List.generate(4, (_) => List.filled(4, 0));
      final invertedBoth = List.generate(4, (_) => List.filled(4, 0));
      final invertedMixed = List.generate(4, (_) => List.filled(4, 0));

      RectangleFilledCommand(1, 1, 3, 3).execute(baseGrid, 3, 4);
      RectangleFilledCommand(3, 3, 1, 1).execute(invertedBoth, 3, 4);
      RectangleFilledCommand(3, 1, 1, 3).execute(invertedMixed, 3, 4);

      expect(invertedBoth, equals(baseGrid));
      expect(invertedMixed, equals(baseGrid));
    });

    test('draws a single-pixel filled rectangle', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      RectangleFilledCommand(1, 1, 1, 1).execute(grid, 4, 4);

      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          if (x == 1 && y == 1) {
            expect(grid[y][x], equals(4));
          } else {
            expect(grid[y][x], equals(0));
          }
        }
      }
    });

    test(
      'clips partially out-of-bounds filled rectangle safely within grid',
      () {
        final grid = List.generate(4, (_) => List.filled(4, 0));
        RectangleFilledCommand(-1, -1, 1, 1).execute(grid, 5, 4);

        // Fills [0, 1] x [0, 1]
        expect(grid[0], equals([5, 5, 0, 0]));
        expect(grid[1], equals([5, 5, 0, 0]));
        expect(grid[2], equals([0, 0, 0, 0]));
        expect(grid[3], equals([0, 0, 0, 0]));
      },
    );

    test(
      'clips filled rectangle extending beyond upper grid boundary safely',
      () {
        final grid = List.generate(4, (_) => List.filled(4, 0));
        RectangleFilledCommand(2, 2, 5, 5).execute(grid, 5, 4);
        expect(grid[0], equals([0, 0, 0, 0]));
        expect(grid[1], equals([0, 0, 0, 0]));
        expect(grid[2], equals([0, 0, 5, 5]));
        expect(grid[3], equals([0, 0, 5, 5]));
      },
    );

    test(
      'leaves grid unaltered when filled rectangle is completely out of bounds',
      () {
        final grid = List.generate(4, (_) => List.filled(4, 0));
        RectangleFilledCommand(-5, -5, -1, -1).execute(grid, 3, 4);
        RectangleFilledCommand(5, 5, 8, 8).execute(grid, 3, 4);
        final empty = List.generate(4, (_) => List.filled(4, 0));
        expect(grid, equals(empty));
      },
    );
  });
}
