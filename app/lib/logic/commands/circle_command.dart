import 'base_command.dart';

/// Command to draw an outlined circle using Bresenham's midpoint circle algorithm.
class CircleCommand implements DrawingCommand {
  final int xc;
  final int yc;
  final int r;

  CircleCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    int x = 0;
    int y = r;
    int d = 3 - 2 * r;

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

    drawCirclePoints(x, y);
    while (y >= x) {
      x++;
      if (d > 0) {
        y--;
        d = d + 4 * (x - y) + 10;
      } else {
        d = d + 4 * x + 6;
      }
      drawCirclePoints(x, y);
    }
  }
}
