import 'base_command.dart';

/// Command to draw a filled ellipse.
class EllipseFilledCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, rx, ry]';

  final num cx;
  final num cy;
  final num rx;
  final num ry;

  EllipseFilledCommand(this.cx, this.cy, this.rx, this.ry);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    final double rxVal = rx < 0.5 ? 0.5 : rx.toDouble();
    final double ryVal = ry < 0.5 ? 0.5 : ry.toDouble();

    final int minX = (cx - rxVal).floor().clamp(0, gridSize - 1);
    final int maxX = (cx + rxVal).ceil().clamp(0, gridSize - 1);
    final int minY = (cy - ryVal).floor().clamp(0, gridSize - 1);
    final int maxY = (cy + ryVal).ceil().clamp(0, gridSize - 1);

    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final double dx = (x - cx) / rxVal;
        final double dy = (y - cy) / ryVal;
        final double dist = dx * dx + dy * dy;
        if (dist <= 1.0) {
          grid[y][x] = color;
        }
      }
    }
  }
}
