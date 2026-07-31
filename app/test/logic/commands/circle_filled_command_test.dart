import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/circle_filled_command.dart';

void main() {
  group('CircleFilledCommand Tests', () {
    test('fills circle completely', () {
      final grid = List.generate(5, (_) => List.filled(5, 0));
      CircleFilledCommand(2, 2, 2).execute(grid, 4, 5);

      // Center should be filled
      expect(grid[2][2], equals(4));
      expect(grid[2][0], equals(4));
      expect(grid[2][4], equals(4));
    });

    group('ASCII Art Visual Rendering Tests (Filled)', () {
      String toAsciiArt(List<List<int>> grid) {
        return grid
            .map((row) => row.map((cell) => cell > 0 ? '#' : '.').join())
            .join('\n');
      }

      test('ASCII art filled circle radius 1 (3x3)', () {
        final grid = List.generate(3, (_) => List.filled(3, 0));
        CircleFilledCommand(1, 1, 1).execute(grid, 1, 3);
        expect(
          toAsciiArt(grid),
          equals(
            '.#.\n'
            '###\n'
            '.#.',
          ),
        );
      });

      test('ASCII art filled circle radius 2 (5x5)', () {
        final grid = List.generate(5, (_) => List.filled(5, 0));
        CircleFilledCommand(2, 2, 2).execute(grid, 1, 5);
        expect(
          toAsciiArt(grid),
          equals(
            '..#..\n'
            '.###.\n'
            '#####\n'
            '.###.\n'
            '..#..',
          ),
        );
      });

      test('ASCII art filled circle radius 3 (7x7)', () {
        final grid = List.generate(7, (_) => List.filled(7, 0));
        CircleFilledCommand(3, 3, 3).execute(grid, 1, 7);
        expect(
          toAsciiArt(grid),
          equals(
            '...#...\n'
            '.#####.\n'
            '.#####.\n'
            '#######\n'
            '.#####.\n'
            '.#####.\n'
            '...#...',
          ),
        );
      });

      test('ASCII art filled circle radius 5 (11x11)', () {
        final grid = List.generate(11, (_) => List.filled(11, 0));
        CircleFilledCommand(5, 5, 5).execute(grid, 1, 11);
        expect(
          toAsciiArt(grid),
          equals(
            '.....#.....\n'
            '..#######..\n'
            '.#########.\n'
            '.#########.\n'
            '.#########.\n'
            '###########\n'
            '.#########.\n'
            '.#########.\n'
            '.#########.\n'
            '..#######..\n'
            '.....#.....',
          ),
        );
      });
    });
  });
}
