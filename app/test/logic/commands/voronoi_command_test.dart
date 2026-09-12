import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/voronoi_command.dart';

void main() {
  group('VoronoiCommand Tests', () {
    test('renders cell pattern', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      VoronoiCommand(0, 0, 7, 7, 4, 123).execute(grid, 3, 8);

      bool hasColor = false;
      bool hasBackground = false;
      for (final row in grid) {
        for (final val in row) {
          if (val == 3) hasColor = true;
          if (val == 0) hasBackground = true;
        }
      }
      expect(hasColor, isTrue);
      expect(hasBackground, isTrue);
    });

    test(
      'does not modify grid when rectangle is completely out of bounds (negative)',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        VoronoiCommand(-10, -10, -5, -5, 4, 100).execute(grid, 2, 16);

        for (final row in grid) {
          for (final val in row) {
            expect(val, equals(0));
          }
        }
      },
    );

    test(
      'does not modify grid when rectangle is completely out of bounds (positive)',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        VoronoiCommand(20, 20, 25, 25, 4, 100).execute(grid, 2, 16);

        for (final row in grid) {
          for (final val in row) {
            expect(val, equals(0));
          }
        }
      },
    );

    test('does not modify grid when numCells is 0 or negative', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      VoronoiCommand(0, 0, 7, 7, 0, 100).execute(grid, 2, 8);

      for (final row in grid) {
        for (final val in row) {
          expect(val, equals(0));
        }
      }

      VoronoiCommand(0, 0, 7, 7, -3, 100).execute(grid, 2, 8);
      for (final row in grid) {
        for (final val in row) {
          expect(val, equals(0));
        }
      }
    });

    test('partially out of bounds only draws within grid bounds', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      VoronoiCommand(-2, -2, 1, 1, 4, 42).execute(grid, 3, 4);

      // Pixels strictly outside (x > 1 or y > 1) must remain 0
      for (int y = 2; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          expect(grid[y][x], equals(0));
        }
      }
      for (int y = 0; y < 4; y++) {
        for (int x = 2; x < 4; x++) {
          expect(grid[y][x], equals(0));
        }
      }
    });

    test('handles non-positive gridSize safely', () {
      final grid = <List<int>>[];
      expect(
        () => VoronoiCommand(0, 0, 2, 2, 4, 42).execute(grid, 1, 0),
        returnsNormally,
      );
      expect(
        () => VoronoiCommand(0, 0, 2, 2, 4, 42).execute(grid, 1, -5),
        returnsNormally,
      );
    });

    test('deterministic cell rendering and correct color assignment', () {
      final grid1 = List.generate(16, (_) => List.filled(16, -1));
      final grid2 = List.generate(16, (_) => List.filled(16, -1));

      VoronoiCommand(0, 0, 15, 15, 6, 789).execute(grid1, 5, 16);
      VoronoiCommand(0, 0, 15, 15, 6, 789).execute(grid2, 5, 16);

      // Verify identical results across identical runs
      for (int y = 0; y < 16; y++) {
        for (int x = 0; x < 16; x++) {
          expect(grid1[y][x], equals(grid2[y][x]));
          // Each pixel should either be assigned the active color (5) or background (0)
          expect(grid1[y][x] == 5 || grid1[y][x] == 0, isTrue);
        }
      }

      // Verify both even and odd cell colors were assigned across the grid
      final allValues = grid1.expand((row) => row).toSet();
      expect(allValues, containsAll([0, 5]));
    });
  });
}
