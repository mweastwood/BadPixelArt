import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/rotated_rectangle_command.dart';

void main() {
  group('RotatedRectangleCommand Tests', () {
    test('draws rotated rectangle', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      // Draw 6x2 rectangle rotated by 90 degrees (becomes 2x6 vertically)
      RotatedRectangleCommand(4, 4, 6, 2, 90.0).execute(grid, 2, 8);

      // Verify it is aligned vertically now
      expect(grid[4][4], equals(2));
      expect(grid[2][4], equals(2));
      expect(grid[6][4], equals(2));
      expect(grid[4][2], equals(0)); // wider horizontally should be empty
    });
  });
}
