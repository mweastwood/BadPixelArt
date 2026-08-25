import '../utils/noise_utils.dart';
import 'base_command.dart';

/// Command to fill a circular area with noise-distributed pixels.
class NoiseCircleCommand implements DrawingCommand {
  static const String usage =
      'params [centerX, centerY, radius, seed] (draws a noise dithering pattern of the active color in a circle)';

  final num cx;
  final num cy;
  final num r;
  final int seed;

  NoiseCircleCommand(this.cx, this.cy, this.r, this.seed);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    final double rSq = (r * r).toDouble();
    final int minX = (cx - r).floor().clamp(0, gridSize - 1);
    final int maxX = (cx + r).ceil().clamp(0, gridSize - 1);
    final int minY = (cy - r).floor().clamp(0, gridSize - 1);
    final int maxY = (cy + r).ceil().clamp(0, gridSize - 1);

    for (int y = minY; y <= maxY; y++) {
      final double dy = y - cy.toDouble();
      for (int x = minX; x <= maxX; x++) {
        final double dx = x - cx.toDouble();
        if (dx * dx + dy * dy <= rSq) {
          final double n = hashNoise(x, y, seed);
          final int idx = (n * 2).floor() % 2;
          if (idx == 0) {
            grid[y][x] = color;
          } else {
            grid[y][x] = 0;
          }
        }
      }
    }
  }
}
