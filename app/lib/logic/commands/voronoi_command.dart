import 'base_command.dart';

/// Command to draw a Voronoi cellular texture.
class VoronoiCommand implements DrawingCommand {
  static const String usage =
      'params [x1, y1, x2, y2, num_cells, seed] (draws a Voronoi cellular texture of the active color)';

  final int x1;
  final int y1;
  final int x2;
  final int y2;
  final int numCells;
  final int seed;

  VoronoiCommand(this.x1, this.y1, this.x2, this.y2, this.numCells, this.seed);

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

    final int w = endX - startX + 1;
    final int h = endY - startY + 1;
    if (w <= 0 || h <= 0) return;

    final List<List<int>> points = [];
    for (int i = 0; i < numCells; i++) {
      final int px = startX + (_hashNoise(i, 0, seed) * w).floor();
      final int py = startY + (_hashNoise(0, i, seed + 99) * h).floor();
      points.add([px, py, i % 2 == 0 ? color : 0]);
    }

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
        double bestDist = double.infinity;
        int bestColor = color;
        for (final pt in points) {
          final double d =
              ((x - pt[0]) * (x - pt[0]) + (y - pt[1]) * (y - pt[1]))
                  .toDouble();
          if (d < bestDist) {
            bestDist = d;
            bestColor = pt[2];
          }
        }
        grid[y][x] = bestColor;
      }
    }
  }
}
