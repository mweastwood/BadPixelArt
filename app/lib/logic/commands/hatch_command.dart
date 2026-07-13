import 'base_command.dart';

/// Command to flood fill a region with an alternating checkerboard pattern (hatch).
class HatchCommand implements DrawingCommand {
  static const String usage =
      'params [startX, startY] (alternating checkerboard pattern flood fill)';

  final int startX;
  final int startY;

  HatchCommand(this.startX, this.startY);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (startX < 0 || startX >= gridSize || startY < 0 || startY >= gridSize) {
      return;
    }
    int targetColor = grid[startY][startX];
    if (targetColor == color) return;

    List<List<int>> queue = [
      [startX, startY],
    ];
    Set<String> visited = {};

    while (queue.isNotEmpty) {
      var curr = queue.removeLast();
      int cx = curr[0];
      int cy = curr[1];
      String key = "$cx,$cy";
      if (visited.contains(key)) continue;
      visited.add(key);

      if (grid[cy][cx] == targetColor) {
        if ((cx + cy) % 2 == 0) {
          grid[cy][cx] = color;
        }

        if (cx > 0) queue.add([cx - 1, cy]);
        if (cx < gridSize - 1) queue.add([cx + 1, cy]);
        if (cy > 0) queue.add([cx, cy - 1]);
        if (cy < gridSize - 1) queue.add([cx, cy + 1]);
      }
    }
  }
}
