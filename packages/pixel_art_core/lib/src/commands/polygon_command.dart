import 'dart:math' as math;

import 'base_command.dart';
import 'line_command.dart';

/// Command to draw a filled arbitrary polygon from vertex coordinates
/// `[x1, y1, x2, y2, x3, y3, ...]`.
class PolygonCommand implements DrawingCommand {
  static const String usage =
      'params [x1, y1, x2, y2, x3, y3, ...] (filled polygon, 3+ vertices)';

  final List<(int, int)> vertices;

  PolygonCommand(this.vertices);

  factory PolygonCommand.fromFlatParams(List<num> params) {
    final pts = <(int, int)>[];
    for (int i = 0; i + 1 < params.length; i += 2) {
      pts.add((params[i].round(), params[i + 1].round()));
    }
    return PolygonCommand(pts);
  }

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    final n = vertices.length;
    if (n < 3 || gridSize <= 0) return;

    int minY = vertices[0].$2;
    int maxY = vertices[0].$2;
    for (final (_, y) in vertices) {
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    final startY = math.max(0, minY);
    final endY = math.min(gridSize - 1, maxY);

    // Scanline fill using pixel center sampling (y + 0.5)
    for (int y = startY; y <= endY; y++) {
      final double sy = y + 0.5;
      final intersections = <double>[];

      for (int i = 0; i < n; i++) {
        final (x1, y1) = vertices[i];
        final (x2, y2) = vertices[(i + 1) % n];
        if (y1 == y2) continue;
        final double dy1 = y1.toDouble();
        final double dy2 = y2.toDouble();
        if ((dy1 <= sy && dy2 > sy) || (dy2 <= sy && dy1 > sy)) {
          final double t = (sy - dy1) / (dy2 - dy1);
          intersections.add(x1 + t * (x2 - x1));
        }
      }

      intersections.sort();
      for (int i = 0; i + 1 < intersections.length; i += 2) {
        final xStart = math.max(0, intersections[i].floor());
        final xEnd = math.min(gridSize - 1, intersections[i + 1].ceil());
        if (xStart <= xEnd) {
          grid[y].fillRange(xStart, xEnd + 1, color);
        }
      }
    }

    // Trace edges with Bresenham lines so crisp tips/vertices are preserved.
    for (int i = 0; i < n; i++) {
      final (x1, y1) = vertices[i];
      final (x2, y2) = vertices[(i + 1) % n];
      LineCommand(x1, y1, x2, y2).execute(grid, color, gridSize);
    }
  }
}
