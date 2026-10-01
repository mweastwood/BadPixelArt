import 'dart:math' as math;

import 'base_command.dart';

/// Command to draw a filled rectangle.
class RectangleFilledCommand implements DrawingCommand {
  static const String usage = 'params [startX, startY, endX, endY]';

  final int x1;
  final int y1;
  final int x2;
  final int y2;

  RectangleFilledCommand(this.x1, this.y1, this.x2, this.y2);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

    final int startX = math.min(x1, x2);
    final int endX = math.max(x1, x2);
    final int startY = math.min(y1, y2);
    final int endY = math.max(y1, y2);

    final int clampedMinY = math.max(0, startY);
    final int clampedMaxY = math.min(gridSize - 1, endY);
    final int clampedMinX = math.max(0, startX);
    final int clampedMaxX = math.min(gridSize - 1, endX);

    if (clampedMinY > clampedMaxY || clampedMinX > clampedMaxX) {
      return;
    }

    for (int y = clampedMinY; y <= clampedMaxY; y++) {
      grid[y].fillRange(clampedMinX, clampedMaxX + 1, color);
    }
  }
}
