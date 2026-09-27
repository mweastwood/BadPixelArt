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
    if (gridSize <= 0 || w <= 0 || h <= 0) return;

    final double rad = angle * pi / 180.0;
    final double cosA = cos(rad);
    final double sinA = sin(rad);
    final double hw = w / 2.0;
    final double hh = h / 2.0;

    final int boundW = ((hw * cosA).abs() + (hh * sinA).abs()).ceil();
    final int boundH = ((hw * sinA).abs() + (hh * cosA).abs()).ceil();

    if (cx + boundW < 0 ||
        cx - boundW >= gridSize ||
        cy + boundH < 0 ||
        cy - boundH >= gridSize) {
      return;
    }

    final int minX = (cx - boundW).clamp(0, gridSize - 1);
    final int maxX = (cx + boundW).clamp(0, gridSize - 1);
    final int minY = (cy - boundH).clamp(0, gridSize - 1);
    final int maxY = (cy + boundH).clamp(0, gridSize - 1);

    for (int py = minY; py <= maxY; py++) {
      final double dy = (py - cy).toDouble();
      final double dySin = dy * sinA;
      final double dyCos = dy * cosA;

      for (int px = minX; px <= maxX; px++) {
        final double dx = (px - cx).toDouble();
        final double lx = dx * cosA + dySin;
        final double ly = -dx * sinA + dyCos;
        if (lx.abs() <= hw && ly.abs() <= hh) {
          grid[py][px] = color;
        }
      }
    }
  }
}
