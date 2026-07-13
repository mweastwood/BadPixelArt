import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/pixel_command.dart';

void main() {
  group('PixelCommand Tests', () {
    test('draws a single pixel', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      PixelCommand(1, 2).execute(grid, 5, 4);
      expect(grid[2][1], equals(5));
      expect(grid[2][0], equals(0));
    });
  });
}
