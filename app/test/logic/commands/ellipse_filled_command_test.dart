import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/ellipse_filled_command.dart';

void main() {
  group('EllipseFilledCommand Tests', () {
    test('fills ellipse', () {
      final grid = List.generate(7, (_) => List.filled(7, 0));
      EllipseFilledCommand(3, 3, 3, 2).execute(grid, 5, 7);

      expect(grid[3][3], equals(5));
      expect(grid[3][0], equals(5));
      expect(grid[3][6], equals(5));
    });
  });
}
