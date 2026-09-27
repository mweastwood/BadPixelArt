import 'dart:math' as math;

import 'base_command.dart';

/// Command to draw a filled ellipse.
class EllipseFilledCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, rx, ry]';

  final num cx;
  final num cy;
  final num rx;
  final num ry;

  EllipseFilledCommand(this.cx, this.cy, this.rx, this.ry);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

    final double rxVal = rx < 0.5 ? 0.5 : rx.toDouble();
    final double ryVal = ry < 0.5 ? 0.5 : ry.toDouble();
    final double invRy = 1.0 / ryVal;
    const double eps = 1e-10;

    final int minY = (cy - ryVal).floor();
    final int maxY = (cy + ryVal).ceil();
    final int clampedMinY = math.max(0, minY);
    final int clampedMaxY = math.min(gridSize - 1, maxY);

    for (int y = clampedMinY; y <= clampedMaxY; y++) {
      final double normY = (y - cy) * invRy;
      final double normYSq = normY * normY;
      if (normYSq > 1.0 + eps) continue;

      final double halfW = rxVal * math.sqrt(math.max(0.0, 1.0 - normYSq));
      final int left = (cx - halfW - eps).ceil();
      final int right = (cx + halfW + eps).floor();
      final int rowMinX = math.max(0, left);
      final int rowMaxX = math.min(gridSize - 1, right);

      if (rowMinX <= rowMaxX) {
        grid[y].fillRange(rowMinX, rowMaxX + 1, color);
      }
    }
  }
}
