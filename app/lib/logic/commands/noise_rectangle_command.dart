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

  static double _hashNoise(int x, int y, int seed) {
    int n = x * 374761393 + y * 668265263 + seed * 1274126177;
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff;
    n = n ^ (n >> 16);
    return (n & 0x7fffffff) / 0x7fffffff;
  }

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    final int startX = x1 < x2 ? x1 : x2;
    final int endX = x1 < x2 ? x2 : x1;
    final int startY = y1 < y2 ? y1 : y2;
    final int endY = y1 < y2 ? y2 : y1;

    for (
      int y = startY.clamp(0, gridSize - 1);
      y <= endY.clamp(0, gridSize - 1);
      y++
    ) {
      for (
        int x = startX.clamp(0, gridSize - 1);
        x <= endX.clamp(0, gridSize - 1);
        x++
      ) {
        final double n = _hashNoise(x, y, seed);
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
