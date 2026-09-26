import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/line_command.dart';

void main() {
  group('LineCommand Tests', () {
    test('draws a horizontal line', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      LineCommand(0, 0, 3, 0).execute(grid, 5, 4);
      expect(grid[0], equals([5, 5, 5, 5]));
      expect(grid[1], equals([0, 0, 0, 0]));
    });

    test('draws a vertical line', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      LineCommand(1, 0, 1, 3).execute(grid, 6, 4);
      expect(grid[0][1], equals(6));
      expect(grid[1][1], equals(6));
      expect(grid[2][1], equals(6));
      expect(grid[3][1], equals(6));
    });

    test('draws a 45-degree diagonal line', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      LineCommand(0, 0, 3, 3).execute(grid, 7, 4);
      for (int i = 0; i < 4; i++) {
        expect(grid[i][i], equals(7));
      }
      expect(grid[0][1], equals(0));
      expect(grid[1][0], equals(0));
    });

    test('draws a steep diagonal line where dy > dx', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      LineCommand(0, 0, 1, 3).execute(grid, 8, 4);
      expect(grid[0][0], equals(8));
      expect(grid[1][0], equals(8));
      expect(grid[2][1], equals(8));
      expect(grid[3][1], equals(8));
    });

    test('direction reversibility produces identical rasterization', () {
      final forwardHorizontal = List.generate(4, (_) => List.filled(4, 0));
      final reverseHorizontal = List.generate(4, (_) => List.filled(4, 0));
      LineCommand(0, 0, 3, 0).execute(forwardHorizontal, 5, 4);
      LineCommand(3, 0, 0, 0).execute(reverseHorizontal, 5, 4);
      expect(reverseHorizontal, equals(forwardHorizontal));

      final forwardDiagonal = List.generate(4, (_) => List.filled(4, 0));
      final reverseDiagonal = List.generate(4, (_) => List.filled(4, 0));
      LineCommand(0, 0, 3, 3).execute(forwardDiagonal, 5, 4);
      LineCommand(3, 3, 0, 0).execute(reverseDiagonal, 5, 4);
      expect(reverseDiagonal, equals(forwardDiagonal));
    });

    test('draws a single-point line', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      LineCommand(1, 1, 1, 1).execute(grid, 9, 4);
      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          if (x == 1 && y == 1) {
            expect(grid[y][x], equals(9));
          } else {
            expect(grid[y][x], equals(0));
          }
        }
      }
    });

    test('clips line starting off-grid', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      LineCommand(-2, 0, 2, 0).execute(grid, 5, 4);
      expect(grid[0], equals([5, 5, 5, 0]));
      expect(grid[1], equals([0, 0, 0, 0]));
    });

    test('clips line ending off-grid', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      LineCommand(2, 2, 5, 2).execute(grid, 5, 4);
      expect(grid[2], equals([0, 0, 5, 5]));
      expect(grid[0], equals([0, 0, 0, 0]));
      expect(grid[1], equals([0, 0, 0, 0]));
      expect(grid[3], equals([0, 0, 0, 0]));
    });

    test('leaves grid unaltered when line is completely off-grid', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      LineCommand(-5, -5, -1, -1).execute(grid, 5, 4);
      LineCommand(5, 5, 8, 8).execute(grid, 5, 4);
      final empty = List.generate(4, (_) => List.filled(4, 0));
      expect(grid, equals(empty));
    });
  });
}
