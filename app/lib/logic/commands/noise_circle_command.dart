import 'base_command.dart';

/// Command to fill a circular area with noise-distributed pixels.
class NoiseCircleCommand implements DrawingCommand {
  static const String usage =
      'params [centerX, centerY, radius, seed] (draws a noise dithering pattern of the active color in a circle)';

  final int cx;
  final int cy;
  final int r;
  final int seed;

  NoiseCircleCommand(this.cx, this.cy, this.r, this.seed);

  static double _hashNoise(int x, int y, int seed) {
    int n = x * 374761393 + y * 668265263 + seed * 1274126177;
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff;
    n = n ^ (n >> 16);
    return (n & 0x7fffffff) / 0x7fffffff;
  }

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    for (
      int y = (cy - r).clamp(0, gridSize - 1);
      y <= (cy + r).clamp(0, gridSize - 1);
      y++
    ) {
      for (
        int x = (cx - r).clamp(0, gridSize - 1);
        x <= (cx + r).clamp(0, gridSize - 1);
        x++
      ) {
        if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r) {
          final double n = _hashNoise(x, y, seed);
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
