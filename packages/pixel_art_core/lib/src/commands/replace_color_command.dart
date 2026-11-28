import 'base_command.dart';

/// Replaces all occurrences of [fromColor] in the grid with the command's target `color`.
class ReplaceColorCommand implements DrawingCommand {
  static const String usage =
      'params [fromColorIndex] (replaces all pixels of fromColorIndex with color)';

  final int fromColor;

  ReplaceColorCommand(this.fromColor);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    for (int y = 0; y < grid.length && y < gridSize; y++) {
      final row = grid[y];
      for (int x = 0; x < row.length && x < gridSize; x++) {
        if (row[x] == fromColor) {
          row[x] = color;
        }
      }
    }
  }
}
