import 'dart:math' as math;
import 'base_command.dart';

/// Command to draw a filled circle using Midpoint Circle scanlines.
class CircleFilledCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, radius]';

  final int xc;
  final int yc;
  final int r;

  CircleFilledCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (r <= 0) {
      if (xc >= 0 && xc < gridSize && yc >= 0 && yc < gridSize) {
        grid[yc][xc] = color;
      }
      return;
    }

    void drawScanline(int y, int x1, int x2) {
      if (y < 0 || y >= gridSize) return;
      final int minX = math.max(0, math.min(x1, x2));
      final int maxX = math.min(gridSize - 1, math.max(x1, x2));
      for (int x = minX; x <= maxX; x++) {
        grid[y][x] = color;
      }
    }

    void drawCircleScanlines(int x, int y) {
      drawScanline(yc + y, xc - x, xc + x);
      drawScanline(yc - y, xc - x, xc + x);
      drawScanline(yc + x, xc - y, xc + y);
      drawScanline(yc - x, xc - y, xc + y);
    }

    int x = 0;
    int y = r;
    int d = 1 - r;
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
  }
}
