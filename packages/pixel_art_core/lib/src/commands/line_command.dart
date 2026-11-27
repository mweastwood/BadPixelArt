import 'base_command.dart';

/// Command to draw a line between two points using Bresenham's line algorithm.
class LineCommand implements DrawingCommand {
  static const String usage = 'params [startX, startY, endX, endY]';

  final int x1;
  final int y1;
  final int x2;
  final int y2;

  LineCommand(this.x1, this.y1, this.x2, this.y2);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    int cx1 = x1;
    int cy1 = y1;
    int dx = (x2 - cx1).abs();
    int dy = (y2 - cy1).abs();
    int sx = cx1 < x2 ? 1 : -1;
    int sy = cy1 < y2 ? 1 : -1;
    int err = dx - dy;

    while (true) {
      if (cx1 >= 0 && cx1 < gridSize && cy1 >= 0 && cy1 < gridSize) {
        grid[cy1][cx1] = color;
      }
      if (cx1 == x2 && cy1 == y2) break;
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        cx1 += sx;
      }
      if (e2 < dx) {
        err += dx;
        cy1 += sy;
      }
    }
  }
}
