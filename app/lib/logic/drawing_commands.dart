/// Base class representing a drawing operation that can be executed on a grid.
abstract class DrawingCommand {
  /// Executes the drawing command on the given 2D [grid] using the provided [color] value.
  void execute(List<List<int>> grid, int color, int gridSize);
}

/// Command to draw a line between two points using Bresenham's line algorithm.
class LineCommand implements DrawingCommand {
  final int x1;
  final int y1;
  final int x2;
  final int y2;

  LineCommand(this.x1, this.y1, this.x2, this.y2);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    int cx1 = x1;
    int cy1 = y1;
    int dx = (x2 - cx1).abs();
    int dy = (y2 - cy1).abs();
    int sx = cx1 < x2 ? 1 : -1;
    int sy = cy1 < y2 ? 1 : -1;
    int err = dx - dy;

    while (true) {
      if (cx1 >= 0 && cx1 < gridSize && cy1 >= 0 && cy1 < gridSize) {
        grid[cy1][cx1] = color;
      }
      if (cx1 == x2 && cy1 == y2) break;
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        cx1 += sx;
      }
      if (e2 < dx) {
        err += dx;
        cy1 += sy;
      }
    }
  }
}

/// Command to draw an outlined circle using Bresenham's midpoint circle algorithm.
class CircleCommand implements DrawingCommand {
  final int xc;
  final int yc;
  final int r;

  CircleCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    int x = 0;
    int y = r;
    int d = 3 - 2 * r;

    void setPixel(int px, int py) {
      if (px >= 0 && px < gridSize && py >= 0 && py < gridSize) {
        grid[py][px] = color;
      }
    }

    void drawCirclePoints(int x, int y) {
      setPixel(xc + x, yc + y);
      setPixel(xc - x, yc + y);
      setPixel(xc + x, yc - y);
      setPixel(xc - x, yc - y);
      setPixel(xc + y, yc + x);
      setPixel(xc - y, yc + x);
      setPixel(xc + y, yc - x);
      setPixel(xc - y, yc - x);
    }

    drawCirclePoints(x, y);
    while (y >= x) {
      x++;
      if (d > 0) {
        y--;
        d = d + 4 * (x - y) + 10;
      } else {
        d = d + 4 * x + 6;
      }
      drawCirclePoints(x, y);
    }
  }
}

/// Command to draw a filled circle.
class CircleFilledCommand implements DrawingCommand {
  final int xc;
  final int yc;
  final int r;

  CircleFilledCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    for (int y = yc - r; y <= yc + r; y++) {
      for (int x = xc - r; x <= xc + r; x++) {
        if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
          if ((x - xc) * (x - xc) + (y - yc) * (y - yc) <= r * r) {
            grid[y][x] = color;
          }
        }
      }
    }
  }
}

/// Command to draw a hatched (checkerboard pattern) filled circle.
class CircleHatchedCommand implements DrawingCommand {
  final int xc;
  final int yc;
  final int r;

  CircleHatchedCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    for (int y = yc - r; y <= yc + r; y++) {
      for (int x = xc - r; x <= xc + r; x++) {
        if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
          if ((x - xc) * (x - xc) + (y - yc) * (y - yc) <= r * r) {
            if ((x + y) % 2 == 0) {
              grid[y][x] = color;
            }
          }
        }
      }
    }
  }
}

/// Command to draw an outlined rectangle.
class RectangleCommand implements DrawingCommand {
  final int x1;
  final int y1;
  final int x2;
  final int y2;

  RectangleCommand(this.x1, this.y1, this.x2, this.y2);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    int startX = x1 < x2 ? x1 : x2;
    int endX = x1 < x2 ? x2 : x1;
    int startY = y1 < y2 ? y1 : y2;
    int endY = y1 < y2 ? y2 : y1;
    for (int x = startX; x <= endX; x++) {
      if (x >= 0 && x < gridSize) {
        if (startY >= 0 && startY < gridSize) grid[startY][x] = color;
        if (endY >= 0 && endY < gridSize) grid[endY][x] = color;
      }
    }
    for (int y = startY; y <= endY; y++) {
      if (y >= 0 && y < gridSize) {
        if (startX >= 0 && startX < gridSize) grid[y][startX] = color;
        if (endX >= 0 && endX < gridSize) grid[y][endX] = color;
      }
    }
  }
}

/// Command to draw a filled rectangle.
class RectangleFilledCommand implements DrawingCommand {
  final int x1;
  final int y1;
  final int x2;
  final int y2;

