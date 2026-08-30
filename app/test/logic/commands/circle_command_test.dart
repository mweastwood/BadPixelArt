import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/circle_command.dart';

void main() {
  group('CircleCommand Tests', () {
    test('draws single point for radius 0', () {
      final grid = List.generate(5, (_) => List.filled(5, 0));
      CircleCommand(2, 2, 0).execute(grid, 3, 5);

      expect(grid[2][2], equals(3));
      expect(grid[2][1], equals(0));
      expect(grid[2][3], equals(0));
    });

    group('ASCII Art Visual Rendering Tests', () {
      String toAsciiArt(List<List<int>> grid) {
        return grid
            .map((row) => row.map((cell) => cell > 0 ? '#' : '.').join())
            .join('\n');
      }

      test('ASCII art circle radius 1 (3x3)', () {
        final grid = List.generate(3, (_) => List.filled(3, 0));
        CircleCommand(1, 1, 1).execute(grid, 1, 3);
        expect(
          toAsciiArt(grid),
          equals(
            '.#.\n'
            '#.#\n'
            '.#.',
          ),
        );
      });

      test('ASCII art circle radius 2 (5x5)', () {
        final grid = List.generate(5, (_) => List.filled(5, 0));
        CircleCommand(2, 2, 2).execute(grid, 1, 5);
        expect(
          toAsciiArt(grid),
          equals(
            '.###.\n'
            '#...#\n'
            '#...#\n'
            '#...#\n'
            '.###.',
          ),
        );
      });

      test('ASCII art circle radius 3 (7x7)', () {
        final grid = List.generate(7, (_) => List.filled(7, 0));
        CircleCommand(3, 3, 3).execute(grid, 1, 7);
        expect(
          toAsciiArt(grid),
          equals(
            '..###..\n'
            '.#...#.\n'
            '#.....#\n'
            '#.....#\n'
            '#.....#\n'
            '.#...#.\n'
            '..###..',
          ),
        );
      });

      test('ASCII art circle radius 5 (11x11)', () {
        final grid = List.generate(11, (_) => List.filled(11, 0));
        CircleCommand(5, 5, 5).execute(grid, 1, 11);
        expect(
          toAsciiArt(grid),
          equals(
            '...#####...\n'
            '..#.....#..\n'
            '.#.......#.\n'
            '#.........#\n'
            '#.........#\n'
            '#.........#\n'
            '#.........#\n'
            '#.........#\n'
            '.#.......#.\n'
            '..#.....#..\n'
            '...#####...',
          ),
        );
      });

      test(
        'ASCII art circle outline with fractional center on 16x16 is symmetric',
        () {
          final grid = List.generate(16, (_) => List.filled(16, 0));
          CircleCommand(7.5, 7.5, 5.5).execute(grid, 1, 16);

          for (int y = 0; y < 16; y++) {
            for (int x = 0; x < 8; x++) {
              expect(
                grid[y][x],
                equals(grid[y][15 - x]),
                reason: 'Mismatch at Y=$y: X=$x vs X=${15 - x}',
              );
            }
          }
        },
      );
    });

    test('handles non-positive gridSize safely', () {
      final grid = <List<int>>[];
      // Integer radius
      expect(() => CircleCommand(2, 2, 2).execute(grid, 1, 0), returnsNormally);
      expect(
        () => CircleCommand(2, 2, 2).execute(grid, 1, -1),
        returnsNormally,
      );
      // Fractional center/radius
      expect(
        () => CircleCommand(2.5, 2.5, 2.5).execute(grid, 1, 0),
        returnsNormally,
      );
      expect(
        () => CircleCommand(2.5, 2.5, 2.5).execute(grid, 1, -1),
        returnsNormally,
      );
    });
  });
}
