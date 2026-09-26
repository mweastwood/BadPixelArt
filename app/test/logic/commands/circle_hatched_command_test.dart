import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/circle_hatched_command.dart';

void main() {
  group('CircleHatchedCommand Tests', () {
    test('fills circle checkerboard pattern', () {
      final grid = List.generate(5, (_) => List.filled(5, 0));
      CircleHatchedCommand(2, 2, 2).execute(grid, 7, 5);

      // (2,2) -> (2+2)%2 == 0 -> filled
      expect(grid[2][2], equals(7));
      // (1,2) -> (1+2)%2 == 3 -> not filled
      expect(grid[2][1], equals(0));
    });

    test('handles non-positive gridSize safely', () {
      final grid = <List<int>>[];
      expect(
        () => CircleHatchedCommand(2, 2, 2).execute(grid, 7, 0),
        returnsNormally,
      );
      expect(
        () => CircleHatchedCommand(2, 2, 2).execute(grid, 7, -1),
        returnsNormally,
      );
    });

    test(
      'non-positive radius with r = 0 draws single pixel when parity is even',
      () {
        final grid = List.generate(5, (_) => List.filled(5, 0));
        // (2, 2): 2 + 2 = 4 (even) -> pixel drawn
        CircleHatchedCommand(2, 2, 0).execute(grid, 7, 5);
        expect(grid[2][2], equals(7));

        // Check all other pixels remain 0
        grid[2][2] = 0;
        final empty = List.generate(5, (_) => List.filled(5, 0));
        expect(grid, equals(empty));
      },
    );

    test(
      'non-positive radius with r = 0 leaves pixel uncolored when parity is odd',
      () {
        final grid = List.generate(5, (_) => List.filled(5, 0));
        // (2, 1): 2 + 1 = 3 (odd) -> no pixel drawn
        CircleHatchedCommand(2, 1, 0).execute(grid, 7, 5);
        final empty = List.generate(5, (_) => List.filled(5, 0));
        expect(grid, equals(empty));
      },
    );

    test(
      'non-positive radius with negative r behaves identically to r = 0',
      () {
        final gridEven = List.generate(5, (_) => List.filled(5, 0));
        CircleHatchedCommand(2, 2, -1).execute(gridEven, 7, 5);
        expect(gridEven[2][2], equals(7));

        final gridOdd = List.generate(5, (_) => List.filled(5, 0));
        CircleHatchedCommand(2, 1, -1).execute(gridOdd, 7, 5);
        final empty = List.generate(5, (_) => List.filled(5, 0));
        expect(gridOdd, equals(empty));
      },
    );

    test(
      'non-positive radius with out-of-bounds center leaves grid unaltered',
      () {
        final grid = List.generate(5, (_) => List.filled(5, 0));
        CircleHatchedCommand(-1, -1, 0).execute(grid, 7, 5);
        CircleHatchedCommand(5, 5, 0).execute(grid, 7, 5);
        CircleHatchedCommand(-2, 3, -1).execute(grid, 7, 5);
        CircleHatchedCommand(3, 7, -2).execute(grid, 7, 5);
        final empty = List.generate(5, (_) => List.filled(5, 0));
        expect(grid, equals(empty));
      },
    );
  });
}
