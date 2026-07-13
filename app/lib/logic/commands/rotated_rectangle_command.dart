import 'dart:math';
import 'base_command.dart';

/// Command to draw a filled rotated rectangle.
class RotatedRectangleCommand implements DrawingCommand {
  static const String usage =
      'params [centerX, centerY, width, height, angle_degrees] (filled rotated rectangle)';

  final int cx;
  final int cy;
  final int w;
  final int h;
  final double angle;

  RotatedRectangleCommand(this.cx, this.cy, this.w, this.h, this.angle);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    final double rad = angle * pi / 180.0;
    final double cosA = cos(rad);
    final double sinA = sin(rad);
    final double hw = w / 2.0;
    final double hh = h / 2.0;

    final int maxR = (sqrt(hw * hw + hh * hh)).ceil() + 1;

    for (
      int py = (cy - maxR).clamp(0, gridSize - 1);
      py <= (cy + maxR).clamp(0, gridSize - 1);
      py++
    ) {
      for (
        int px = (cx - maxR).clamp(0, gridSize - 1);
        px <= (cx + maxR).clamp(0, gridSize - 1);
        px++
      ) {
        final double dx = (px - cx).toDouble();
        final double dy = (py - cy).toDouble();
        final double lx = dx * cosA + dy * sinA;
        final double ly = -dx * sinA + dy * cosA;
        if (lx.abs() <= hw && ly.abs() <= hh) {
          grid[py][px] = color;
        }
      }
    }
  }
}
