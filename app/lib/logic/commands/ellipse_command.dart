import 'base_command.dart';

/// Command to draw an outlined ellipse.
class EllipseCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, rx, ry] (outline)';

  final int cx;
  final int cy;
  final int rx;
  final int ry;

  EllipseCommand(this.cx, this.cy, this.rx, this.ry);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    final int rxVal = rx < 1 ? 1 : rx;
    final int ryVal = ry < 1 ? 1 : ry;

    for (int y = cy - ryVal; y <= cy + ryVal; y++) {
      for (int x = cx - rxVal; x <= cx + rxVal; x++) {
        if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
          final double dx = (x - cx) / rxVal;
          final double dy = (y - cy) / ryVal;
          final double dist = dx * dx + dy * dy;
          if ((dist - 1.0).abs() <= 0.3) {
            grid[y][x] = color;
          }
        }
      }
    }
  }
}
