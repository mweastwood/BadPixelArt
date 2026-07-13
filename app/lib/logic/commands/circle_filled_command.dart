import 'base_command.dart';

/// Command to draw a filled circle.
class CircleFilledCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, radius]';

  final int xc;
  final int yc;
  final int r;

  CircleFilledCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    for (int y = yc - r; y <= yc + r; y++) {
      for (int x = xc - r; x <= xc + r; x++) {
        if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
          if ((x - xc) * (x - xc) + (y - yc) * (y - yc) <= r * r) {
            grid[y][x] = color;
          }
        }
      }
    }
  }
}
