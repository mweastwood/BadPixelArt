import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/circle_hatched_command.dart';

void main() {
  group('CircleHatchedCommand Tests', () {
    test('fills circle checkerboard pattern', () {
      final grid = List.generate(5, (_) => List.filled(5, 0));
      CircleHatchedCommand(2, 2, 2).execute(grid, 7, 5);

      // (2,2) -> (2+2)%2 == 0 -> filled
      expect(grid[2][2], equals(7));
      // (1,2) -> (1+2)%2 == 3 -> not filled
      expect(grid[2][1], equals(0));
    });
  });
}
