import '../utils/noise_utils.dart';
import 'base_command.dart';

/// Command to fill a rectangular area with noise-distributed pixels.
class NoiseRectangleCommand implements DrawingCommand {
  static const String usage =
      'params [x1, y1, x2, y2, seed] (draws a noise dithering pattern of the active color)';

  final int x1;
  final int y1;
  final int x2;
  final int y2;
  final int seed;

  NoiseRectangleCommand(this.x1, this.y1, this.x2, this.y2, this.seed);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

    final int startX = x1 < x2 ? x1 : x2;
    final int endX = x1 < x2 ? x2 : x1;
    final int startY = y1 < y2 ? y1 : y2;
    final int endY = y1 < y2 ? y2 : y1;

    if (endX < 0 || startX >= gridSize || endY < 0 || startY >= gridSize) {
      return;
    }

    final int clampedStartY = startY.clamp(0, gridSize - 1);
    final int clampedEndY = endY.clamp(0, gridSize - 1);
    final int clampedStartX = startX.clamp(0, gridSize - 1);
    final int clampedEndX = endX.clamp(0, gridSize - 1);

    for (int y = clampedStartY; y <= clampedEndY; y++) {
      for (int x = clampedStartX; x <= clampedEndX; x++) {
        final double n = hashNoise(x, y, seed);
        final int idx = (n * 2).floor() % 2;
        if (idx == 0) {
          grid[y][x] = color;
        } else {
          grid[y][x] = 0; // Transparent/Eraser
        }
      }
    }
  }
}
