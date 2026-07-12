import 'base_command.dart';

/// Command to draw a hatched (checkerboard pattern) filled rectangle.
class RectangleHatchedCommand implements DrawingCommand {
  final int x1;
  final int y1;
  final int x2;
  final int y2;

  RectangleHatchedCommand(this.x1, this.y1, this.x2, this.y2);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    int startX = x1 < x2 ? x1 : x2;
    int endX = x1 < x2 ? x2 : x1;
    int startY = y1 < y2 ? y1 : y2;
    int endY = y1 < y2 ? y2 : y1;
    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
          if ((x + y) % 2 == 0) {
            grid[y][x] = color;
          }
        }
      }
    }
  }
}
