import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/noise_circle_command.dart';

void main() {
  group('NoiseCircleCommand Tests', () {
    test('noise fills circle area', () {
      final grid = List.generate(6, (_) => List.filled(6, 0));
      NoiseCircleCommand(2, 2, 2, 99).execute(grid, 4, 6);

      bool hasColor = false;
      bool hasBackground = false;
      for (int y = 0; y < 6; y++) {
        for (int x = 0; x < 6; x++) {
          if ((x - 2) * (x - 2) + (y - 2) * (y - 2) <= 4) {
            if (grid[y][x] == 4) hasColor = true;
            if (grid[y][x] == 0) hasBackground = true;
          }
        }
      }
      expect(hasColor, isTrue);
      expect(hasBackground, isTrue);
    });
  });
}
