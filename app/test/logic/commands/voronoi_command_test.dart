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
  });
}
