import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/circle_filled_command.dart';

void main() {
  group('CircleFilledCommand Tests', () {
    test('fills circle completely', () {
      final grid = List.generate(5, (_) => List.filled(5, 0));
      CircleFilledCommand(2, 2, 2).execute(grid, 4, 5);

      // Center should be filled
      expect(grid[2][2], equals(4));
      expect(grid[2][0], equals(4));
      expect(grid[2][4], equals(4));
    });
  });
}
