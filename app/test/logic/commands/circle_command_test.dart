import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/circle_command.dart';

void main() {
  group('CircleCommand Tests', () {
    test('draws outline circle', () {
      final grid = List.generate(5, (_) => List.filled(5, 0));
      CircleCommand(2, 2, 2).execute(grid, 3, 5);

      // Verify outline points (e.g. center x +/- r, y +/- r)
      expect(grid[2][0], equals(3));
      expect(grid[2][4], equals(3));
      expect(grid[0][2], equals(3));
      expect(grid[4][2], equals(3));
      // Center should remain unfilled
      expect(grid[2][2], equals(0));
    });
  });
}
