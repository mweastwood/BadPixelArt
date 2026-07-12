import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/rectangle_command.dart';

void main() {
  group('RectangleCommand Tests', () {
    test('draws outline rectangle', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      RectangleCommand(1, 1, 3, 3).execute(grid, 2, 4);

      expect(grid[1].sublist(1, 4), equals([2, 2, 2]));
      expect(grid[2].sublist(1, 4), equals([2, 0, 2]));
      expect(grid[3].sublist(1, 4), equals([2, 2, 2]));
    });
  });
}
