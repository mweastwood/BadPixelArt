import 'base_command.dart';

/// Command to flood fill a region with a single color.
class FillCommand implements DrawingCommand {
  static const String usage = 'params [startX, startY]';

  final int startX;
  final int startY;

  FillCommand(this.startX, this.startY);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (startX < 0 || startX >= gridSize || startY < 0 || startY >= gridSize) {
      return;
    }
    int targetColor = grid[startY][startX];
    if (targetColor == color) return;

    grid[startY][startX] = color;
    final List<int> queue = [startY * gridSize + startX];

    while (queue.isNotEmpty) {
      final int pos = queue.removeLast();
      final int cx = pos % gridSize;
      final int cy = pos ~/ gridSize;

      void checkNeighbor(int nx, int ny) {
        if (grid[ny][nx] == targetColor) {
          grid[ny][nx] = color;
          queue.add(ny * gridSize + nx);
        }
      }

      if (cx > 0) checkNeighbor(cx - 1, cy);
      if (cx < gridSize - 1) checkNeighbor(cx + 1, cy);
      if (cy > 0) checkNeighbor(cx, cy - 1);
      if (cy < gridSize - 1) checkNeighbor(cx, cy + 1);
    }
  }
}
