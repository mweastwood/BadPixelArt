import 'base_command.dart';

/// Command to draw a hatched (checkerboard pattern) filled circle.
class CircleHatchedCommand implements DrawingCommand {
  final int xc;
  final int yc;
  final int r;

  CircleHatchedCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    for (int y = yc - r; y <= yc + r; y++) {
      for (int x = xc - r; x <= xc + r; x++) {
        if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
          if ((x - xc) * (x - xc) + (y - yc) * (y - yc) <= r * r) {
            if ((x + y) % 2 == 0) {
              grid[y][x] = color;
            }
          }
        }
      }
    }
  }
}
