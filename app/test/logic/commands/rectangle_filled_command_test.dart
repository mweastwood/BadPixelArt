import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/rectangle_filled_command.dart';

void main() {
  group('RectangleFilledCommand Tests', () {
    test('draws solid rectangle', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      RectangleFilledCommand(1, 1, 3, 3).execute(grid, 3, 4);

      expect(grid[1].sublist(1, 4), equals([3, 3, 3]));
      expect(grid[2].sublist(1, 4), equals([3, 3, 3]));
      expect(grid[3].sublist(1, 4), equals([3, 3, 3]));
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
