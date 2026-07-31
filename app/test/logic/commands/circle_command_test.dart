import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/circle_command.dart';

void main() {
  group('CircleCommand Tests', () {
    test(
      'draws outline circle of radius 2 with single-pixel compass points',
      () {
        final grid = List.generate(5, (_) => List.filled(5, 0));
        CircleCommand(2, 2, 2).execute(grid, 3, 5);

        // Verify 4 compass points are drawn
        expect(grid[0][2], equals(3)); // Top compass point
        expect(grid[4][2], equals(3)); // Bottom compass point
        expect(grid[2][0], equals(3)); // Left compass point
        expect(grid[2][4], equals(3)); // Right compass point

        // Verify NO extra pixels exist on the top row (0) or bottom row (4)
        expect(
          grid[0][1],
          equals(0),
          reason: 'Top row must not have extra compass pixels',
        );
        expect(
          grid[0][3],
          equals(0),
          reason: 'Top row must not have extra compass pixels',
        );
        expect(
          grid[4][1],
          equals(0),
          reason: 'Bottom row must not have extra compass pixels',
        );
        expect(
          grid[4][3],
          equals(0),
          reason: 'Bottom row must not have extra compass pixels',
        );

        // Verify NO extra pixels exist on the left col (0) or right col (4)
        expect(
          grid[1][0],
          equals(0),
          reason: 'Left col must not have extra compass pixels',
        );
        expect(
          grid[3][0],
          equals(0),
          reason: 'Left col must not have extra compass pixels',
        );
        expect(
          grid[1][4],
          equals(0),
          reason: 'Right col must not have extra compass pixels',
        );
        expect(
          grid[3][4],
          equals(0),
          reason: 'Right col must not have extra compass pixels',
        );

        // Center should remain unfilled
        expect(grid[2][2], equals(0));
      },
    );

    test(
      'draws outline circle of radius 5 with single-pixel compass points',
      () {
        final grid = List.generate(21, (_) => List.filled(21, 0));
        CircleCommand(10, 10, 5).execute(grid, 1, 21);

        // Top row (y=5): ONLY (10, 5) should be drawn
        expect(grid[5][10], equals(1));
        expect(
          grid[5][9],
          equals(0),
          reason: 'Extra pixel at top compass point',
        );
        expect(
          grid[5][11],
          equals(0),
          reason: 'Extra pixel at top compass point',
        );

        // Bottom row (y=15): ONLY (10, 15) should be drawn
        expect(grid[15][10], equals(1));
        expect(
          grid[15][9],
          equals(0),
          reason: 'Extra pixel at bottom compass point',
        );
        expect(
          grid[15][11],
          equals(0),
          reason: 'Extra pixel at bottom compass point',
        );

        // Left col (x=5): ONLY (5, 10) should be drawn
        expect(grid[10][5], equals(1));
        expect(
          grid[9][5],
          equals(0),
          reason: 'Extra pixel at left compass point',
        );
        expect(
          grid[11][5],
          equals(0),
          reason: 'Extra pixel at left compass point',
        );

        // Right col (x=15): ONLY (15, 10) should be drawn
        expect(grid[10][15], equals(1));
        expect(
          grid[9][15],
          equals(0),
          reason: 'Extra pixel at right compass point',
        );
        expect(
          grid[11][15],
          equals(0),
          reason: 'Extra pixel at right compass point',
        );
      },
    );

    test('draws single point for radius 0', () {
      final grid = List.generate(5, (_) => List.filled(5, 0));
      CircleCommand(2, 2, 0).execute(grid, 3, 5);

      expect(grid[2][2], equals(3));
      expect(grid[2][1], equals(0));
      expect(grid[2][3], equals(0));
    });
  });
}
