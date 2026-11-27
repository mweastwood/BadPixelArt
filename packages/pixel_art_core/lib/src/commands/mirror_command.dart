import 'base_command.dart';

/// Mirrors the grid horizontally (left-to-right by default, or right-to-left if [fromRight] is true).
class MirrorHorizontalCommand implements DrawingCommand {
  static const String usage =
      'params [] or [fromRight: 0|1] (mirrors left half to right half, or right to left)';

  final bool fromRight;

  MirrorHorizontalCommand({this.fromRight = false});

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    final int half = gridSize ~/ 2;
    for (int y = 0; y < gridSize && y < grid.length; y++) {
      final row = grid[y];
      final rowWidth = row.length < gridSize ? row.length : gridSize;
      for (int x = 0; x < half; x++) {
        final mx = rowWidth - 1 - x;
        if (mx < 0 || mx >= row.length) continue;
        if (fromRight) {
          row[x] = row[mx];
        } else {
          row[mx] = row[x];
        }
      }
    }
  }
}

/// Mirrors the grid vertically (top-to-bottom by default, or bottom-to-top if [fromBottom] is true).
class MirrorVerticalCommand implements DrawingCommand {
  static const String usage =
      'params [] or [fromBottom: 0|1] (mirrors top half to bottom half, or bottom to top)';

  final bool fromBottom;

  MirrorVerticalCommand({this.fromBottom = false});

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    final int height = grid.length < gridSize ? grid.length : gridSize;
    final int half = height ~/ 2;
    for (int y = 0; y < half; y++) {
      final my = height - 1 - y;
      final rowLen = grid[y].length < grid[my].length
          ? grid[y].length
          : grid[my].length;
      for (int x = 0; x < rowLen; x++) {
        if (fromBottom) {
          grid[y][x] = grid[my][x];
        } else {
          grid[my][x] = grid[y][x];
        }
      }
    }
  }
}
