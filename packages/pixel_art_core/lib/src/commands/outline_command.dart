import 'base_command.dart';

/// Adds a 1px outer silhouette outline in `color` on empty (0) pixels adjacent
/// to any non-zero pixel.
///
/// By default uses 4-connectivity (cardinal neighbors only), which produces
/// cleaner pixel-art outlines without chunky double corners. Pass `[8]` to
/// include diagonal neighbors.
class OutlineCommand implements DrawingCommand {
  static const String usage =
      'params [] or [connectivity: 4|8] (adds 1px outer outline on empty pixels bordering non-empty pixels)';

  final bool eightConnected;

  OutlineCommand({this.eightConnected = false});

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    final int height = grid.length < gridSize ? grid.length : gridSize;
    if (height <= 0) return;

    final toOutline = <(int, int)>[];
    final dx = eightConnected
        ? const [-1, 0, 1, -1, 1, -1, 0, 1]
        : const [0, 0, -1, 1];
    final dy = eightConnected
        ? const [-1, -1, -1, 0, 0, 1, 1, 1]
        : const [-1, 1, 0, 0];

    for (int y = 0; y < height; y++) {
      final row = grid[y];
      final width = row.length < gridSize ? row.length : gridSize;
      for (int x = 0; x < width; x++) {
        if (row[x] != 0) continue;
        for (int i = 0; i < dx.length; i++) {
          final nx = x + dx[i];
          final ny = y + dy[i];
          if (ny >= 0 && ny < height && nx >= 0 && nx < grid[ny].length) {
            if (grid[ny][nx] > 0) {
              toOutline.add((x, y));
              break;
            }
          }
        }
      }
    }

    for (final (x, y) in toOutline) {
      grid[y][x] = color;
    }
  }
}
