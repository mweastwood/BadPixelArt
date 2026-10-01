import 'dart:math' as math;

import 'base_command.dart';

/// Command to draw an outlined ellipse.
class EllipseCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, rx, ry] (outline)';

  final num cx;
  final num cy;
  final num rx;
  final num ry;

  EllipseCommand(this.cx, this.cy, this.rx, this.ry);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

    final double rxVal = rx < 0.5 ? 0.5 : rx.toDouble();
    final double ryVal = ry < 0.5 ? 0.5 : ry.toDouble();
    final double invRx = 1.0 / rxVal;
    final double invRy = 1.0 / ryVal;

    final int minX = math.max(0, (cx - rxVal - 1).floor());
    final int maxX = math.min(gridSize - 1, (cx + rxVal + 1).ceil());
    final int minY = math.max(0, (cy - ryVal - 1).floor());
    final int maxY = math.min(gridSize - 1, (cy + ryVal + 1).ceil());

    if (minX > maxX || minY > maxY) return;

    for (int y = minY; y <= maxY; y++) {
      final double dy = (y - cy) * invRy;
      final double dySq = dy * dy;

      for (int x = minX; x <= maxX; x++) {
        final double dx = (x - cx) * invRx;
        final double dist = dx * dx + dySq;
        // Threshold 0.35 (widened from 0.30) ensures the outline is at least
        // one pixel wide at low resolutions and for near-circular shapes where
        // the pixel grid is coarse relative to the ellipse perimeter.
        if ((dist - 1.0).abs() <= 0.35) {
          grid[y][x] = color;
        }
      }
    }
  }
}

