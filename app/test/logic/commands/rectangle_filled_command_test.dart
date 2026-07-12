import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/rectangle_filled_command.dart';

void main() {
  group('RectangleFilledCommand Tests', () {
    test('draws solid rectangle', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      RectangleFilledCommand(1, 1, 3, 3).execute(grid, 3, 4);

      expect(grid[1].sublist(1, 4), equals([3, 3, 3]));
      expect(grid[2].sublist(1, 4), equals([3, 3, 3]));
      expect(grid[3].sublist(1, 4), equals([3, 3, 3]));
    });
  });
}
