import 'base_command.dart';

/// Command to draw a filled triangle using edge-side signing function.
class TriangleCommand implements DrawingCommand {
  static const String usage =
      'params [x1, y1, x2, y2, x3, y3] (filled triangle)';

  final int x1;
  final int y1;
  final int x2;
  final int y2;
  final int x3;
  final int y3;

  TriangleCommand(this.x1, this.y1, this.x2, this.y2, this.x3, this.y3);

  static int _sign(int px, int py, int ax, int ay, int bx, int by) {
    return (px - bx) * (ay - by) - (ax - bx) * (py - by);
  }

  static int _min3(int a, int b, int c) =>
      a < b ? (a < c ? a : c) : (b < c ? b : c);
  static int _max3(int a, int b, int c) =>
      a > b ? (a > c ? a : c) : (b > c ? b : c);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

    final int rawMinX = _min3(x1, x2, x3);
    final int rawMaxX = _max3(x1, x2, x3);
    final int rawMinY = _min3(y1, y2, y3);
    final int rawMaxY = _max3(y1, y2, y3);

    if (rawMaxX < 0 ||
        rawMinX >= gridSize ||
        rawMaxY < 0 ||
        rawMinY >= gridSize) {
      return;
    }

    final int minX = rawMinX.clamp(0, gridSize - 1);
    final int maxX = rawMaxX.clamp(0, gridSize - 1);
    final int minY = rawMinY.clamp(0, gridSize - 1);
    final int maxY = rawMaxY.clamp(0, gridSize - 1);

    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final int d1 = _sign(x, y, x1, y1, x2, y2);
        final int d2 = _sign(x, y, x2, y2, x3, y3);
        final int d3 = _sign(x, y, x3, y3, x1, y1);
        final bool hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
        final bool hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
        if (!(hasNeg && hasPos)) {
          grid[y][x] = color;
        }
      }
    }
  }
}
