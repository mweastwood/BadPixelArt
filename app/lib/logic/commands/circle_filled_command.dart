import 'dart:math' as math;

import 'base_command.dart';

/// Command to draw a filled circle supporting both integer and fractional
/// centers.
class CircleFilledCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, radius]';

  final num xc;
  final num yc;
  final num r;

  CircleFilledCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

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
        if (minX <= maxX) {
          grid[y].fillRange(minX, maxX + 1, color);
        }
      }

      void drawCircleScanlines(int x, int y) {
        drawScanline(ycInt + y, xcInt - x, xcInt + x);
        if (y != 0) {
          drawScanline(ycInt - y, xcInt - x, xcInt + x);
        }
        if (x != y) {
          drawScanline(ycInt + x, xcInt - y, xcInt + y);
          if (x != 0) {
            drawScanline(ycInt - x, xcInt - y, xcInt + y);
          }
        }
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
      const double eps = 1e-10;
      final int minY = math.max(0, (yc - r).floor());
      final int maxY = math.min(gridSize - 1, (yc + r).ceil());

      for (int y = minY; y <= maxY; y++) {
        final double dy = y - yc.toDouble();
        final double dySq = dy * dy;
        if (dySq > rSq) continue;

        final double halfW = math.sqrt(math.max(0.0, rSq - dySq));
        final int left = (xc - halfW - eps).ceil();
        final int right = (xc + halfW + eps).floor();
        final int rowMinX = math.max(0, left);
        final int rowMaxX = math.min(gridSize - 1, right);

        if (rowMinX <= rowMaxX) {
          grid[y].fillRange(rowMinX, rowMaxX + 1, color);
        }
      }
    }
  }
}
