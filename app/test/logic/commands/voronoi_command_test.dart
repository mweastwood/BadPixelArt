import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/commands/voronoi_command.dart';

void main() {
  group('VoronoiCommand Tests', () {
    test('renders cell pattern', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      VoronoiCommand(0, 0, 7, 7, 4, 123).execute(grid, 3, 8);

      bool hasColor = false;
      bool hasBackground = false;
      for (final row in grid) {
        for (final val in row) {
          if (val == 3) hasColor = true;
          if (val == 0) hasBackground = true;
        }
      }
      expect(hasColor, isTrue);
      expect(hasBackground, isTrue);
    });
  });
}