  RectangleFilledCommand(this.x1, this.y1, this.x2, this.y2);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    int startX = x1 < x2 ? x1 : x2;
    int endX = x1 < x2 ? x2 : x1;
    int startY = y1 < y2 ? y1 : y2;
    int endY = y1 < y2 ? y2 : y1;
    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
          grid[y][x] = color;
        }
      }
    }
  }
}

/// Command to draw a hatched (checkerboard pattern) filled rectangle.
class RectangleHatchedCommand implements DrawingCommand {
  final int x1;
  final int y1;
  final int x2;
  final int y2;

  RectangleHatchedCommand(this.x1, this.y1, this.x2, this.y2);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    int startX = x1 < x2 ? x1 : x2;
    int endX = x1 < x2 ? x2 : x1;
    int startY = y1 < y2 ? y1 : y2;
    int endY = y1 < y2 ? y2 : y1;
    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
          if ((x + y) % 2 == 0) {
            grid[y][x] = color;
          }
        }
      }
    }
  }
}

/// Command to flood fill a region with a single color.
class FillCommand implements DrawingCommand {
  final int startX;
  final int startY;

  FillCommand(this.startX, this.startY);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (startX < 0 || startX >= gridSize || startY < 0 || startY >= gridSize) {
      return;
    }
    int targetColor = grid[startY][startX];
    if (targetColor == color) return;

    List<List<int>> queue = [
      [startX, startY],
    ];
    while (queue.isNotEmpty) {
      var curr = queue.removeLast();
      int cx = curr[0];
      int cy = curr[1];

      if (grid[cy][cx] == targetColor) {
        grid[cy][cx] = color;

        if (cx > 0) queue.add([cx - 1, cy]);
        if (cx < gridSize - 1) queue.add([cx + 1, cy]);
        if (cy > 0) queue.add([cx, cy - 1]);
        if (cy < gridSize - 1) queue.add([cx, cy + 1]);
      }
    }
  }
}

/// Command to flood fill a region with an alternating checkerboard pattern (hatch).
class HatchCommand implements DrawingCommand {
  final int startX;
  final int startY;

  HatchCommand(this.startX, this.startY);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (startX < 0 || startX >= gridSize || startY < 0 || startY >= gridSize) {
      return;
    }
    int targetColor = grid[startY][startX];
    if (targetColor == color) return;

    List<List<int>> queue = [
      [startX, startY],
    ];
    Set<String> visited = {};

    while (queue.isNotEmpty) {
      var curr = queue.removeLast();
      int cx = curr[0];
      int cy = curr[1];
      String key = "$cx,$cy";
      if (visited.contains(key)) continue;
      visited.add(key);

      if (grid[cy][cx] == targetColor) {
        if ((cx + cy) % 2 == 0) {
          grid[cy][cx] = color;
        }

        if (cx > 0) queue.add([cx - 1, cy]);
        if (cx < gridSize - 1) queue.add([cx + 1, cy]);
        if (cy > 0) queue.add([cx, cy - 1]);
        if (cy < gridSize - 1) queue.add([cx, cy + 1]);
      }
    }
  }
}

/// Factory class to instantiate DrawingCommands from tool configurations.
class DrawingCommandFactory {
  /// Returns the matching [DrawingCommand] instance based on the [toolName] and [params].
  /// Returns `null` if the tool configurations are invalid or unsupported.
  static DrawingCommand? create(String toolName, List<int> params) {
    switch (toolName) {
      case 'line':
        if (params.length >= 4) {
          return LineCommand(params[0], params[1], params[2], params[3]);
        }
        break;
      case 'circle':
        if (params.length >= 3) {
          return CircleCommand(params[0], params[1], params[2]);
        }
        break;
      case 'circle_filled':
        if (params.length >= 3) {
          return CircleFilledCommand(params[0], params[1], params[2]);
        }
        break;
      case 'circle_hatched':
        if (params.length >= 3) {
          return CircleHatchedCommand(params[0], params[1], params[2]);
        }
        break;
      case 'rectangle':
        if (params.length >= 4) {
          return RectangleCommand(params[0], params[1], params[2], params[3]);
        }
        break;
      case 'rectangle_filled':
        if (params.length >= 4) {
          return RectangleFilledCommand(
            params[0],
            params[1],
            params[2],
            params[3],
          );
        }
        break;
      case 'rectangle_hatched':
        if (params.length >= 4) {
          return RectangleHatchedCommand(
            params[0],
            params[1],
            params[2],
            params[3],
          );
        }
        break;
      case 'fill':
        if (params.length >= 2) {
          return FillCommand(params[0], params[1]);
        }
        break;
      case 'hatch':
        if (params.length >= 2) {
          return HatchCommand(params[0], params[1]);
        }
        break;
    }
    return null;
  }
}
