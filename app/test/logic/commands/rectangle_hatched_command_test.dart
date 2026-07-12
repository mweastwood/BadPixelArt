import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/rectangle_hatched_command.dart';

void main() {
  group('RectangleHatchedCommand Tests', () {
    test('draws checkerboard hatched rectangle', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      RectangleHatchedCommand(1, 1, 3, 3).execute(grid, 4, 4);

      expect(grid[1].sublist(1, 4), equals([4, 0, 4]));
      expect(grid[2].sublist(1, 4), equals([0, 4, 0]));
      expect(grid[3].sublist(1, 4), equals([4, 0, 4]));
    });
  });
}
