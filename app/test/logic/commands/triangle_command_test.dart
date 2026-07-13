import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/triangle_command.dart';

void main() {
  group('TriangleCommand Tests', () {
    test('draws solid triangle', () {
      final grid = List.generate(6, (_) => List.filled(6, 0));
      TriangleCommand(0, 0, 4, 0, 0, 4).execute(grid, 3, 6);

      // Verify some points inside the triangle bounds
      expect(grid[0][0], equals(3));
      expect(grid[1][1], equals(3));
      expect(grid[2][2], equals(3));
      expect(grid[4][0], equals(3));
      // Point outside bounds
      expect(grid[5][5], equals(0));
    });
  });
}
