import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/rectangle_hatched_command.dart';

void main() {
  group('RectangleHatchedCommand Tests', () {
    test('draws checkerboard hatched rectangle', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      RectangleHatchedCommand(1, 1, 3, 3).execute(grid, 4, 4);

      expect(grid[1].sublist(1, 4), equals([4, 0, 4]));
      expect(grid[2].sublist(1, 4), equals([0, 4, 0]));
      expect(grid[3].sublist(1, 4), equals([4, 0, 4]));
    });

    test('inverted coordinate pairs produce identical hatched fill', () {
      final baseGrid = List.generate(4, (_) => List.filled(4, 0));
      final invertedBoth = List.generate(4, (_) => List.filled(4, 0));
      final invertedMixed = List.generate(4, (_) => List.filled(4, 0));

      RectangleHatchedCommand(1, 1, 3, 3).execute(baseGrid, 4, 4);
      RectangleHatchedCommand(3, 3, 1, 1).execute(invertedBoth, 4, 4);
      RectangleHatchedCommand(3, 1, 1, 3).execute(invertedMixed, 4, 4);

      expect(invertedBoth, equals(baseGrid));
      expect(invertedMixed, equals(baseGrid));
    });

    test('single-pixel hatched rectangle respects even/odd parity', () {
      final gridEven = List.generate(4, (_) => List.filled(4, 0));
      // (2, 2): 2 + 2 = 4 (even) -> colored
      RectangleHatchedCommand(2, 2, 2, 2).execute(gridEven, 6, 4);
      expect(gridEven[2][2], equals(6));

      final gridOdd = List.generate(4, (_) => List.filled(4, 0));
      // (2, 1): 2 + 1 = 3 (odd) -> uncolored (0)
      RectangleHatchedCommand(2, 1, 2, 1).execute(gridOdd, 6, 4);
      expect(gridOdd[1][2], equals(0));
      final empty = List.generate(4, (_) => List.filled(4, 0));
      expect(gridOdd, equals(empty));
    });

    test(
      'clips partially out-of-bounds hatched rectangle safely within grid',
      () {
        final grid = List.generate(4, (_) => List.filled(4, 0));
        RectangleHatchedCommand(-1, -1, 2, 2).execute(grid, 8, 4);

        // Subgrid [0, 2] x [0, 2] where (x + y) % 2 == 0
        // y=0: x=0 (even -> 8), x=1 (odd -> 0), x=2 (even -> 8)
        // y=1: x=0 (odd -> 0), x=1 (even -> 8), x=2 (odd -> 0)
        // y=2: x=0 (even -> 8), x=1 (odd -> 0), x=2 (even -> 8)
        expect(grid[0], equals([8, 0, 8, 0]));
        expect(grid[1], equals([0, 8, 0, 0]));
        expect(grid[2], equals([8, 0, 8, 0]));
        expect(grid[3], equals([0, 0, 0, 0]));
      },
    );

    test(
      'leaves grid unaltered when hatched rectangle is completely out of bounds',
      () {
        final grid = List.generate(4, (_) => List.filled(4, 0));
        RectangleHatchedCommand(-5, -5, -1, -1).execute(grid, 4, 4);
        RectangleHatchedCommand(5, 5, 8, 8).execute(grid, 4, 4);
        final empty = List.generate(4, (_) => List.filled(4, 0));
        expect(grid, equals(empty));
      },
    );
  });
}
