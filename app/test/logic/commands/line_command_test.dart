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
  });
}
