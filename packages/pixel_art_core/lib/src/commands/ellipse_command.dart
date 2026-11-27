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

    // Threshold 0.35 allows dist up to 1.35. The maximum extent along either
    // axis is sqrt(1.35) * radius. An epsilon guard prevents float truncation.
    const double maxScale = 1.161895003862225; // math.sqrt(1.35)
    const double eps = 1e-10;
    final double maxRx = rxVal * maxScale + eps;
    final double maxRy = ryVal * maxScale + eps;

    final int minX = math.max(0, (cx - maxRx).floor());
    final int maxX = math.min(gridSize - 1, (cx + maxRx).ceil());
    final int minY = math.max(0, (cy - maxRy).floor());
    final int maxY = math.min(gridSize - 1, (cy + maxRy).ceil());

    if (minX > maxX || minY > maxY) return;

    for (int y = minY; y <= maxY; y++) {
      final double dy = (y - cy) * invRy;
      final double dySq = dy * dy;
      if (dySq > 1.35) continue;

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
