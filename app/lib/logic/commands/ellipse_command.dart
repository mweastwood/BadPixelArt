import 'base_command.dart';

/// Command to draw an outlined ellipse.
class EllipseCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, rx, ry] (outline)';

  final num cx;
  final num cy;
  final num rx;
  final num ry;

  EllipseCommand(this.cx, this.cy, this.rx, this.ry);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

    final double rxVal = rx < 0.5 ? 0.5 : rx.toDouble();
    final double ryVal = ry < 0.5 ? 0.5 : ry.toDouble();

    final int minX = (cx - rxVal - 1).floor().clamp(0, gridSize - 1);
    final int maxX = (cx + rxVal + 1).ceil().clamp(0, gridSize - 1);
    final int minY = (cy - ryVal - 1).floor().clamp(0, gridSize - 1);
    final int maxY = (cy + ryVal + 1).ceil().clamp(0, gridSize - 1);

    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final double dx = (x - cx) / rxVal;
        final double dy = (y - cy) / ryVal;
        final double dist = dx * dx + dy * dy;
        // Threshold 0.35 (widened from 0.30) ensures the outline is at least
        // one pixel wide at low resolutions and for near-circular shapes where
        // the pixel grid is coarse relative to the ellipse perimeter.
        if ((dist - 1.0).abs() <= 0.35) {
          grid[y][x] = color;
        }
      }
    }
  }
}
