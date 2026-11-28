import 'dart:typed_data';

import '../utils/noise_utils.dart';
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

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (numCells <= 0 || gridSize <= 0) return;

    final int startX = x1 < x2 ? x1 : x2;
    final int endX = x1 < x2 ? x2 : x1;
    final int startY = y1 < y2 ? y1 : y2;
    final int endY = y1 < y2 ? y2 : y1;

    if (endX < 0 || startX >= gridSize || endY < 0 || startY >= gridSize) {
      return;
    }

    final int w = endX - startX + 1;
    final int h = endY - startY + 1;
    if (w <= 0 || h <= 0) return;

    final pointsX = Int32List(numCells);
    final pointsY = Int32List(numCells);
    final pointsColor = Int32List(numCells);

    for (int i = 0; i < numCells; i++) {
      pointsX[i] = startX + (hashNoise(i, 0, seed) * w).floor();
      pointsY[i] = startY + (hashNoise(0, i, seed + 99) * h).floor();
      pointsColor[i] = i % 2 == 0 ? color : 0;
    }

    final int clampedStartY = startY.clamp(0, gridSize - 1);
    final int clampedEndY = endY.clamp(0, gridSize - 1);
    final int clampedStartX = startX.clamp(0, gridSize - 1);
    final int clampedEndX = endX.clamp(0, gridSize - 1);

    for (int y = clampedStartY; y <= clampedEndY; y++) {
      for (int x = clampedStartX; x <= clampedEndX; x++) {
        int bestDist = 0x7FFFFFFF;
        int bestColor = color;
        for (int i = 0; i < numCells; i++) {
          final int dx = x - pointsX[i];
          final int dy = y - pointsY[i];
          final int dist = dx * dx + dy * dy;
          if (dist < bestDist) {
            bestDist = dist;
            bestColor = pointsColor[i];
          }
        }
        grid[y][x] = bestColor;
      }
    }
  }
}
