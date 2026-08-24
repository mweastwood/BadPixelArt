import 'dart:math' as math;
import 'base_command.dart';

/// Command to draw a filled circle supporting both integer and fractional centers.
class CircleFilledCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, radius]';

  final num xc;
  final num yc;
  final num r;

  CircleFilledCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (r <= 0) {
      final int px = xc.round();
      final int py = yc.round();
      if (px >= 0 && px < gridSize && py >= 0 && py < gridSize) {
        grid[py][px] = color;
      }
      return;
    }

    final bool isInteger =
        xc == xc.roundToDouble() &&
        yc == yc.roundToDouble() &&
        r == r.roundToDouble();

    if (isInteger) {
      final int xcInt = xc.round();
      final int ycInt = yc.round();
      final int rInt = r.round();

      void drawScanline(int y, int x1, int x2) {
        if (y < 0 || y >= gridSize) return;
        final int minX = math.max(0, math.min(x1, x2));
        final int maxX = math.min(gridSize - 1, math.max(x1, x2));
        for (int x = minX; x <= maxX; x++) {
          grid[y][x] = color;
        }
      }

      void drawCircleScanlines(int x, int y) {
        drawScanline(ycInt + y, xcInt - x, xcInt + x);
        drawScanline(ycInt - y, xcInt - x, xcInt + x);
        drawScanline(ycInt + x, xcInt - y, xcInt + y);
        drawScanline(ycInt - x, xcInt - y, xcInt + y);
      }

      int x = 0;
      int y = rInt;
      int d = 1 - rInt;
      drawCircleScanlines(x, y);

      while (x < y) {
        x++;
        if (d < 0) {
          d += 2 * x + 1;
        } else {
          y--;
          d += 2 * (x - y) + 1;
        }
        drawCircleScanlines(x, y);
      }
    } else {
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
            grid[y][x] = color;
          }
        }
      }
    }
  }
}
