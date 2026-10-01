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
            '.###.\n'
            '#####\n'
            '#####\n'
            '#####\n'
            '.###.',
          ),
        );
      });

      test('ASCII art filled circle radius 3 (7x7)', () {
        final grid = List.generate(7, (_) => List.filled(7, 0));
        CircleFilledCommand(3, 3, 3).execute(grid, 1, 7);
        expect(
          toAsciiArt(grid),
          equals(
            '..###..\n'
            '.#####.\n'
            '#######\n'
            '#######\n'
            '#######\n'
            '.#####.\n'
            '..###..',
          ),
        );
      });

      test('ASCII art filled circle radius 5 (11x11)', () {
        final grid = List.generate(11, (_) => List.filled(11, 0));
        CircleFilledCommand(5, 5, 5).execute(grid, 1, 11);
        expect(
          toAsciiArt(grid),
          equals(
            '...#####...\n'
            '..#######..\n'
            '.#########.\n'
            '###########\n'
            '###########\n'
            '###########\n'
            '###########\n'
            '###########\n'
            '.#########.\n'
            '..#######..\n'
            '...#####...',
          ),
        );
      });

      test(
        'ASCII art filled circle with fractional center on 16x16 is symmetric',
        () {
          final grid = List.generate(16, (_) => List.filled(16, 0));
          CircleFilledCommand(7.5, 7.5, 5.5).execute(grid, 1, 16);

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

    group('Edge cases and boundary clipping', () {
      test('gridSize <= 0 does not throw and executes safely', () {
        final emptyGrid = <List<int>>[];
        expect(
          () => CircleFilledCommand(5, 5, 3).execute(emptyGrid, 1, 0),
          returnsNormally,
        );
        expect(
          () => CircleFilledCommand(5.5, 5.5, 3.5).execute(emptyGrid, 1, -1),
          returnsNormally,
        );
      });

      test('r <= 0 draws single center point if inside bounds', () {
        final grid = List.generate(5, (_) => List.filled(5, 0));
        CircleFilledCommand(2, 2, 0).execute(grid, 7, 5);
        expect(grid[2][2], equals(7));

        // Center outside bounds with r <= 0
        CircleFilledCommand(-1, -1, 0).execute(grid, 7, 5);
        CircleFilledCommand(10, 10, -2).execute(grid, 7, 5);
        expect(grid[0][0], equals(0));
      });

      test('integer circle clipped outside grid boundaries', () {
        final grid = List.generate(8, (_) => List.filled(8, 0));
        // Circle center outside top-left
        expect(
          () => CircleFilledCommand(-2, -2, 4).execute(grid, 1, 8),
          returnsNormally,
        );
        expect(grid[0][0], equals(1));

        // Circle center outside bottom-right
        expect(
          () => CircleFilledCommand(9, 9, 4).execute(grid, 2, 8),
          returnsNormally,
        );
        expect(grid[7][7], equals(2));

        // Circle completely outside grid
        expect(
          () => CircleFilledCommand(-20, -20, 5).execute(grid, 3, 8),
          returnsNormally,
        );
      });

      test('fractional circle clipped outside grid boundaries', () {
        final grid = List.generate(8, (_) => List.filled(8, 0));
        // Circle center outside top-left
        expect(
          () => CircleFilledCommand(-1.5, -1.5, 3.5).execute(grid, 1, 8),
          returnsNormally,
        );
        expect(grid[0][0], equals(1));

        // Circle center outside bottom-right
        expect(
          () => CircleFilledCommand(9.5, 9.5, 3.5).execute(grid, 2, 8),
          returnsNormally,
        );
        expect(grid[7][7], equals(2));

        // Circle completely outside grid
        expect(
          () => CircleFilledCommand(30.5, 30.5, 2.5).execute(grid, 3, 8),
          returnsNormally,
        );
      });
    });

    group('Analytical fractional rasterization parity', () {
      test('matches brute-force point-in-circle check across configurations', () {
        final testCases = [
          (xc: 7.5, yc: 7.5, r: 5.5, size: 16),
          (xc: 5.0, yc: 5.0, r: 4.2, size: 12),
          (xc: 3.2, yc: 4.7, r: 3.8, size: 10),
          (xc: 0.5, yc: 0.5, r: 2.5, size: 8),
          (xc: 7.2, yc: 2.1, r: 4.3, size: 10),
        ];

        for (final tc in testCases) {
          final actualGrid =
              List.generate(tc.size, (_) => List.filled(tc.size, 0));
          CircleFilledCommand(tc.xc, tc.yc, tc.r).execute(actualGrid, 1, tc.size);

          // Expected grid using point-in-circle definition
          final expectedGrid =
              List.generate(tc.size, (_) => List.filled(tc.size, 0));
          final rSq = (tc.r * tc.r).toDouble();
          for (int y = 0; y < tc.size; y++) {
            final dy = y - tc.yc.toDouble();
            for (int x = 0; x < tc.size; x++) {
              final dx = x - tc.xc.toDouble();
              if (dx * dx + dy * dy <= rSq) {
                expectedGrid[y][x] = 1;
              }
            }
          }

          for (int y = 0; y < tc.size; y++) {
            for (int x = 0; x < tc.size; x++) {
              expect(
                actualGrid[y][x],
                equals(expectedGrid[y][x]),
                reason:
                    'Mismatch for circle (${tc.xc}, ${tc.yc}, r=${tc.r}) at ($x, $y)',
              );
            }
          }
        }
      });
    });
  });
}
