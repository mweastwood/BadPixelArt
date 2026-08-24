import 'dart:math' as math;
import 'base_command.dart';

/// Command to draw a hatched (checkerboard pattern) filled circle.
class CircleHatchedCommand implements DrawingCommand {
  static const String usage =
      'params [centerX, centerY, radius] (alternating checkerboard pattern fill)';

  final num xc;
  final num yc;
  final num r;

  CircleHatchedCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (r <= 0) {
      final int px = xc.round();
      final int py = yc.round();
      if (px >= 0 && px < gridSize && py >= 0 && py < gridSize) {
        if ((px + py) % 2 == 0) grid[py][px] = color;
      }
      return;
    }

    final double rSq = (r * r).toDouble();
    final int minX = math.max(0, (xc - r).floor());
    final int maxX = math.min(gridSize - 1, (xc + r).ceil());
    final int minY = math.max(0, (yc - r).floor());
    final int maxY = math.min(gridSize - 1, (yc + r).ceil());

    for (int y = minY; y <= maxY; y++) {
      final double dy = y - yc.toDouble();
      for (int x = minX; x <= maxX; x++) {
        final double dx = x - xc.toDouble();
        if (dx * dx + dy * dy <= rSq) {
          if ((x + y) % 2 == 0) {
            grid[y][x] = color;
          }
        }
      }
    }
  }
}
