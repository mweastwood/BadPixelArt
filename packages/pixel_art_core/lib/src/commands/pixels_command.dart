import 'base_command.dart';

/// Command to draw multiple individual pixels in batch.
class PixelsCommand implements DrawingCommand {
  static const String usage =
      'params [x1, y1, x2, y2, ...] (draws multiple individual pixels)';

  final List<int> coords;

  PixelsCommand(this.coords);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    for (int i = 0; i < coords.length - 1; i += 2) {
      final x = coords[i];
      final y = coords[i + 1];
      if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
        grid[y][x] = color;
      }
    }
  }
}
