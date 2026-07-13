import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/ellipse_command.dart';

void main() {
  group('EllipseCommand Tests', () {
    test('draws outline ellipse', () {
      final grid = List.generate(7, (_) => List.filled(7, 0));
      EllipseCommand(3, 3, 3, 2).execute(grid, 6, 7);

      // Outline boundaries should be drawn
      expect(grid[3][0], equals(6));
      expect(grid[3][6], equals(6));
      expect(grid[1][3], equals(6));
      expect(grid[5][3], equals(6));
      // Center remains empty
      expect(grid[3][3], equals(0));
    });
  });
}
