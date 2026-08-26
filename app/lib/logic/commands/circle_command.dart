import 'dart:math' as math;

import 'base_command.dart';

/// Command to draw an outlined circle supporting both integer and fractional centers.
class CircleCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, radius] (outline)';

  final num xc;
  final num yc;
  final num r;

  CircleCommand(this.xc, this.yc, this.r);

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

      void setPixel(int px, int py) {
        if (px >= 0 && px < gridSize && py >= 0 && py < gridSize) {
          grid[py][px] = color;
        }
      }

      void drawCirclePoints(int x, int y) {
        setPixel(xcInt + x, ycInt + y);
        setPixel(xcInt - x, ycInt + y);
        setPixel(xcInt + x, ycInt - y);
        setPixel(xcInt - x, ycInt - y);
        setPixel(xcInt + y, ycInt + x);
        setPixel(xcInt - y, ycInt + x);
        setPixel(xcInt + y, ycInt - x);
        setPixel(xcInt - y, ycInt - x);
      }

      int x = 0;
      int y = rInt;
      int d = 1 - rInt;
      drawCirclePoints(x, y);

      while (x < y) {
        x++;
        if (d < 0) {
          d += 2 * x + 1;
        } else {
          y--;
          d += 2 * (x - y) + 1;
        }
        drawCirclePoints(x, y);
      }
    } else {
      // Symmetric ±0.5 band around the ideal circle radius produces an even
      // one-pixel-wide outline regardless of the fractional center position.
      final double rIn = math.max(0.0, r - 0.5);
      final double rInSq = rIn * rIn;
      final double rOut = (r + 0.5).toDouble();
      final double rOutSq = rOut * rOut;

      final int minX = (xc - r - 1).floor().clamp(0, gridSize - 1);
      final int maxX = (xc + r + 1).ceil().clamp(0, gridSize - 1);
      final int minY = (yc - r - 1).floor().clamp(0, gridSize - 1);
      final int maxY = (yc + r + 1).ceil().clamp(0, gridSize - 1);

      for (int y = minY; y <= maxY; y++) {
        final double dy = y - yc.toDouble();
        for (int x = minX; x <= maxX; x++) {
          final double dx = x - xc.toDouble();
          final double distSq = dx * dx + dy * dy;
          if (distSq >= rInSq && distSq <= rOutSq) {
            grid[y][x] = color;
          }
        }
      }
    }
  }
}
