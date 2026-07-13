import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/pixels_command.dart';

void main() {
  group('PixelsCommand Tests', () {
    test('draws batch pixels', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      PixelsCommand([0, 0, 2, 2, 3, 1]).execute(grid, 7, 4);

      expect(grid[0][0], equals(7));
      expect(grid[2][2], equals(7));
      expect(grid[1][3], equals(7));
      expect(grid[0][1], equals(0));
    });
  });
}
