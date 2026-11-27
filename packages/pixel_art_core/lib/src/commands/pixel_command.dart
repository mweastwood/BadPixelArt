import 'base_command.dart';

/// Command to draw a single pixel.
class PixelCommand implements DrawingCommand {
  static const String usage = 'params [x, y]';

  final int x;
  final int y;

  PixelCommand(this.x, this.y);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
      grid[y][x] = color;
    }
  }
}
