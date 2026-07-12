import 'base_command.dart';

/// Command to draw an outlined rectangle.
class RectangleCommand implements DrawingCommand {
  static const String usage = 'params [startX, startY, endX, endY] (outline)';

  final int x1;
  final int y1;
  final int x2;
  final int y2;

  RectangleCommand(this.x1, this.y1, this.x2, this.y2);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    int startX = x1 < x2 ? x1 : x2;
    int endX = x1 < x2 ? x2 : x1;
    int startY = y1 < y2 ? y1 : y2;
    int endY = y1 < y2 ? y2 : y1;
    for (int x = startX; x <= endX; x++) {
      if (x >= 0 && x < gridSize) {
        if (startY >= 0 && startY < gridSize) grid[startY][x] = color;
        if (endY >= 0 && endY < gridSize) grid[endY][x] = color;
      }
    }
    for (int y = startY; y <= endY; y++) {
      if (y >= 0 && y < gridSize) {
        if (startX >= 0 && startX < gridSize) grid[y][startX] = color;
        if (endX >= 0 && endX < gridSize) grid[y][endX] = color;
      }
    }
  }
}
