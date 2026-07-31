import 'dart:math' as math;
import 'base_command.dart';

/// Command to draw an outlined circle using precision midpoint rounding without extra compass pixels.
class CircleCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, radius] (outline)';

  final int xc;
  final int yc;
  final int r;

  CircleCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (r <= 0) {
      if (xc >= 0 && xc < gridSize && yc >= 0 && yc < gridSize) {
        grid[yc][xc] = color;
      }
      return;
    }

    void setPixel(int px, int py) {
      if (px >= 0 && px < gridSize && py >= 0 && py < gridSize) {
        grid[py][px] = color;
      }
    }

    void drawCirclePoints(int x, int y) {
      setPixel(xc + x, yc + y);
      setPixel(xc - x, yc + y);
      setPixel(xc + x, yc - y);
      setPixel(xc - x, yc - y);
      setPixel(xc + y, yc + x);
      setPixel(xc - y, yc + x);
      setPixel(xc + y, yc - x);
      setPixel(xc - y, yc - x);
    }

    int x = 0;
    int y = r;
    drawCirclePoints(x, y);

    while (x < y) {
      x++;
      y = math.sqrt(r * r - x * x).round();
      if (x > 0 && y == r) {
        y = r - 1;
      }
      if (x <= y) {
        drawCirclePoints(x, y);
      }
    }
  }
}
