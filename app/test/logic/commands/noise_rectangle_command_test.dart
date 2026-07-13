import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/noise_rectangle_command.dart';

void main() {
  group('NoiseRectangleCommand Tests', () {
    test('noise fills rectangle area', () {
      final grid = List.generate(4, (_) => List.filled(4, 0));
      NoiseRectangleCommand(0, 0, 3, 3, 42).execute(grid, 5, 4);

      // Verify that some pixels are filled with 5, and some remain transparent (0)
      bool hasColor = false;
      bool hasBackground = false;
      for (final row in grid) {
        for (final val in row) {
          if (val == 5) hasColor = true;
          if (val == 0) hasBackground = true;
        }
      }
      expect(hasColor, isTrue);
      expect(hasBackground, isTrue);
    });
  });
}
