import 'dart:typed_data';
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

    final Uint8List visited = Uint8List(gridSize * gridSize);
    final List<int> queue = [startY * gridSize + startX];
    visited[startY * gridSize + startX] = 1;

    while (queue.isNotEmpty) {
      final int pos = queue.removeLast();
      final int cx = pos % gridSize;
      final int cy = pos ~/ gridSize;

      if (grid[cy][cx] == targetColor) {
        if ((cx + cy) % 2 == 0) {
          grid[cy][cx] = color;
        }

        void checkNeighbor(int nx, int ny) {
          final int nIdx = ny * gridSize + nx;
          if (visited[nIdx] == 0) {
            visited[nIdx] = 1;
            queue.add(nIdx);
          }
        }

        if (cx > 0) checkNeighbor(cx - 1, cy);
        if (cx < gridSize - 1) checkNeighbor(cx + 1, cy);
        if (cy > 0) checkNeighbor(cx, cy - 1);
        if (cy < gridSize - 1) checkNeighbor(cx, cy + 1);
      }
    }
  }
}
