// GENERATED FILE — DO NOT EDIT DIRECTLY.
// Regenerate via: cd packages/pixel_art_core && dart run tool/bundle_skill.dart
// ignore_for_file: unused_element, unused_local_variable

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:math' as math;
import 'dart:typed_data';

// === lib/src/types.dart ===
/// Pure-Dart immutable 32-bit ARGB color representation.
class PixelColor {
  /// Packed 32-bit ARGB integer (`0xAARRGGBB`).
  final int value;

  const PixelColor(this.value);

  /// Creates a color from individual 0..255 channel values.
  const PixelColor.fromARGB(int a, int r, int g, int b)
    : value =
          ((a & 0xFF) << 24) |
          ((r & 0xFF) << 16) |
          ((g & 0xFF) << 8) |
          (b & 0xFF);

  /// Creates an opaque color from 0..255 RGB values.
  const PixelColor.fromRGB(int r, int g, int b)
    : value = 0xFF000000 | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);

  int get a => (value >> 24) & 0xFF;
  int get r => (value >> 16) & 0xFF;
  int get g => (value >> 8) & 0xFF;
  int get b => value & 0xFF;

  int toARGB32() => value;

  /// Formats as `#rrggbb` (or `#aarrggbb` when [includeAlpha] is true).
  String toHex({bool includeAlpha = false, bool uppercase = false}) {
    final hex = includeAlpha
        ? value.toRadixString(16).padLeft(8, '0')
        : (value & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
    return '#${uppercase ? hex.toUpperCase() : hex}';
  }

  /// Parses `#RGB`, `#RGBA`, `#RRGGBB`, `#AARRGGBB`, or `0x...` hex strings.
  /// Returns `null` if invalid.
  static PixelColor? tryParseHex(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;

    final hasPrefix = s.startsWith('#') || s.toLowerCase().startsWith('0x');
    if (s.toLowerCase().startsWith('0x')) {
      s = s.substring(2).trim();
    } else if (s.startsWith('#')) {
      s = s.substring(1).trim();
    }

    if (hasPrefix && s.length == 3) {
      s = '${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
    } else if (hasPrefix && s.length == 4) {
      // #RGBA -> AARRGGBB
      s = '${s[3]}${s[3]}${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
    }

    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) return null;

    if (s.length == 6) {
      final v = int.tryParse('FF$s', radix: 16);
      return v == null ? null : PixelColor(v);
    }
    if (s.length == 8) {
      final v = int.tryParse(s, radix: 16);
      return v == null ? null : PixelColor(v);
    }
    return null;
  }

  /// Parses hex or throws [FormatException].
  factory PixelColor.parseHex(String hex) {
    final c = tryParseHex(hex);
    if (c == null) {
      throw FormatException('Invalid hex color: "$hex"');
    }
    return c;
  }

  static const PixelColor transparent = PixelColor(0x00000000);
  static const PixelColor black = PixelColor(0xFF000000);
  static const PixelColor white = PixelColor(0xFFFFFFFF);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PixelColor && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PixelColor(${toHex(includeAlpha: a != 255)})';
}

/// Pure-Dart normalized 2D rectangle (typically in `0.0..1.0` coordinates).
class NormalizedRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const NormalizedRect.fromLTWH(this.left, this.top, this.width, this.height);

  static const NormalizedRect zero = NormalizedRect.fromLTWH(0, 0, 0, 0);
  static const NormalizedRect full = NormalizedRect.fromLTWH(0, 0, 1, 1);

  double get right => left + width;
  double get bottom => top + height;

  Map<String, double> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  factory NormalizedRect.fromJson(Map<String, dynamic> json) {
    return NormalizedRect.fromLTWH(
      ((json['left'] as num?) ?? 0.0).toDouble(),
      ((json['top'] as num?) ?? 0.0).toDouble(),
      ((json['width'] as num?) ?? 1.0).toDouble(),
      ((json['height'] as num?) ?? 1.0).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedRect &&
          left == other.left &&
          top == other.top &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'NormalizedRect.fromLTWH($left, $top, $width, $height)';
}

// === lib/src/utils/noise_utils.dart ===
/// Computes a deterministic pseudo-random floating point value in the range [0.0, 1.0]
/// based on 2D coordinates [x], [y] and an integer [seed].
double hashNoise(int x, int y, int seed) {
  int n = x * 374761393 + y * 668265263 + seed * 1274126177;
  n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff;
  n = n ^ (n >> 16);
  return (n & 0x7fffffff) / 0x7fffffff;
}

// === lib/src/coordinate_converter.dart ===

/// Represents integer pixel grid bounds `[leftCol, topRow, rightCol, bottomRow]`,
/// where `leftCol` and `topRow` are inclusive start indices, and `rightCol` and
/// `bottomRow` are exclusive end indices.
///
/// Provides convenience getters for 0-indexed inclusive pixel ranges `[minX, maxX]`
/// and `[minY, maxY]`.
class GridBounds {
  /// Inclusive start column (x-axis index), clamped within `0..gridSize`.
  final int leftCol;

  /// Inclusive start row (y-axis index), clamped within `0..gridSize`.
  final int topRow;

  /// Exclusive end column (x-axis index), clamped within `0..gridSize`.
  final int rightCol;

  /// Exclusive end row (y-axis index), clamped within `0..gridSize`.
  final int bottomRow;

  const GridBounds({
    required this.leftCol,
    required this.topRow,
    required this.rightCol,
    required this.bottomRow,
  });

  /// Creates a [GridBounds] from 0-indexed inclusive pixel coordinates `[minX, maxX, minY, maxY]`.
  factory GridBounds.fromMinMax({
    required int minX,
    required int maxX,
    required int minY,
    required int maxY,
  }) {
    return GridBounds(
      leftCol: minX,
      topRow: minY,
      rightCol: maxX + 1,
      bottomRow: maxY + 1,
    );
  }

  /// 0-indexed inclusive minimum X pixel coordinate.
  int get minX => leftCol;

  /// 0-indexed inclusive maximum X pixel coordinate.
  int get maxX => rightCol - 1;

  /// 0-indexed inclusive minimum Y pixel coordinate.
  int get minY => topRow;

  /// 0-indexed inclusive maximum Y pixel coordinate.
  int get maxY => bottomRow - 1;

  /// Width in grid cells/pixels.
  int get width => rightCol - leftCol;

  /// Height in grid cells/pixels.
  int get height => bottomRow - topRow;

  /// Whether the bounds contain zero area.
  bool get isEmpty => width <= 0 || height <= 0;

  /// Whether the bounds contain non-zero area.
  bool get isNotEmpty => !isEmpty;

  /// Checks if pixel coordinate `(x, y)` is within grid bounds.
  bool containsPixel(int x, int y) {
    return x >= leftCol && x < rightCol && y >= topRow && y < bottomRow;
  }

  /// Converts integer grid bounds back to a normalized `0.0..1.0` [NormalizedRect].
  NormalizedRect toNormalizedRect(int gridSize) {
    if (gridSize <= 0) return NormalizedRect.zero;
    return NormalizedRect.fromLTWH(
      leftCol / gridSize,
      topRow / gridSize,
      width / gridSize,
      height / gridSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridBounds &&
          runtimeType == other.runtimeType &&
          leftCol == other.leftCol &&
          topRow == other.topRow &&
          rightCol == other.rightCol &&
          bottomRow == other.bottomRow;

  @override
  int get hashCode => Object.hash(leftCol, topRow, rightCol, bottomRow);

  @override
  String toString() =>
      'GridBounds(leftCol: $leftCol, topRow: $topRow, rightCol: $rightCol, bottomRow: $bottomRow)';
}

/// Extension on [NormalizedRect] for normalized double coordinate to integer pixel grid conversions.
extension NormalizedRectGridExtension on NormalizedRect {
  /// Converts a normalized [NormalizedRect] (coordinates 0.0 to 1.0) to integer pixel [GridBounds] for a given [gridSize].
  ///
  /// If [ensureNonEmpty] is `true`, ensures `rightCol > leftCol` and `bottomRow > topRow` (minimum 1 pixel width/height).
  GridBounds toGridBounds(int gridSize, {bool ensureNonEmpty = false}) {
    if (gridSize <= 0) {
      return const GridBounds(leftCol: 0, topRow: 0, rightCol: 0, bottomRow: 0);
    }

    int x1 = (left * gridSize).round().clamp(0, gridSize);
    int y1 = (top * gridSize).round().clamp(0, gridSize);
    int x2 = ((left + width) * gridSize).round().clamp(0, gridSize);
    int y2 = ((top + height) * gridSize).round().clamp(0, gridSize);

    if (ensureNonEmpty) {
      if (x1 >= gridSize) x1 = gridSize - 1;
      if (y1 >= gridSize) y1 = gridSize - 1;
      if (x2 <= x1) x2 = (x1 + 1).clamp(0, gridSize);
      if (y2 <= y1) y2 = (y1 + 1).clamp(0, gridSize);
    }

    return GridBounds(leftCol: x1, topRow: y1, rightCol: x2, bottomRow: y2);
  }

  /// Converts relative shape bounds (0.0 to 1.0 within parent component) to sub-grid bounds within [parentBounds].
  GridBounds toSubGridBounds(
    GridBounds parentBounds, {
    bool ensureNonEmpty = false,
  }) {
    if (parentBounds.isEmpty) {
      return GridBounds(
        leftCol: parentBounds.leftCol,
        topRow: parentBounds.topRow,
        rightCol: parentBounds.leftCol,
        bottomRow: parentBounds.topRow,
      );
    }

    final parentWidth = parentBounds.width;
    final parentHeight = parentBounds.height;

    int subLeftCol = (parentBounds.leftCol + left * parentWidth).round().clamp(
      parentBounds.leftCol,
      parentBounds.rightCol,
    );
    int subRightCol = (parentBounds.leftCol + (left + width) * parentWidth)
        .round()
        .clamp(parentBounds.leftCol, parentBounds.rightCol);
    int subTopRow = (parentBounds.topRow + top * parentHeight).round().clamp(
      parentBounds.topRow,
      parentBounds.bottomRow,
    );
    int subBottomRow = (parentBounds.topRow + (top + height) * parentHeight)
        .round()
        .clamp(parentBounds.topRow, parentBounds.bottomRow);

    if (ensureNonEmpty) {
      if (subLeftCol >= parentBounds.rightCol) {
        subLeftCol = (parentBounds.rightCol - 1).clamp(
          parentBounds.leftCol,
          parentBounds.rightCol,
        );
      }
      if (subTopRow >= parentBounds.bottomRow) {
        subTopRow = (parentBounds.bottomRow - 1).clamp(
          parentBounds.topRow,
          parentBounds.bottomRow,
        );
      }
      if (subRightCol <= subLeftCol) {
        subRightCol = (subLeftCol + 1).clamp(
          parentBounds.leftCol,
          parentBounds.rightCol,
        );
      }
      if (subBottomRow <= subTopRow) {
        subBottomRow = (subTopRow + 1).clamp(
          parentBounds.topRow,
          parentBounds.bottomRow,
        );
      }
    } else {
      if (subRightCol < subLeftCol) subRightCol = subLeftCol;
      if (subBottomRow < subTopRow) subBottomRow = subTopRow;
    }

    return GridBounds(
      leftCol: subLeftCol,
      topRow: subTopRow,
      rightCol: subRightCol,
      bottomRow: subBottomRow,
    );
  }
}

/// Domain converter helper for bounding box coordinate transformations.
abstract class CoordinateConverter {
  /// Snaps a normalized [rect] to integer grid pixels and returns a normalized [NormalizedRect].
  static NormalizedRect alignRectToGrid(NormalizedRect rect, int gridSize) {
    return rect
        .toGridBounds(gridSize, ensureNonEmpty: true)
        .toNormalizedRect(gridSize);
  }
}

// === lib/src/bounded_canvas.dart ===

/// Clamps drawing operations on a 2D pixel grid to a normalized [boundingBox].
class BoundedCanvas {
  final List<List<int>> grid;
  final NormalizedRect boundingBox;
  final int gridSize;

  late final GridBounds bounds;
  late final int minX;
  late final int maxX;
  late final int minY;
  late final int maxY;

  BoundedCanvas({
    required this.grid,
    required this.boundingBox,
    required this.gridSize,
  }) {
    bounds = boundingBox.toGridBounds(gridSize);
    minX = bounds.minX;
    maxX = bounds.maxX;
    minY = bounds.minY;
    maxY = bounds.maxY;
  }

  /// Checks if a coordinate is within the bounded area.
  bool isWithinBounds(int x, int y) => bounds.containsPixel(x, y);

  /// Sets a pixel at (x, y) if it falls within both the grid boundaries and the bounding box.
  void setPixel(int x, int y, int colorIndex) {
    if (x >= 0 &&
        x < gridSize &&
        y >= 0 &&
        y < gridSize &&
        isWithinBounds(x, y)) {
      grid[y][x] = colorIndex;
    }
  }

  /// Executes a drawing operation on a temporary grid, then copies only the pixels
  /// that lie within the bounding box back to the main grid.
  void executeClamped(void Function(List<List<int>> targetGrid) drawAction) {
    final tempGrid = grid.map((row) => List<int>.from(row)).toList();
    drawAction(tempGrid);
    for (int y = bounds.topRow; y < bounds.bottomRow; y++) {
      for (int x = bounds.leftCol; x < bounds.rightCol; x++) {
        grid[y][x] = tempGrid[y][x];
      }
    }
  }
}

// === lib/src/commands/base_command.dart ===
/// Base class representing a drawing operation that can be executed on a grid.
abstract class DrawingCommand {
  /// Executes the drawing command on the given 2D [grid] using the provided [color] value.
  void execute(List<List<int>> grid, int color, int gridSize);
}

// === lib/src/commands/line_command.dart ===

/// Command to draw a line between two points using Bresenham's line algorithm.
class LineCommand implements DrawingCommand {
  static const String usage = 'params [startX, startY, endX, endY]';

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

// === lib/src/commands/circle_command.dart ===


/// Command to draw an outlined circle supporting both integer and fractional centers.
class CircleCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, radius] (outline)';

  final num xc;
  final num yc;
  final num r;

  CircleCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

    if (r <= 0) {
      final int px = xc.round();
      final int py = yc.round();
      if (px >= 0 && px < gridSize && py >= 0 && py < gridSize) {
        grid[py][px] = color;
      }
      return;
    }

    final bool isInteger =
        xc == xc.roundToDouble() &&
        yc == yc.roundToDouble() &&
        r == r.roundToDouble();

    if (isInteger) {
      final int xcInt = xc.round();
      final int ycInt = yc.round();
      final int rInt = r.round();

      void setPixel(int px, int py) {
        if (px >= 0 && px < gridSize && py >= 0 && py < gridSize) {
          grid[py][px] = color;
        }
      }

      void drawCirclePoints(int x, int y) {
        setPixel(xcInt + x, ycInt + y);
        setPixel(xcInt - x, ycInt + y);
        setPixel(xcInt + x, ycInt - y);
        setPixel(xcInt - x, ycInt - y);
        setPixel(xcInt + y, ycInt + x);
        setPixel(xcInt - y, ycInt + x);
        setPixel(xcInt + y, ycInt - x);
        setPixel(xcInt - y, ycInt - x);
      }

      int x = 0;
      int y = rInt;
      int d = 1 - rInt;
      drawCirclePoints(x, y);

      while (x < y) {
        x++;
        if (d < 0) {
          d += 2 * x + 1;
        } else {
          y--;
          d += 2 * (x - y) + 1;
        }
        drawCirclePoints(x, y);
      }
    } else {
      // Symmetric ±0.5 band around the ideal circle radius produces an even
      // one-pixel-wide outline regardless of the fractional center position.
      final double rIn = math.max(0.0, r - 0.5);
      final double rInSq = rIn * rIn;
      final double rOut = (r + 0.5).toDouble();
      final double rOutSq = rOut * rOut;

      final int minX = (xc - r - 1).floor().clamp(0, gridSize - 1);
      final int maxX = (xc + r + 1).ceil().clamp(0, gridSize - 1);
      final int minY = (yc - r - 1).floor().clamp(0, gridSize - 1);
      final int maxY = (yc + r + 1).ceil().clamp(0, gridSize - 1);

      for (int y = minY; y <= maxY; y++) {
        final double dy = y - yc.toDouble();
        for (int x = minX; x <= maxX; x++) {
          final double dx = x - xc.toDouble();
          final double distSq = dx * dx + dy * dy;
          if (distSq >= rInSq && distSq <= rOutSq) {
            grid[y][x] = color;
          }
        }
      }
    }
  }
}

// === lib/src/commands/circle_filled_command.dart ===


/// Command to draw a filled circle supporting both integer and fractional
/// centers.
class CircleFilledCommand implements DrawingCommand {
  static const String usage = 'params [centerX, centerY, radius]';

  final num xc;
  final num yc;
  final num r;

  CircleFilledCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

    if (r <= 0) {
      final int px = xc.round();
      final int py = yc.round();
      if (px >= 0 && px < gridSize && py >= 0 && py < gridSize) {
        grid[py][px] = color;
      }
      return;
    }

    final bool isInteger =
        xc == xc.roundToDouble() &&
        yc == yc.roundToDouble() &&
        r == r.roundToDouble();

    if (isInteger) {
      final int xcInt = xc.round();
      final int ycInt = yc.round();
      final int rInt = r.round();

      void drawScanline(int y, int x1, int x2) {
        if (y < 0 || y >= gridSize) return;
        final int minX = math.max(0, math.min(x1, x2));
        final int maxX = math.min(gridSize - 1, math.max(x1, x2));
        if (minX <= maxX) {
          grid[y].fillRange(minX, maxX + 1, color);
        }
      }

      void drawCircleScanlines(int x, int y) {
        drawScanline(ycInt + y, xcInt - x, xcInt + x);
        if (y != 0) {
          drawScanline(ycInt - y, xcInt - x, xcInt + x);
        }
        if (x != y) {
          drawScanline(ycInt + x, xcInt - y, xcInt + y);
          if (x != 0) {
            drawScanline(ycInt - x, xcInt - y, xcInt + y);
          }
        }
      }

      int x = 0;
      int y = rInt;
      int d = 1 - rInt;
      drawCircleScanlines(x, y);

      while (x < y) {
        x++;
        if (d < 0) {
          d += 2 * x + 1;
        } else {
          y--;
          d += 2 * (x - y) + 1;
        }
        drawCircleScanlines(x, y);
      }
    } else {
      final double rSq = (r * r).toDouble();
      const double eps = 1e-10;
      final int minY = math.max(0, (yc - r).floor());
      final int maxY = math.min(gridSize - 1, (yc + r).ceil());

      for (int y = minY; y <= maxY; y++) {
        final double dy = y - yc.toDouble();
        final double dySq = dy * dy;
        if (dySq > rSq) continue;

        final double halfW = math.sqrt(math.max(0.0, rSq - dySq));
        final int left = (xc - halfW - eps).ceil();
        final int right = (xc + halfW + eps).floor();
        final int rowMinX = math.max(0, left);
        final int rowMaxX = math.min(gridSize - 1, right);

        if (rowMinX <= rowMaxX) {
          grid[y].fillRange(rowMinX, rowMaxX + 1, color);
        }
      }
    }
  }
}

// === lib/src/commands/circle_hatched_command.dart ===

/// Command to draw a hatched (checkerboard pattern) filled circle.
class CircleHatchedCommand implements DrawingCommand {
  static const String usage =
      'params [centerX, centerY, radius] (alternating checkerboard pattern fill)';

  final num xc;
  final num yc;
  final num r;

  CircleHatchedCommand(this.xc, this.yc, this.r);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

    if (r <= 0) {
      final int px = xc.round();
      final int py = yc.round();
      if (px >= 0 && px < gridSize && py >= 0 && py < gridSize) {
        if ((px + py) % 2 == 0) grid[py][px] = color;
      }
      return;
    }

    final double rSq = (r * r).toDouble();
    final int minX = (xc - r).floor().clamp(0, gridSize - 1);
    final int maxX = (xc + r).ceil().clamp(0, gridSize - 1);
    final int minY = (yc - r).floor().clamp(0, gridSize - 1);
    final int maxY = (yc + r).ceil().clamp(0, gridSize - 1);

    for (int y = minY; y <= maxY; y++) {
      final double dy = y - yc.toDouble();
      for (int x = minX; x <= maxX; x++) {
        final double dx = x - xc.toDouble();
        if (dx * dx + dy * dy <= rSq) {
          if ((x + y) % 2 == 0) {
            grid[y][x] = color;
          }
        }
      }
    }
  }
}

// === lib/src/commands/rectangle_command.dart ===

/// Command to draw an outlined rectangle.
class RectangleCommand implements DrawingCommand {
  static const String usage = 'params [startX, startY, endX, endY] (outline)';

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

// === lib/src/commands/rectangle_filled_command.dart ===


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

// === lib/src/commands/rectangle_hatched_command.dart ===

/// Command to draw a hatched (checkerboard pattern) filled rectangle.
class RectangleHatchedCommand implements DrawingCommand {
  static const String usage =
      'params [startX, startY, endX, endY] (alternating checkerboard pattern fill)';

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

// === lib/src/commands/fill_command.dart ===

/// Command to flood fill a region with a single color.
class FillCommand implements DrawingCommand {
  static const String usage = 'params [startX, startY]';

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

    grid[startY][startX] = color;
    final List<int> queue = [startY * gridSize + startX];

    while (queue.isNotEmpty) {
      final int pos = queue.removeLast();
      final int cx = pos % gridSize;
      final int cy = pos ~/ gridSize;

      void checkNeighbor(int nx, int ny) {
        if (grid[ny][nx] == targetColor) {
          grid[ny][nx] = color;
          queue.add(ny * gridSize + nx);
        }
      }

      if (cx > 0) checkNeighbor(cx - 1, cy);
      if (cx < gridSize - 1) checkNeighbor(cx + 1, cy);
      if (cy > 0) checkNeighbor(cx, cy - 1);
      if (cy < gridSize - 1) checkNeighbor(cx, cy + 1);
    }
  }
}

// === lib/src/commands/hatch_command.dart ===

/// Command to flood fill a region with an alternating checkerboard pattern (hatch).
class HatchCommand implements DrawingCommand {
  static const String usage =
      'params [startX, startY] (alternating checkerboard pattern flood fill)';

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

    final Uint8List visited = Uint8List(gridSize * gridSize);
    final List<int> queue = [startY * gridSize + startX];
    visited[startY * gridSize + startX] = 1;

    while (queue.isNotEmpty) {
      final int pos = queue.removeLast();
      final int cx = pos % gridSize;
      final int cy = pos ~/ gridSize;

      if (grid[cy][cx] == targetColor) {
        if ((cx + cy) % 2 == 0) {
          grid[cy][cx] = color;
        }

        void checkNeighbor(int nx, int ny) {
          final int nIdx = ny * gridSize + nx;
          if (visited[nIdx] == 0) {
            visited[nIdx] = 1;
            queue.add(nIdx);
          }
        }

        if (cx > 0) checkNeighbor(cx - 1, cy);
        if (cx < gridSize - 1) checkNeighbor(cx + 1, cy);
        if (cy > 0) checkNeighbor(cx, cy - 1);
        if (cy < gridSize - 1) checkNeighbor(cx, cy + 1);
      }
    }
  }
}

// === lib/src/commands/pixel_command.dart ===

/// Command to draw a single pixel.
class PixelCommand implements DrawingCommand {
  static const String usage = 'params [x, y]';

  final int x;
  final int y;

  PixelCommand(this.x, this.y);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
      grid[y][x] = color;
    }
  }
}

// === lib/src/commands/pixels_command.dart ===

/// Command to draw multiple individual pixels in batch.
class PixelsCommand implements DrawingCommand {
  static const String usage =
      'params [x1, y1, x2, y2, ...] (draws multiple individual pixels)';

  final List<int> coords;

  PixelsCommand(this.coords);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    for (int i = 0; i < coords.length - 1; i += 2) {
      final x = coords[i];
      final y = coords[i + 1];
      if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
        grid[y][x] = color;
      }
    }
  }
}

// === lib/src/commands/ellipse_command.dart ===


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
    final double invRx = 1.0 / rxVal;
    final double invRy = 1.0 / ryVal;

    // Threshold 0.35 allows dist up to 1.35. The maximum extent along either
    // axis is sqrt(1.35) * radius. An epsilon guard prevents float truncation.
    const double maxScale = 1.161895003862225; // math.sqrt(1.35)
    const double eps = 1e-10;
    final double maxRx = rxVal * maxScale + eps;
    final double maxRy = ryVal * maxScale + eps;

    final int minX = math.max(0, (cx - maxRx).floor());
    final int maxX = math.min(gridSize - 1, (cx + maxRx).ceil());
    final int minY = math.max(0, (cy - maxRy).floor());
    final int maxY = math.min(gridSize - 1, (cy + maxRy).ceil());

    if (minX > maxX || minY > maxY) return;

    for (int y = minY; y <= maxY; y++) {
      final double dy = (y - cy) * invRy;
      final double dySq = dy * dy;
      if (dySq > 1.35) continue;

      for (int x = minX; x <= maxX; x++) {
        final double dx = (x - cx) * invRx;
        final double dist = dx * dx + dySq;
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

// === lib/src/commands/ellipse_filled_command.dart ===


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
    if (gridSize <= 0) return;

    final double rxVal = rx < 0.5 ? 0.5 : rx.toDouble();
    final double ryVal = ry < 0.5 ? 0.5 : ry.toDouble();
    final double invRy = 1.0 / ryVal;
    const double eps = 1e-10;

    final int minY = (cy - ryVal).floor();
    final int maxY = (cy + ryVal).ceil();
    final int clampedMinY = math.max(0, minY);
    final int clampedMaxY = math.min(gridSize - 1, maxY);

    for (int y = clampedMinY; y <= clampedMaxY; y++) {
      final double normY = (y - cy) * invRy;
      final double normYSq = normY * normY;
      if (normYSq > 1.0 + eps) continue;

      final double halfW = rxVal * math.sqrt(math.max(0.0, 1.0 - normYSq));
      final int left = (cx - halfW - eps).ceil();
      final int right = (cx + halfW + eps).floor();
      final int rowMinX = math.max(0, left);
      final int rowMaxX = math.min(gridSize - 1, right);

      if (rowMinX <= rowMaxX) {
        grid[y].fillRange(rowMinX, rowMaxX + 1, color);
      }
    }
  }
}

// === lib/src/commands/triangle_command.dart ===

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

// === lib/src/commands/rotated_rectangle_command.dart ===


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

// === lib/src/commands/noise_rectangle_command.dart ===

/// Command to fill a rectangular area with noise-distributed pixels.
class NoiseRectangleCommand implements DrawingCommand {
  static const String usage =
      'params [x1, y1, x2, y2, seed] (draws a noise dithering pattern of the active color)';

  final int x1;
  final int y1;
  final int x2;
  final int y2;
  final int seed;

  NoiseRectangleCommand(this.x1, this.y1, this.x2, this.y2, this.seed);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

    final int startX = x1 < x2 ? x1 : x2;
    final int endX = x1 < x2 ? x2 : x1;
    final int startY = y1 < y2 ? y1 : y2;
    final int endY = y1 < y2 ? y2 : y1;

    if (endX < 0 || startX >= gridSize || endY < 0 || startY >= gridSize) {
      return;
    }

    final int clampedStartY = startY.clamp(0, gridSize - 1);
    final int clampedEndY = endY.clamp(0, gridSize - 1);
    final int clampedStartX = startX.clamp(0, gridSize - 1);
    final int clampedEndX = endX.clamp(0, gridSize - 1);

    for (int y = clampedStartY; y <= clampedEndY; y++) {
      for (int x = clampedStartX; x <= clampedEndX; x++) {
        final double n = hashNoise(x, y, seed);
        final int idx = (n * 2).floor() % 2;
        if (idx == 0) {
          grid[y][x] = color;
        } else {
          grid[y][x] = 0; // Transparent/Eraser
        }
      }
    }
  }
}

// === lib/src/commands/noise_circle_command.dart ===

/// Command to fill a circular area with noise-distributed pixels.
class NoiseCircleCommand implements DrawingCommand {
  static const String usage =
      'params [centerX, centerY, radius, seed] (draws a noise dithering pattern of the active color in a circle)';

  final num cx;
  final num cy;
  final num r;
  final int seed;

  NoiseCircleCommand(this.cx, this.cy, this.r, this.seed);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (gridSize <= 0) return;

    final double rSq = (r * r).toDouble();
    final int minX = (cx - r).floor().clamp(0, gridSize - 1);
    final int maxX = (cx + r).ceil().clamp(0, gridSize - 1);
    final int minY = (cy - r).floor().clamp(0, gridSize - 1);
    final int maxY = (cy + r).ceil().clamp(0, gridSize - 1);

    for (int y = minY; y <= maxY; y++) {
      final double dy = y - cy.toDouble();
      for (int x = minX; x <= maxX; x++) {
        final double dx = x - cx.toDouble();
        if (dx * dx + dy * dy <= rSq) {
          final double n = hashNoise(x, y, seed);
          final int idx = (n * 2).floor() % 2;
          if (idx == 0) {
            grid[y][x] = color;
          } else {
            grid[y][x] = 0;
          }
        }
      }
    }
  }
}

// === lib/src/commands/voronoi_command.dart ===


/// Command to draw a Voronoi cellular texture.
class VoronoiCommand implements DrawingCommand {
  static const String usage =
      'params [x1, y1, x2, y2, num_cells, seed] (draws a Voronoi cellular texture of the active color)';

  final int x1;
  final int y1;
  final int x2;
  final int y2;
  final int numCells;
  final int seed;

  VoronoiCommand(this.x1, this.y1, this.x2, this.y2, this.numCells, this.seed);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    if (numCells <= 0 || gridSize <= 0) return;

    final int startX = x1 < x2 ? x1 : x2;
    final int endX = x1 < x2 ? x2 : x1;
    final int startY = y1 < y2 ? y1 : y2;
    final int endY = y1 < y2 ? y2 : y1;

    if (endX < 0 || startX >= gridSize || endY < 0 || startY >= gridSize) {
      return;
    }

    final int w = endX - startX + 1;
    final int h = endY - startY + 1;
    if (w <= 0 || h <= 0) return;

    final pointsX = Int32List(numCells);
    final pointsY = Int32List(numCells);
    final pointsColor = Int32List(numCells);

    for (int i = 0; i < numCells; i++) {
      pointsX[i] = startX + (hashNoise(i, 0, seed) * w).floor();
      pointsY[i] = startY + (hashNoise(0, i, seed + 99) * h).floor();
      pointsColor[i] = i % 2 == 0 ? color : 0;
    }

    final int clampedStartY = startY.clamp(0, gridSize - 1);
    final int clampedEndY = endY.clamp(0, gridSize - 1);
    final int clampedStartX = startX.clamp(0, gridSize - 1);
    final int clampedEndX = endX.clamp(0, gridSize - 1);

    for (int y = clampedStartY; y <= clampedEndY; y++) {
      for (int x = clampedStartX; x <= clampedEndX; x++) {
        int bestDist = 0x7FFFFFFF;
        int bestColor = color;
        for (int i = 0; i < numCells; i++) {
          final int dx = x - pointsX[i];
          final int dy = y - pointsY[i];
          final int dist = dx * dx + dy * dy;
          if (dist < bestDist) {
            bestDist = dist;
            bestColor = pointsColor[i];
          }
        }
        grid[y][x] = bestColor;
      }
    }
  }
}

// === lib/src/commands/polygon_command.dart ===


/// Command to draw a filled arbitrary polygon from vertex coordinates
/// `[x1, y1, x2, y2, x3, y3, ...]`.
class PolygonCommand implements DrawingCommand {
  static const String usage =
      'params [x1, y1, x2, y2, x3, y3, ...] (filled polygon, 3+ vertices)';

  final List<(int, int)> vertices;

  PolygonCommand(this.vertices);

  factory PolygonCommand.fromFlatParams(List<num> params) {
    final pts = <(int, int)>[];
    for (int i = 0; i + 1 < params.length; i += 2) {
      pts.add((params[i].round(), params[i + 1].round()));
    }
    return PolygonCommand(pts);
  }

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    final n = vertices.length;
    if (n < 3 || gridSize <= 0) return;

    int minY = vertices[0].$2;
    int maxY = vertices[0].$2;
    for (final (_, y) in vertices) {
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    final startY = math.max(0, minY);
    final endY = math.min(gridSize - 1, maxY);

    // Scanline fill using pixel center sampling (y + 0.5)
    for (int y = startY; y <= endY; y++) {
      final double sy = y + 0.5;
      final intersections = <double>[];

      for (int i = 0; i < n; i++) {
        final (x1, y1) = vertices[i];
        final (x2, y2) = vertices[(i + 1) % n];
        if (y1 == y2) continue;
        final double dy1 = y1.toDouble();
        final double dy2 = y2.toDouble();
        if ((dy1 <= sy && dy2 > sy) || (dy2 <= sy && dy1 > sy)) {
          final double t = (sy - dy1) / (dy2 - dy1);
          intersections.add(x1 + t * (x2 - x1));
        }
      }

      intersections.sort();
      for (int i = 0; i + 1 < intersections.length; i += 2) {
        final xStart = math.max(0, intersections[i].floor());
        final xEnd = math.min(gridSize - 1, intersections[i + 1].ceil());
        if (xStart <= xEnd) {
          grid[y].fillRange(xStart, xEnd + 1, color);
        }
      }
    }

    // Trace edges with Bresenham lines so crisp tips/vertices are preserved.
    for (int i = 0; i < n; i++) {
      final (x1, y1) = vertices[i];
      final (x2, y2) = vertices[(i + 1) % n];
      LineCommand(x1, y1, x2, y2).execute(grid, color, gridSize);
    }
  }
}

// === lib/src/commands/mirror_command.dart ===

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

// === lib/src/commands/replace_color_command.dart ===

/// Replaces all occurrences of [fromColor] in the grid with the command's target `color`.
class ReplaceColorCommand implements DrawingCommand {
  static const String usage =
      'params [fromColorIndex] (replaces all pixels of fromColorIndex with color)';

  final int fromColor;

  ReplaceColorCommand(this.fromColor);

  @override
  void execute(List<List<int>> grid, int color, int gridSize) {
    for (int y = 0; y < grid.length && y < gridSize; y++) {
      final row = grid[y];
      for (int x = 0; x < row.length && x < gridSize; x++) {
        if (row[x] == fromColor) {
          row[x] = color;
        }
      }
    }
  }
}

// === lib/src/commands/outline_command.dart ===

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

// === lib/src/commands/drawing_command_factory.dart ===

typedef CommandCreator = DrawingCommand? Function(List<num> params);

/// Factory class to instantiate DrawingCommands from tool configurations.
class DrawingCommandFactory {
  static final Map<String, CommandCreator> _registry = {
    'line': (p) => p.length >= 4
        ? LineCommand(p[0].round(), p[1].round(), p[2].round(), p[3].round())
        : null,
    'circle': (p) => p.length >= 3 ? CircleCommand(p[0], p[1], p[2]) : null,
    'circle_filled': (p) =>
        p.length >= 3 ? CircleFilledCommand(p[0], p[1], p[2]) : null,
    'circle_hatched': (p) =>
        p.length >= 3 ? CircleHatchedCommand(p[0], p[1], p[2]) : null,
    'rectangle': (p) => p.length >= 4
        ? RectangleCommand(
            p[0].round(),
            p[1].round(),
            p[2].round(),
            p[3].round(),
          )
        : null,
    'rectangle_filled': (p) => p.length >= 4
        ? RectangleFilledCommand(
            p[0].round(),
            p[1].round(),
            p[2].round(),
            p[3].round(),
          )
        : null,
    'rectangle_hatched': (p) => p.length >= 4
        ? RectangleHatchedCommand(
            p[0].round(),
            p[1].round(),
            p[2].round(),
            p[3].round(),
          )
        : null,
    'fill': (p) =>
        p.length >= 2 ? FillCommand(p[0].round(), p[1].round()) : null,
    'hatch': (p) =>
        p.length >= 2 ? HatchCommand(p[0].round(), p[1].round()) : null,
    'pixel': (p) =>
        p.length >= 2 ? PixelCommand(p[0].round(), p[1].round()) : null,
    'pixels': (p) => PixelsCommand(p.map((e) => e.round()).toList()),
    'ellipse': (p) =>
        p.length >= 4 ? EllipseCommand(p[0], p[1], p[2], p[3]) : null,
    'ellipse_filled': (p) =>
        p.length >= 4 ? EllipseFilledCommand(p[0], p[1], p[2], p[3]) : null,
    'triangle': (p) => p.length >= 6
        ? TriangleCommand(
            p[0].round(),
            p[1].round(),
            p[2].round(),
            p[3].round(),
            p[4].round(),
            p[5].round(),
          )
        : null,
    'rotated_rectangle': (p) => p.length >= 5
        ? RotatedRectangleCommand(
            p[0].round(),
            p[1].round(),
            p[2].round(),
            p[3].round(),
            p[4].toDouble(),
          )
        : null,
    'noise_rectangle': (p) => p.length >= 5
        ? NoiseRectangleCommand(
            p[0].round(),
            p[1].round(),
            p[2].round(),
            p[3].round(),
            p[4].round(),
          )
        : null,
    'noise_circle': (p) => p.length >= 4
        ? NoiseCircleCommand(p[0], p[1], p[2], p[3].round())
        : null,
    'voronoi': (p) => p.length >= 6
        ? VoronoiCommand(
            p[0].round(),
            p[1].round(),
            p[2].round(),
            p[3].round(),
            p[4].round(),
            p[5].round(),
          )
        : null,
    'polygon': (p) => p.length >= 6 ? PolygonCommand.fromFlatParams(p) : null,
    'mirror_h': (p) =>
        MirrorHorizontalCommand(fromRight: p.isNotEmpty && p[0].round() != 0),
    'mirror_v': (p) =>
        MirrorVerticalCommand(fromBottom: p.isNotEmpty && p[0].round() != 0),
    'replace_color': (p) =>
        p.isNotEmpty ? ReplaceColorCommand(p[0].round()) : null,
    'auto_outline': (p) =>
        OutlineCommand(eightConnected: p.isNotEmpty && p[0].round() == 8),
  };

  /// Map of tool names to their respective instructions (arguments description).
  static final Map<String, String> toolInstructions = {
    'line': LineCommand.usage,
    'circle': CircleCommand.usage,
    'circle_filled': CircleFilledCommand.usage,
    'circle_hatched': CircleHatchedCommand.usage,
    'rectangle': RectangleCommand.usage,
    'rectangle_filled': RectangleFilledCommand.usage,
    'rectangle_hatched': RectangleHatchedCommand.usage,
    'fill': FillCommand.usage,
    'hatch': HatchCommand.usage,
    'pixel': PixelCommand.usage,
    'pixels': PixelsCommand.usage,
    'ellipse': EllipseCommand.usage,
    'ellipse_filled': EllipseFilledCommand.usage,
    'triangle': TriangleCommand.usage,
    'rotated_rectangle': RotatedRectangleCommand.usage,
    'noise_rectangle': NoiseRectangleCommand.usage,
    'noise_circle': NoiseCircleCommand.usage,
    'voronoi': VoronoiCommand.usage,
    'polygon': PolygonCommand.usage,
    'mirror_h': MirrorHorizontalCommand.usage,
    'mirror_v': MirrorVerticalCommand.usage,
    'replace_color': ReplaceColorCommand.usage,
    'auto_outline': OutlineCommand.usage,
    'undo':
        'params [] (reverts the last AI or user action if the AI thinks the last stroke was a mistake)',
  };

  /// Allows dynamic registration of custom commands/tools.
  static void register(String toolName, CommandCreator creator, String usage) {
    _registry[toolName] = creator;
    toolInstructions[toolName] = usage;
  }

  /// Returns the matching [DrawingCommand] instance based on the [toolName] and [params].
  /// Returns `null` if the tool configurations are invalid or unsupported.
  static DrawingCommand? create(String toolName, List<num> params) {
    final creator = _registry[toolName];
    if (creator != null) {
      return creator(params);
    }
    return null;
  }
}

// === lib/src/palettes.dart ===

class PixelArtPalette {
  final String id;
  final String displayName;
  final List<PixelColor> colors;

  const PixelArtPalette({
    required this.id,
    required this.displayName,
    required this.colors,
  });
}

class PaletteRegistry {
  static const List<PixelColor> grayscalePalette = [
    PixelColor(0xFF000000), // Black
    PixelColor(0xFF555555), // Dark Gray
    PixelColor(0xFFAAAAAA), // Light Gray
    PixelColor(0xFFFFFFFF), // White
  ];

  static const List<PixelColor> primaryPalette = [
    PixelColor(0xFF000000), // Black
    PixelColor(0xFFFFFFFF), // White
    PixelColor(0xFFFF0000), // Red
    PixelColor(0xFF00FF00), // Green
    PixelColor(0xFF0000FF), // Blue
    PixelColor(0xFFFFFF00), // Yellow
    PixelColor(0xFFFF00FF), // Magenta
    PixelColor(0xFF00FFFF), // Cyan
  ];

  static const List<PixelColor> gameboyPalette = [
    PixelColor(0xFF0F380F),
    PixelColor(0xFF306230),
    PixelColor(0xFF8BAC0F),
    PixelColor(0xFF9BBC0F),
  ];

  static const List<PixelColor> nesPalette = [
    PixelColor(0xFF000000), // Black
    PixelColor(0xFFFCBCB0), // Peach/Skin
    PixelColor(0xFFF06800), // Red/Orange
    PixelColor(0xFFF8B800), // Yellow
    PixelColor(0xFF00A800), // Green
    PixelColor(0xFF0058F8), // Blue
    PixelColor(0xFFD800CC), // Purple
    PixelColor(0xFFFFFFFF), // White
  ];

  static const List<PixelColor> pico8Palette = [
    PixelColor(0xFF000000),
    PixelColor(0xFF1D2B53),
    PixelColor(0xFF7E2553),
    PixelColor(0xFF008751),
    PixelColor(0xFFAB5236),
    PixelColor(0xFF5F574F),
    PixelColor(0xFFC2C3C7),
    PixelColor(0xFFFFF1E8),
    PixelColor(0xFFFF004D),
    PixelColor(0xFFFFA300),
    PixelColor(0xFFFFEC27),
    PixelColor(0xFF00E436),
    PixelColor(0xFF29ADFF),
    PixelColor(0xFF83769C),
    PixelColor(0xFFFF77A8),
    PixelColor(0xFFFFCCAA),
  ];

  /// Sweetie 16 — a classic hue-shifted 16-color pixel art palette.
  static const List<PixelColor> sweetie16Palette = [
    PixelColor(0xFF1A1C2C), // 1: Deep Ink
    PixelColor(0xFF5D275D), // 2: Dark Purple
    PixelColor(0xFFB13E53), // 3: Crimson
    PixelColor(0xFFEF7D57), // 4: Orange
    PixelColor(0xFFFFCD75), // 5: Warm Yellow
    PixelColor(0xFFA7F070), // 6: Lime
    PixelColor(0xFF38B764), // 7: Green
    PixelColor(0xFF257179), // 8: Dark Teal
    PixelColor(0xFF29366F), // 9: Deep Blue
    PixelColor(0xFF3B5DC9), // 10: Royal Blue
    PixelColor(0xFF41A6F6), // 11: Sky Blue
    PixelColor(0xFF73EFF7), // 12: Cyan Highlight
    PixelColor(0xFFF4F4F4), // 13: Off-White
    PixelColor(0xFF94B0C2), // 14: Light Cool Gray
    PixelColor(0xFF566C86), // 15: Mid Slate
    PixelColor(0xFF333C57), // 16: Dark Slate
  ];

  static const List<PixelArtPalette> presets = [
    PixelArtPalette(
      id: 'grayscale',
      displayName: 'Grayscale',
      colors: grayscalePalette,
    ),
    PixelArtPalette(
      id: 'primary',
      displayName: 'Primary Colors',
      colors: primaryPalette,
    ),
    PixelArtPalette(
      id: 'gameboy',
      displayName: 'Gameboy',
      colors: gameboyPalette,
    ),
    PixelArtPalette(id: 'nes', displayName: 'NES', colors: nesPalette),
    PixelArtPalette(id: 'pico8', displayName: 'PICO-8', colors: pico8Palette),
    PixelArtPalette(
      id: 'sweetie16',
      displayName: 'Sweetie 16',
      colors: sweetie16Palette,
    ),
  ];

  static PixelArtPalette? findById(String id) {
    final normalized = id.trim().toLowerCase();
    for (final p in presets) {
      if (p.id == normalized) return p;
    }
    return null;
  }

  static PixelArtPalette getById(String id) {
    return findById(id) ?? presets[1]; // primary as default
  }
}

// === lib/src/k_means_quantizer.dart ===


class _RgbPoint {
  final int r;
  final int g;
  final int b;
  final int weight;

  const _RgbPoint({
    required this.r,
    required this.g,
    required this.b,
    required this.weight,
  });
}

/// Extracted weighted K-Means color quantization algorithm.
List<PixelColor> kMeansQuantize(List<List<PixelColor>> colorGrid, int k) {
  if (k <= 0 || colorGrid.isEmpty) {
    return const [];
  }

  // 1. Gather all pixel colors and count their frequency
  final Map<int, int> colorCounts = {};
  for (final row in colorGrid) {
    for (final color in row) {
      final argb = color.toARGB32();
      colorCounts[argb] = (colorCounts[argb] ?? 0) + 1;
    }
  }

  final List<int> uniqueColors = colorCounts.keys.toList();
  if (uniqueColors.length <= k) {
    final list = uniqueColors.map((argb) => PixelColor(argb)).toList();
    while (list.length < k) {
      list.add(list.length % 2 == 0 ? PixelColor.black : PixelColor.white);
    }
    return list;
  }

  // Pre-extract integer RGB channels and weights using bitwise operations
  final List<_RgbPoint> points = [];
  for (final argb in uniqueColors) {
    points.add(
      _RgbPoint(
        r: (argb >> 16) & 0xFF,
        g: (argb >> 8) & 0xFF,
        b: argb & 0xFF,
        weight: colorCounts[argb]!,
      ),
    );
  }

  // 2. Select initial centroids spread across the unique colors
  final List<int> centroidR = List<int>.filled(k, 0);
  final List<int> centroidG = List<int>.filled(k, 0);
  final List<int> centroidB = List<int>.filled(k, 0);

  final step = points.length ~/ k;
  for (int i = 0; i < k; i++) {
    final pt = points[(i * step).clamp(0, points.length - 1)];
    centroidR[i] = pt.r;
    centroidG[i] = pt.g;
    centroidB[i] = pt.b;
  }

  // 3. Iteratively refine centroids
  for (int iteration = 0; iteration < 5; iteration++) {
    final Int64List sumR = Int64List(k);
    final Int64List sumG = Int64List(k);
    final Int64List sumB = Int64List(k);
    final Int32List totalWeight = Int32List(k);

    // Assign each unique color to the closest centroid
    for (final pt in points) {
      int minDistance = 0x7FFFFFFF;
      int bestCentroidIndex = 0;
      final pr = pt.r;
      final pg = pt.g;
      final pb = pt.b;

      for (int c = 0; c < k; c++) {
        final dr = pr - centroidR[c];
        final dg = pg - centroidG[c];
        final db = pb - centroidB[c];
        final dist = dr * dr + dg * dg + db * db;
        if (dist < minDistance) {
          minDistance = dist;
          bestCentroidIndex = c;
        }
      }

      final w = pt.weight;
      sumR[bestCentroidIndex] += pr * w;
      sumG[bestCentroidIndex] += pg * w;
      sumB[bestCentroidIndex] += pb * w;
      totalWeight[bestCentroidIndex] += w;
    }

    // Recompute centroids as weighted averages
    for (int c = 0; c < k; c++) {
      final tw = totalWeight[c];
      if (tw > 0) {
        centroidR[c] = (sumR[c] / tw).round().clamp(0, 255);
        centroidG[c] = (sumG[c] / tw).round().clamp(0, 255);
        centroidB[c] = (sumB[c] / tw).round().clamp(0, 255);
      }
    }
  }

  return List<PixelColor>.generate(
    k,
    (c) => PixelColor.fromARGB(255, centroidR[c], centroidG[c], centroidB[c]),
  );
}

// === lib/src/component.dart ===


class FundamentalShape {
  final String type; // 'rectangle', 'circle', 'triangle'
  final NormalizedRect relativeBoundingBox;
  final String description;

  const FundamentalShape({
    required this.type,
    required this.relativeBoundingBox,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'relativeBoundingBox': relativeBoundingBox.toJson(),
      'description': description,
    };
  }

  factory FundamentalShape.fromJson(Map<String, dynamic> json) {
    final bbox = json['relativeBoundingBox'] as Map<String, dynamic>;
    return FundamentalShape(
      type: json['type'] as String,
      description: json['description'] as String,
      relativeBoundingBox: NormalizedRect.fromJson(bbox),
    );
  }

  GridBounds subGridBounds(
    GridBounds parentBounds, {
    bool ensureNonEmpty = false,
  }) {
    return relativeBoundingBox.toSubGridBounds(
      parentBounds,
      ensureNonEmpty: ensureNonEmpty,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FundamentalShape) return false;
    return type == other.type &&
        relativeBoundingBox == other.relativeBoundingBox &&
        description == other.description;
  }

  @override
  int get hashCode => Object.hash(type, relativeBoundingBox, description);
}

class PixelArtComponent {
  final String name;
  final String description;
  final NormalizedRect relativeBoundingBox;
  final List<List<int>>? grid;
  final List<FundamentalShape> shapes;
  final PixelColor? fillColor;
  final PixelColor? fillColor2;
  final double gradientAngle;
  final PixelColor? outlineColor;
  final bool isSculpted;
  final bool hasInterior;
  final double minP;
  final double maxP;
  final List<List<int>>? outlineGrid;
  final double cosA;
  final double sinA;

  factory PixelArtComponent({
    required String name,
    required String description,
    required NormalizedRect relativeBoundingBox,
    List<List<int>>? grid,
    List<FundamentalShape> shapes = const [],
    PixelColor? fillColor,
    PixelColor? fillColor2,
    double gradientAngle = 90.0,
    PixelColor? outlineColor,
    bool isSculpted = false,
    bool? hasInterior,
    double? minP,
    double? maxP,
    List<List<int>>? outlineGrid,
    double? cosA,
    double? sinA,
  }) {
    final double rad = gradientAngle * (math.pi / 180.0);
    final double computedCosA = cosA ?? math.cos(rad);
    final double computedSinA = sinA ?? math.sin(rad);
    final (
      double computedMinP,
      double computedMaxP,
    ) = (minP != null && maxP != null)
        ? (minP, maxP)
        : _calculateProjectionRange(
            grid,
            computedCosA,
            computedSinA,
            explicitMinP: minP,
            explicitMaxP: maxP,
          );

    return PixelArtComponent._(
      name: name,
      description: description,
      relativeBoundingBox: relativeBoundingBox,
      grid: grid,
      shapes: shapes,
      fillColor: fillColor,
      fillColor2: fillColor2,
      gradientAngle: gradientAngle,
      outlineColor: outlineColor,
      isSculpted: isSculpted,
      hasInterior: hasInterior ?? _calculateHasInterior(grid),
      minP: computedMinP,
      maxP: computedMaxP,
      outlineGrid: outlineGrid ?? _calculateOutlineGrid(grid),
      cosA: computedCosA,
      sinA: computedSinA,
    );
  }

  const PixelArtComponent._({
    required this.name,
    required this.description,
    required this.relativeBoundingBox,
    this.grid,
    this.shapes = const [],
    this.fillColor,
    this.fillColor2,
    this.gradientAngle = 90.0,
    this.outlineColor,
    this.isSculpted = false,
    required this.hasInterior,
    required this.minP,
    required this.maxP,
    this.outlineGrid,
    required this.cosA,
    required this.sinA,
  });

  GridBounds gridBounds(int gridSize, {bool ensureNonEmpty = false}) {
    return relativeBoundingBox.toGridBounds(
      gridSize,
      ensureNonEmpty: ensureNonEmpty,
    );
  }

  static bool _calculateHasInterior(List<List<int>>? grid) {
    if (grid == null || grid.isEmpty) return false;
    final height = grid.length;
    for (int y = 0; y < height; y++) {
      final row = grid[y];
      final width = row.length;
      for (int x = 0; x < width; x++) {
        if (row[x] > 0) {
          if (y > 0 && y < height - 1 && x > 0 && x < width - 1) {
            if (grid[y - 1].length > x &&
                grid[y + 1].length > x &&
                grid[y - 1][x] > 0 &&
                grid[y + 1][x] > 0 &&
                row[x - 1] > 0 &&
                row[x + 1] > 0) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  static (double, double) _calculateProjectionRange(
    List<List<int>>? grid,
    double cosA,
    double sinA, {
    double? explicitMinP,
    double? explicitMaxP,
  }) {
    if (grid == null) {
      return (explicitMinP ?? 0.0, explicitMaxP ?? 0.0);
    }
    final size = grid.length;
    double minP = explicitMinP ?? double.infinity;
    double maxP = explicitMaxP ?? -double.infinity;

    for (int py = 0; py < size; py++) {
      final row = grid[py];
      final double pySin = py * sinA;
      final int rowLen = row.length;
      for (int px = 0; px < rowLen; px++) {
        if (row[px] > 0) {
          final double p = px * cosA + pySin;
          if (explicitMinP == null && p < minP) minP = p;
          if (explicitMaxP == null && p > maxP) maxP = p;
        }
      }
    }
    return (
      minP == double.infinity ? (explicitMinP ?? 0.0) : minP,
      maxP == -double.infinity ? (explicitMaxP ?? 0.0) : maxP,
    );
  }

  static const List<List<double>> bayerMatrix4x4 = [
    [0.0 / 16, 8.0 / 16, 2.0 / 16, 10.0 / 16],
    [12.0 / 16, 4.0 / 16, 14.0 / 16, 6.0 / 16],
    [3.0 / 16, 11.0 / 16, 1.0 / 16, 9.0 / 16],
    [15.0 / 16, 7.0 / 16, 13.0 / 16, 5.0 / 16],
  ];

  /// Computes the fill color at `(x, y)` with optional 4x4 Bayer ordered dithering.
  PixelColor? getPixelFillColor(int x, int y) {
    if (grid == null || y < 0 || y >= grid!.length) return null;
    if (x < 0 || x >= grid![y].length || grid![y][x] == 0) return null;
    if (fillColor == null) return null;
    if (fillColor2 == null || !hasInterior) return fillColor;
    if (maxP <= minP) return fillColor;

    final currentP = x * cosA + y * sinA;
    final t = ((currentP - minP) / (maxP - minP)).clamp(0.0, 1.0);
    final ditherThreshold = bayerMatrix4x4[y % 4][x % 4];

    return t > ditherThreshold ? fillColor2 : fillColor;
  }

  /// Computes a smooth (non-dithered) linear band choice or Bayer-dithered choice
  /// between [fillColor] and [fillColor2] at `(x, y)` for arbitrary [dither] mode.
  PixelColor? getPixelFillColorWithMode(int x, int y, {bool dither = true}) {
    if (dither) return getPixelFillColor(x, y);
    if (grid == null || y < 0 || y >= grid!.length) return null;
    if (x < 0 || x >= grid![y].length || grid![y][x] == 0) return null;
    if (fillColor == null) return null;
    if (fillColor2 == null || !hasInterior) return fillColor;
    if (maxP <= minP) return fillColor;

    final currentP = x * cosA + y * sinA;
    final t = ((currentP - minP) / (maxP - minP)).clamp(0.0, 1.0);
    return t >= 0.5 ? fillColor2 : fillColor;
  }

  PixelArtComponent initializeDefaultGrid(int gridSize) {
    if (grid != null) return this;
    final List<List<int>> newGrid = List.generate(
      gridSize,
      (_) => List.filled(gridSize, 0),
    );
    final bounds = gridBounds(gridSize);

    for (int y = bounds.topRow; y < bounds.bottomRow; y++) {
      for (int x = bounds.leftCol; x < bounds.rightCol; x++) {
        newGrid[y][x] = 1;
      }
    }
    return copyWith(grid: newGrid);
  }

  static List<List<int>>? _calculateOutlineGrid(List<List<int>>? grid) {
    if (grid == null) return null;
    final height = grid.length;
    if (height == 0) return [];
    final outline = List.generate(
      height,
      (y) => List.filled(grid[y].length, 0),
    );
    for (int y = 0; y < height; y++) {
      final row = grid[y];
      final width = row.length;
      for (int x = 0; x < width; x++) {
        if (row[x] > 0) {
          bool hasBackgroundNeighbor = false;
          if (y == 0 || y == height - 1 || x == 0 || x == width - 1) {
            hasBackgroundNeighbor = true;
          } else {
            if (grid[y - 1].length <= x ||
                grid[y - 1][x] == 0 ||
                grid[y + 1].length <= x ||
                grid[y + 1][x] == 0 ||
                row[x - 1] == 0 ||
                row[x + 1] == 0) {
              hasBackgroundNeighbor = true;
            }
          }
          if (hasBackgroundNeighbor) {
            outline[y][x] = 1;
          }
        }
      }
    }
    return outline;
  }

  List<List<int>>? getOutlineGrid() => outlineGrid;

  PixelArtComponent copyWith({
    String? name,
    String? description,
    NormalizedRect? relativeBoundingBox,
    List<List<int>>? grid,
    bool clearGrid = false,
    List<FundamentalShape>? shapes,
    PixelColor? Function()? fillColor,
    PixelColor? Function()? fillColor2,
    double? gradientAngle,
    PixelColor? Function()? outlineColor,
    bool? isSculpted,
  }) {
    final newGrid = clearGrid ? null : (grid ?? this.grid);
    final newGradientAngle = gradientAngle ?? this.gradientAngle;
    final gridChanged = clearGrid || (grid != null && grid != this.grid);
    final angleChanged =
        gradientAngle != null && gradientAngle != this.gradientAngle;

    return PixelArtComponent(
      name: name ?? this.name,
      description: description ?? this.description,
      relativeBoundingBox: relativeBoundingBox ?? this.relativeBoundingBox,
      grid: newGrid,
      shapes: shapes ?? this.shapes,
      fillColor: fillColor != null ? fillColor() : this.fillColor,
      fillColor2: fillColor2 != null ? fillColor2() : this.fillColor2,
      gradientAngle: newGradientAngle,
      outlineColor: outlineColor != null ? outlineColor() : this.outlineColor,
      isSculpted: isSculpted ?? this.isSculpted,
      hasInterior: gridChanged ? null : hasInterior,
      minP: (gridChanged || angleChanged) ? null : minP,
      maxP: (gridChanged || angleChanged) ? null : maxP,
      outlineGrid: gridChanged ? null : outlineGrid,
      cosA: angleChanged ? null : cosA,
      sinA: angleChanged ? null : sinA,
    );
  }
}

// === lib/src/sprite_template.dart ===
/// Represents a pixel art template with ASCII / numeric grid definitions.
class SpriteTemplate {
  final String id;
  final String name;
  final String description;
  final int width;
  final int height;
  final String rawTemplate;
  final String defaultPrompt;
  final Map<String, int>? symbolMapping;

  const SpriteTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.rawTemplate,
    this.defaultPrompt = '',
    this.symbolMapping,
  });

  /// Parses [rows] or [rawTemplate] into a 2D integer grid of size [height] x [width].
  ///
  /// '.' and '0' and whitespace denote empty / transparent pixels (value 0).
  /// Characters '1'..'9' map directly to palette color indices 1..9.
  /// Letters 'A'..'Z' map to color indices 10..35.
  /// Symbols like '#', 'o', 'X' map via [customMapping] or [symbolMapping].
  static List<List<int>> parseRows(
    List<String> lines,
    int width,
    int height, {
    Map<String, int>? symbolMapping,
  }) {
    final mapping =
        symbolMapping ?? const {'#': 1, 'o': 2, 'O': 2, 'x': 3, 'X': 3};

    return List.generate(height, (y) {
      return List.generate(width, (x) {
        if (y >= lines.length || x >= lines[y].length) return 0;
        final char = lines[y][x];
        if (char == '.' || char == ' ' || char == '0') return 0;

        if (mapping.containsKey(char)) {
          return mapping[char]!;
        }

        final digit = int.tryParse(char);
        if (digit != null) {
          return digit;
        }

        final code = char.toUpperCase().codeUnitAt(0);
        if (code >= 65 && code <= 90) {
          return code - 65 + 10;
        }

        return 1;
      });
    });
  }

  List<List<int>> parseToGrid([Map<String, int>? customMapping]) {
    final lines = rawTemplate
        .replaceAll('\r', '')
        .split('\n')
        .where((l) => l.isNotEmpty)
        .toList();
    return parseRows(
      lines,
      width,
      height,
      symbolMapping: customMapping ?? symbolMapping,
    );
  }

  static const characterPreset = SpriteTemplate(
    id: 'sprite_character',
    name: 'Sprite Character',
    description:
        '16x16 humanoid character sprite with outline, body fill, and eyes',
    width: 16,
    height: 16,
    defaultPrompt: 'pixel art 16x16 character sprite hero, detailed shading',
    symbolMapping: {'#': 1, 'o': 2, 'X': 3, '.': 0},
    rawTemplate: '''
....111111......
...122222221....
..12222222221...
.1222222222221..
.1222222222221..
.1223222223221..
.1223222223221..
.1222222222221..
..12222222221...
...112222211....
...122222221....
..12122222121...
..12122222121...
...112222211....
....1221221.....
....111.111.....
''',
  );

  static const List<SpriteTemplate> presets = [characterPreset];

  static SpriteTemplate? getById(String id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }
}

// === lib/src/png_encoder.dart ===


/// Pure-Dart RGBA PNG encoder using `dart:io`'s built-in [ZLibEncoder].
class PngEncoder {
  static final Uint32List _crcTable = _buildCrcTable();

  static Uint32List _buildCrcTable() {
    final table = Uint32List(256);
    for (int n = 0; n < 256; n++) {
      int c = n;
      for (int k = 0; k < 8; k++) {
        if ((c & 1) != 0) {
          c = 0xEDB88320 ^ (c >>> 1);
        } else {
          c = c >>> 1;
        }
      }
      table[n] = c;
    }
    return table;
  }

  static int _crc32(List<int> bytes) {
    int c = 0xFFFFFFFF;
    for (int i = 0; i < bytes.length; i++) {
      c = _crcTable[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8);
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static Uint8List _chunk(String type, List<int> data) {
    assert(type.length == 4);
    final typeBytes = type.codeUnits;
    final out = Uint8List(12 + data.length);
    final bd = ByteData.sublistView(out);
    bd.setUint32(0, data.length, Endian.big);
    for (int i = 0; i < 4; i++) {
      out[4 + i] = typeBytes[i];
    }
    out.setRange(8, 8 + data.length, data);
    final crcInput = Uint8List.sublistView(out, 4, 8 + data.length);
    bd.setUint32(8 + data.length, _crc32(crcInput), Endian.big);
    return out;
  }

  /// Encodes a flat RGBA byte buffer ([rgba], length `width * height * 4`)
  /// into a valid lossless 8-bit RGBA PNG byte array.
  static Uint8List encodeRgba(int width, int height, Uint8List rgba) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('PNG dimensions must be positive: ${width}x$height');
    }
    if (rgba.length != width * height * 4) {
      throw ArgumentError(
        'RGBA buffer length (${rgba.length}) does not match '
        '${width}x$height*4 (${width * height * 4})',
      );
    }

    // PNG signature
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];

    // IHDR chunk: width, height, bit depth 8, color type 6 (RGBA),
    // compression 0, filter 0, interlace 0
    final ihdrData = Uint8List(13);
    final ihdrBd = ByteData.sublistView(ihdrData);
    ihdrBd.setUint32(0, width, Endian.big);
    ihdrBd.setUint32(4, height, Endian.big);
    ihdrData[8] = 8; // bit depth
    ihdrData[9] = 6; // RGBA
    ihdrData[10] = 0; // deflate
    ihdrData[11] = 0; // adaptive filter
    ihdrData[12] = 0; // no interlace

    // Prepare raw scanlines with filter byte 0 (None) before each row
    final rowBytes = width * 4;
    final raw = Uint8List(height * (1 + rowBytes));
    for (int y = 0; y < height; y++) {
      final dstOffset = y * (1 + rowBytes);
      raw[dstOffset] = 0; // filter type 0
      final srcOffset = y * rowBytes;
      raw.setRange(dstOffset + 1, dstOffset + 1 + rowBytes, rgba, srcOffset);
    }

    final compressed = zlib.encode(raw);

    final ihdr = _chunk('IHDR', ihdrData);
    final idat = _chunk('IDAT', compressed);
    final iend = _chunk('IEND', const []);

    final builder = BytesBuilder(copy: false)
      ..add(signature)
      ..add(ihdr)
      ..add(idat)
      ..add(iend);
    return builder.toBytes();
  }

  /// Encodes a palette-indexed pixel art [grid] and [palette] into a crisp
  /// nearest-neighbor scaled RGBA PNG.
  static Uint8List encodeGrid(
    List<List<int>> grid,
    List<PixelColor> palette, {
    int scale = 1,
    bool transparentBackground = true,
    PixelColor backgroundColor = const PixelColor(0xFF1E1E1E),
  }) {
    final int height = grid.length;
    final int width = height > 0 ? grid[0].length : 0;
    if (width <= 0 || height <= 0 || scale <= 0) {
      return Uint8List(0);
    }

    final int outWidth = width * scale;
    final int outHeight = height * scale;
    final rgba = Uint8List(outWidth * outHeight * 4);

    final bgA = transparentBackground ? 0 : backgroundColor.a;
    final bgR = transparentBackground ? 0 : backgroundColor.r;
    final bgG = transparentBackground ? 0 : backgroundColor.g;
    final bgB = transparentBackground ? 0 : backgroundColor.b;

    for (int y = 0; y < height; y++) {
      final row = grid[y];
      for (int x = 0; x < width; x++) {
        final idx = x < row.length ? row[x] : 0;
        int r = bgR, g = bgG, b = bgB, a = bgA;
        if (idx > 0 && idx <= palette.length) {
          final c = palette[idx - 1];
          r = c.r;
          g = c.g;
          b = c.b;
          a = c.a;
        }

        final pyStart = y * scale;
        final pxStart = x * scale;
        for (int sy = 0; sy < scale; sy++) {
          final rowBase = ((pyStart + sy) * outWidth + pxStart) * 4;
          for (int sx = 0; sx < scale; sx++) {
            final off = rowBase + sx * 4;
            rgba[off] = r;
            rgba[off + 1] = g;
            rgba[off + 2] = b;
            rgba[off + 3] = a;
          }
        }
      }
    }

    return encodeRgba(outWidth, outHeight, rgba);
  }
}

// === lib/src/svg_exporter.dart ===

/// Generates an SVG vector string representation of the pixel art [grid] and [palette].
///
/// Optimizes horizontal spans of identical colors into single rectangle elements
/// with crisp pixel edges (`shape-rendering="crispEdges"`).
String generateSvgString(
  List<List<int>> grid,
  List<PixelColor> palette, {
  int scale = 1,
  bool transparentBackground = true,
  PixelColor backgroundColor = const PixelColor(0xFF1E1E1E),
}) {
  final int height = grid.length;
  final int width = height > 0 ? grid[0].length : 0;
  if (width == 0 || height == 0 || scale <= 0) {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1" width="1" height="1"></svg>';
  }

  final int outWidth = width * scale;
  final int outHeight = height * scale;

  final buffer = StringBuffer();
  buffer.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height" width="$outWidth" height="$outHeight" shape-rendering="crispEdges">',
  );

  if (!transparentBackground) {
    final bgHex = backgroundColor.toHex();
    buffer.writeln('  <rect width="100%" height="100%" fill="$bgHex" />');
  }

  for (int y = 0; y < height; y++) {
    final row = grid[y];
    int x = 0;
    while (x < width && x < row.length) {
      final colorIndex = row[x];
      if (colorIndex > 0 && colorIndex <= palette.length) {
        int runLength = 1;
        while (x + runLength < width &&
            x + runLength < row.length &&
            row[x + runLength] == colorIndex) {
          runLength++;
        }
        final color = palette[colorIndex - 1];
        if (color.a > 0) {
          final hex = color.toHex();
          if (color.a < 255) {
            final double opacity = color.a / 255.0;
            final opacityStr = opacity
                .toStringAsFixed(4)
                .replaceAll(RegExp(r'0+$'), '')
                .replaceAll(RegExp(r'\.$'), '');
            buffer.writeln(
              '  <rect x="$x" y="$y" width="$runLength" height="1" fill="$hex" fill-opacity="$opacityStr" />',
            );
          } else {
            buffer.writeln(
              '  <rect x="$x" y="$y" width="$runLength" height="1" fill="$hex" />',
            );
          }
        }
        x += runLength;
      } else {
        x++;
      }
    }
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}

// === lib/src/preview_renderer.dart ===


/// Renders an upscaled inspection PNG with checkerboard transparency,
/// pixel gridlines, coordinate rulers (0..W-1, 0..H-1), and a palette swatch bar.
///
/// Designed specifically so humans and multimodal agents can visually inspect
/// a pixel art canvas and immediately read exact `(x, y)` coordinates and
/// palette indices.
class PreviewRenderer {
  /// Minimal 3x5 bitmap font for digits 0-9 and uppercase A-Z.
  static const Map<String, List<String>> _font3x5 = {
    '0': ['111', '101', '101', '101', '111'],
    '1': ['010', '110', '010', '010', '111'],
    '2': ['111', '001', '111', '100', '111'],
    '3': ['111', '001', '111', '001', '111'],
    '4': ['101', '101', '111', '001', '001'],
    '5': ['111', '100', '111', '001', '111'],
    '6': ['111', '100', '111', '101', '111'],
    '7': ['111', '001', '001', '010', '010'],
    '8': ['111', '101', '111', '101', '111'],
    '9': ['111', '101', '111', '001', '111'],
    'A': ['010', '101', '111', '101', '101'],
    'B': ['110', '101', '110', '101', '110'],
    'C': ['011', '100', '100', '100', '011'],
    'D': ['110', '101', '101', '101', '110'],
    'E': ['111', '100', '110', '100', '111'],
    'F': ['111', '100', '110', '100', '100'],
    'G': ['011', '100', '101', '101', '011'],
    'H': ['101', '101', '111', '101', '101'],
    'I': ['111', '010', '010', '010', '111'],
    'J': ['001', '001', '001', '101', '010'],
    'K': ['101', '101', '110', '101', '101'],
    'L': ['100', '100', '100', '100', '111'],
    'M': ['101', '111', '111', '101', '101'],
    'N': ['111', '101', '101', '101', '101'],
    'O': ['010', '101', '101', '101', '010'],
    'P': ['110', '101', '110', '100', '100'],
    'Q': ['010', '101', '101', '111', '011'],
    'R': ['110', '101', '110', '101', '101'],
    'S': ['011', '100', '010', '001', '110'],
    'T': ['111', '010', '010', '010', '010'],
    'U': ['101', '101', '101', '101', '111'],
    'V': ['101', '101', '101', '101', '010'],
    'W': ['101', '101', '111', '111', '101'],
    'X': ['101', '101', '010', '101', '101'],
    'Y': ['101', '101', '010', '010', '010'],
    'Z': ['111', '001', '010', '100', '111'],
  };

  /// Renders a debug preview PNG with rulers, gridlines, and palette legend.
  static Uint8List renderPreviewPng(
    List<List<int>> grid,
    List<PixelColor> palette, {
    int cellSize = 20,
    bool showGridLines = true,
    bool showRulers = true,
    bool showPaletteBar = true,
  }) {
    final int gridH = grid.length;
    final int gridW = gridH > 0 ? grid[0].length : 0;
    if (gridW <= 0 || gridH <= 0 || cellSize < 4) {
      return Uint8List(0);
    }

    final int rulerLeft = showRulers ? 28 : 0;
    final int rulerTop = showRulers ? 22 : 0;
    final int rightPad = 8;
    final int bottomPad = 8;
    final int paletteBarHeight = (showPaletteBar && palette.isNotEmpty)
        ? 38
        : 0;

    final int canvasW = gridW * cellSize;
    final int canvasH = gridH * cellSize;
    final int totalW = rulerLeft + canvasW + rightPad;
    final int totalH = rulerTop + canvasH + bottomPad + paletteBarHeight;

    final buf = _RgbaBuffer(totalW, totalH);
    const frameBg = PixelColor(0xFF1A1D24);
    const rulerText = PixelColor(0xFFB8C4D4);
    const checkerA = PixelColor(0xFF2B2F3A);
    const checkerB = PixelColor(0xFF343946);
    const minorGrid = PixelColor(0xFF474E61);
    const majorGrid = PixelColor(0xFF67718A);

    buf.fillRect(0, 0, totalW, totalH, frameBg);

    // Draw pixels + checkerboard background
    final int checkerTile = (cellSize ~/ 2).clamp(2, 12);
    for (int gy = 0; gy < gridH; gy++) {
      final row = grid[gy];
      for (int gx = 0; gx < gridW; gx++) {
        final px0 = rulerLeft + gx * cellSize;
        final py0 = rulerTop + gy * cellSize;
        final idx = gx < row.length ? row[gx] : 0;

        if (idx > 0 && idx <= palette.length) {
          final color = palette[idx - 1];
          if (color.a == 255) {
            buf.fillRect(px0, py0, cellSize, cellSize, color);
          } else {
            _fillChecker(
              buf,
              px0,
              py0,
              cellSize,
              cellSize,
              checkerTile,
              checkerA,
              checkerB,
            );
            buf.blendRect(px0, py0, cellSize, cellSize, color);
          }
        } else {
          _fillChecker(
            buf,
            px0,
            py0,
            cellSize,
            cellSize,
            checkerTile,
            checkerA,
            checkerB,
          );
        }
      }
    }

    // Draw gridlines
    if (showGridLines) {
      for (int gx = 0; gx <= gridW; gx++) {
        final x = rulerLeft + gx * cellSize;
        final isMajor = gx % 4 == 0 || gx == gridW;
        final lineColor = isMajor ? majorGrid : minorGrid;
        final drawX = gx == gridW ? x - 1 : x;
        buf.fillRect(drawX, rulerTop, 1, canvasH, lineColor);
      }
      for (int gy = 0; gy <= gridH; gy++) {
        final y = rulerTop + gy * cellSize;
        final isMajor = gy % 4 == 0 || gy == gridH;
        final lineColor = isMajor ? majorGrid : minorGrid;
        final drawY = gy == gridH ? y - 1 : y;
        buf.fillRect(rulerLeft, drawY, canvasW, 1, lineColor);
      }
    }

    // Draw coordinate rulers
    if (showRulers) {
      final fontScale = cellSize >= 18 ? 2 : 1;
      final stepX = cellSize < 14 ? 2 : 1;
      final stepY = cellSize < 12 ? 2 : 1;

      for (int gx = 0; gx < gridW; gx += stepX) {
        final label = gx.toString();
        final textW = _measureText(label, fontScale);
        final textH = 5 * fontScale;
        final cx = rulerLeft + gx * cellSize + (cellSize - textW) ~/ 2;
        final cy = (rulerTop - textH) ~/ 2;
        _drawText(buf, label, cx, cy, fontScale, rulerText);
      }

      for (int gy = 0; gy < gridH; gy += stepY) {
        final label = gy.toString();
        final textW = _measureText(label, fontScale);
        final textH = 5 * fontScale;
        final cx = rulerLeft - textW - 4;
        final cy = rulerTop + gy * cellSize + (cellSize - textH) ~/ 2;
        _drawText(buf, label, cx, cy, fontScale, rulerText);
      }
    }

    // Draw palette swatch bar
    if (showPaletteBar && palette.isNotEmpty) {
      final barTop = rulerTop + canvasH + bottomPad + 4;
      final count = palette.length;
      final availW = canvasW;
      final swatchStep = (availW ~/ count).clamp(12, 34);
      final swatchW = (swatchStep - 3).clamp(8, 28);
      final swatchH = 16;

      for (int i = 0; i < count; i++) {
        final sx = rulerLeft + i * swatchStep;
        if (sx + swatchW > totalW - rightPad) break;

        // Border around swatch
        buf.fillRect(sx - 1, barTop - 1, swatchW + 2, swatchH + 2, majorGrid);
        buf.fillRect(sx, barTop, swatchW, swatchH, palette[i]);

        final label = indexToSymbol(i + 1);
        final tw = _measureText(label, 2);
        final lx = sx + (swatchW - tw) ~/ 2;
        _drawText(buf, label, lx, barTop + swatchH + 3, 2, rulerText);
      }
    }

    return PngEncoder.encodeRgba(totalW, totalH, buf.data);
  }

  /// Maps a 1-based color index to a single display character (`1..9`, `A..Z`).
  static String indexToSymbol(int index) {
    if (index <= 0) return '.';
    if (index <= 9) return index.toString();
    if (index <= 35) return String.fromCharCode(65 + index - 10);
    return '#';
  }

  /// Formats a pixel grid as a readable ASCII table with coordinate rulers.
  static String formatAsciiGrid(List<List<int>> grid) {
    final int height = grid.length;
    final int width = height > 0 ? grid[0].length : 0;
    if (width == 0 || height == 0) return '(empty grid)';

    final sb = StringBuffer();
    // Tens header for widths > 10
    if (width > 10) {
      sb.write('    ');
      for (int x = 0; x < width; x++) {
        sb.write(x >= 10 ? '${x ~/ 10} ' : '  ');
      }
      sb.writeln();
    }
    sb.write('    ');
    for (int x = 0; x < width; x++) {
      sb.write('${x % 10} ');
    }
    sb.writeln();

    for (int y = 0; y < height; y++) {
      sb.write('${y.toString().padLeft(2)}  ');
      final row = grid[y];
      for (int x = 0; x < width; x++) {
        final v = x < row.length ? row[x] : 0;
        sb.write('${indexToSymbol(v)} ');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  static void _fillChecker(
    _RgbaBuffer buf,
    int x0,
    int y0,
    int w,
    int h,
    int tile,
    PixelColor a,
    PixelColor b,
  ) {
    for (int y = y0; y < y0 + h; y++) {
      final ty = (y - y0) ~/ tile;
      for (int x = x0; x < x0 + w; x++) {
        final tx = (x - x0) ~/ tile;
        buf.setPixel(x, y, ((tx + ty) & 1) == 0 ? a : b);
      }
    }
  }

  static int _measureText(String text, int scale) {
    if (text.isEmpty) return 0;
    return (text.length * 4 - 1) * scale;
  }

  static void _drawText(
    _RgbaBuffer buf,
    String text,
    int x,
    int y,
    int scale,
    PixelColor color,
  ) {
    int cursorX = x;
    for (int i = 0; i < text.length; i++) {
      final glyph = _font3x5[text[i].toUpperCase()];
      if (glyph != null) {
        for (int gy = 0; gy < 5; gy++) {
          final row = glyph[gy];
          for (int gx = 0; gx < 3; gx++) {
            if (row[gx] == '1') {
              buf.fillRect(
                cursorX + gx * scale,
                y + gy * scale,
                scale,
                scale,
                color,
              );
            }
          }
        }
      }
      cursorX += 4 * scale;
    }
  }
}

class _RgbaBuffer {
  final int width;
  final int height;
  final Uint8List data;

  _RgbaBuffer(this.width, this.height) : data = Uint8List(width * height * 4);

  void setPixel(int x, int y, PixelColor c) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    final off = (y * width + x) * 4;
    data[off] = c.r;
    data[off + 1] = c.g;
    data[off + 2] = c.b;
    data[off + 3] = c.a;
  }

  void fillRect(int x0, int y0, int w, int h, PixelColor c) {
    final xStart = x0 < 0 ? 0 : x0;
    final yStart = y0 < 0 ? 0 : y0;
    final xEnd = (x0 + w) > width ? width : (x0 + w);
    final yEnd = (y0 + h) > height ? height : (y0 + h);
    for (int y = yStart; y < yEnd; y++) {
      int off = (y * width + xStart) * 4;
      for (int x = xStart; x < xEnd; x++) {
        data[off] = c.r;
        data[off + 1] = c.g;
        data[off + 2] = c.b;
        data[off + 3] = c.a;
        off += 4;
      }
    }
  }

  void blendRect(int x0, int y0, int w, int h, PixelColor c) {
    if (c.a == 0) return;
    final alpha = c.a / 255.0;
    final inv = 1.0 - alpha;
    final xStart = x0 < 0 ? 0 : x0;
    final yStart = y0 < 0 ? 0 : y0;
    final xEnd = (x0 + w) > width ? width : (x0 + w);
    final yEnd = (y0 + h) > height ? height : (y0 + h);
    for (int y = yStart; y < yEnd; y++) {
      int off = (y * width + xStart) * 4;
      for (int x = xStart; x < xEnd; x++) {
        data[off] = (c.r * alpha + data[off] * inv).round().clamp(0, 255);
        data[off + 1] = (c.g * alpha + data[off + 1] * inv).round().clamp(
          0,
          255,
        );
        data[off + 2] = (c.b * alpha + data[off + 2] * inv).round().clamp(
          0,
          255,
        );
        data[off + 3] = 255;
        off += 4;
      }
    }
  }
}

// === lib/src/scene.dart ===


/// Result of rendering a declarative [PixelArtScene] into a palette-indexed grid.
class SceneRenderResult {
  final String title;
  final int gridSize;
  final List<PixelColor> palette;
  final Map<String, int> colorNames;
  final List<List<int>> grid;
  final List<String> warnings;

  const SceneRenderResult({
    required this.title,
    required this.gridSize,
    required this.palette,
    required this.colorNames,
    required this.grid,
    required this.warnings,
  });

  /// Counts non-transparent pixels in [grid].
  int get filledPixelCount {
    int count = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell > 0) count++;
      }
    }
    return count;
  }

  /// Counts pixels per palette index (1..palette.length).
  Map<int, int> get colorUsage {
    final counts = <int, int>{};
    for (final row in grid) {
      for (final cell in row) {
        if (cell > 0) {
          counts[cell] = (counts[cell] ?? 0) + 1;
        }
      }
    }
    return counts;
  }
}

/// Declarative scene runner for BadPixelArt.
///
/// Compiles a JSON scene specification into a final composited pixel grid,
/// supporting:
/// - Named palettes (`"sweetie16"`, `"pico8"`, etc.), hex lists, or named color maps
/// - Bottom-to-top layered compositing
/// - Three flexible layer styles (combinable on any layer):
///   1. **Component mask + Bayer gradient + outline** (`maskOps` / `shapes`, `add`, `remove`, `fill`, `fill2`, `gradientAngle`, `dither`, `outline`, `outlineMode`)
///   2. **Multi-color drawing commands** (`ops`: `[{tool, params, color}, ...]`)
///   3. **ASCII pixel rows** (`rows` + optional `legend`, `offsetX`, `offsetY`)
/// - Optional per-layer or scene-wide `mirrorH` / `mirrorV`
/// - Global `postOps` for final silhouettes (`auto_outline`), pixel touch-ups, and swaps
class PixelArtScene {
  final Map<String, dynamic> spec;

  PixelArtScene(this.spec);

  factory PixelArtScene.fromJsonString(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Scene JSON root must be an object.');
    }
    return PixelArtScene(decoded);
  }

  SceneRenderResult render() {
    final warnings = <String>[];
    final title = (spec['title'] as String?)?.trim().isNotEmpty == true
        ? (spec['title'] as String).trim()
        : 'pixel_art';

    final int gridSize = _parseInt(spec['gridSize'] ?? spec['size']) ?? 16;
    if (gridSize <= 0 || gridSize > 256) {
      throw RangeError.range(gridSize, 1, 256, 'gridSize');
    }

    // 1. Parse palette
    final palette = <PixelColor>[];
    final colorNames = <String, int>{};
    _parsePalette(spec['palette'], palette, colorNames, warnings);
    if (palette.isEmpty) {
      palette.addAll(PaletteRegistry.sweetie16Palette);
      warnings.add('No palette specified; defaulted to sweetie16.');
    }

    int resolveColor(dynamic raw, {int fallback = 1}) {
      if (raw == null) return fallback;
      if (raw is int) {
        if (raw == 0) return 0;
        if (raw >= 1 && raw <= palette.length) return raw;
        warnings.add('Color index $raw out of range 0..${palette.length}.');
        return raw.clamp(0, palette.length);
      }
      if (raw is num) {
        return resolveColor(raw.round(), fallback: fallback);
      }
      final s = raw.toString().trim();
      if (s.isEmpty ||
          s == '0' ||
          s.toLowerCase() == 'transparent' ||
          s.toLowerCase() == 'erase') {
        return 0;
      }
      final asInt = int.tryParse(s);
      if (asInt != null) {
        return resolveColor(asInt, fallback: fallback);
      }
      final named = colorNames[s.toLowerCase()];
      if (named != null) return named;

      final parsedHex = PixelColor.tryParseHex(s);
      if (parsedHex != null) {
        final existingIdx = palette.indexWhere(
          (c) => c.toARGB32() == parsedHex.toARGB32(),
        );
        if (existingIdx != -1) return existingIdx + 1;
        palette.add(parsedHex);
        return palette.length;
      }

      warnings.add('Unknown color "$raw"; using fallback index $fallback.');
      return fallback;
    }

    final grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));

    // Optional base template
    final templateId = spec['template'] as String?;
    if (templateId != null && templateId.isNotEmpty) {
      final tmpl = SpriteTemplate.getById(templateId);
      if (tmpl != null) {
        final tGrid = tmpl.parseToGrid();
        _blitGrid(grid, tGrid, gridSize);
      } else {
        warnings.add('Unknown template "$templateId".');
      }
    }

    // 2. Render layers bottom-to-top
    final layers = spec['layers'] as List? ?? const [];
    for (int i = 0; i < layers.length; i++) {
      final rawLayer = layers[i];
      if (rawLayer is! Map<String, dynamic>) {
        warnings.add('Layer $i is not an object; skipped.');
        continue;
      }
      if (rawLayer['visible'] == false) continue;

      final layerName = (rawLayer['name'] as String?) ?? 'layer_$i';
      final layerGrid = List.generate(
        gridSize,
        (_) => List.filled(gridSize, 0),
      );

      final NormalizedRect? boundsRect = _parseBounds(
        rawLayer['bounds'],
        gridSize,
      );
      final BoundedCanvas? bounded = boundsRect != null
          ? BoundedCanvas(
              grid: layerGrid,
              boundingBox: boundsRect,
              gridSize: gridSize,
            )
          : null;

      void applyOps(List<dynamic> opsList, {bool maskMode = false}) {
        for (final rawOp in opsList) {
          if (rawOp is! Map<String, dynamic>) continue;
          final tool = (rawOp['tool'] as String? ?? '').trim().toLowerCase();
          if (tool.isEmpty) continue;
          final params = _parseNumList(rawOp['params']);
          final colorIdx = maskMode
              ? (rawOp.containsKey('color')
                    ? resolveColor(rawOp['color'], fallback: 1)
                    : 1)
              : resolveColor(
                  rawOp['color'] ?? rawOp['colorIndex'],
                  fallback: 1,
                );

          final cmd = DrawingCommandFactory.create(tool, params);
          if (cmd == null) {
            warnings.add(
              'Layer "$layerName": invalid command "$tool" with params $params.',
            );
            continue;
          }
          if (bounded != null) {
            bounded.executeClamped((g) => cmd.execute(g, colorIdx, gridSize));
          } else {
            cmd.execute(layerGrid, colorIdx, gridSize);
          }
        }
      }

      // Mode A: Component mask mode (shapes/maskOps + fill/fill2/gradientAngle/outline)
      final hasMaskSpec =
          rawLayer.containsKey('maskOps') ||
          rawLayer.containsKey('shapes') ||
          rawLayer.containsKey('fill') ||
          rawLayer.containsKey('fillColor');

      if (hasMaskSpec) {
        final maskGrid = List.generate(
          gridSize,
          (_) => List.filled(gridSize, 0),
        );
        final maskBounded = boundsRect != null
            ? BoundedCanvas(
                grid: maskGrid,
                boundingBox: boundsRect,
                gridSize: gridSize,
              )
            : null;

        final maskOps =
            (rawLayer['maskOps'] ?? rawLayer['shapes']) as List? ?? const [];
        for (final rawOp in maskOps) {
          if (rawOp is! Map<String, dynamic>) continue;
          final tool = (rawOp['tool'] as String? ?? '').trim().toLowerCase();
          if (tool.isEmpty) continue;
          final params = _parseNumList(rawOp['params']);
          final val = rawOp['erase'] == true ? 0 : 1;
          final cmd = DrawingCommandFactory.create(tool, params);
          if (cmd == null) {
            warnings.add(
              'Layer "$layerName": invalid mask command "$tool" with params $params.',
            );
            continue;
          }
          if (maskBounded != null) {
            maskBounded.executeClamped((g) => cmd.execute(g, val, gridSize));
          } else {
            cmd.execute(maskGrid, val, gridSize);
          }
        }

        _applyCoordList(
          maskGrid,
          rawLayer['add'] as List?,
          1,
          gridSize,
          maskBounded,
          warnings,
          layerName,
        );
        _applyCoordList(
          maskGrid,
          (rawLayer['remove'] ?? rawLayer['erase']) as List?,
          0,
          gridSize,
          maskBounded,
          warnings,
          layerName,
        );

        if (rawLayer['mirrorH'] == true) {
          MirrorHorizontalCommand().execute(maskGrid, 1, gridSize);
        }
        if (rawLayer['mirrorV'] == true) {
          MirrorVerticalCommand().execute(maskGrid, 1, gridSize);
        }

        final fillRaw = rawLayer['fill'] ?? rawLayer['fillColor'];
        final fill2Raw = rawLayer['fill2'] ?? rawLayer['fillColor2'];
        final outlineRaw = rawLayer['outline'] ?? rawLayer['outlineColor'];
        final outlineMode = (rawLayer['outlineMode'] as String? ?? 'inner')
            .trim()
            .toLowerCase();
        final double gradientAngle =
            (_parseNum(rawLayer['gradientAngle']) ?? 90.0).toDouble();
        final bool dither = rawLayer['dither'] != false;

        final fillIdx = fillRaw != null
            ? resolveColor(fillRaw, fallback: 1)
            : 0;
        final fill2Idx = fill2Raw != null
            ? resolveColor(fill2Raw, fallback: 0)
            : 0;
        final outlineIdx = outlineRaw != null
            ? resolveColor(outlineRaw, fallback: 0)
            : 0;

        final comp = PixelArtComponent(
          name: layerName,
          description: (rawLayer['description'] as String?) ?? '',
          relativeBoundingBox: boundsRect ?? NormalizedRect.full,
          grid: maskGrid,
          fillColor: fillIdx > 0 ? palette[fillIdx - 1] : null,
          fillColor2: fill2Idx > 0 ? palette[fill2Idx - 1] : null,
          gradientAngle: gradientAngle,
          outlineColor: outlineIdx > 0 ? palette[outlineIdx - 1] : null,
          isSculpted: true,
        );

        if (fillIdx > 0) {
          final color1 = palette[fillIdx - 1];
          for (int y = 0; y < gridSize; y++) {
            for (int x = 0; x < gridSize; x++) {
              if (maskGrid[y][x] > 0) {
                final c = comp.getPixelFillColorWithMode(x, y, dither: dither);
                if (c != null) {
                  layerGrid[y][x] = (fill2Idx > 0 && c != color1)
                      ? fill2Idx
                      : fillIdx;
                }
              }
            }
          }
        }

        if (outlineIdx > 0) {
          if (outlineMode == 'outer' || outlineMode == 'outer8') {
            OutlineCommand(
              eightConnected: outlineMode == 'outer8',
            ).execute(layerGrid, outlineIdx, gridSize);
          } else {
            final outline = comp.getOutlineGrid();
            if (outline != null) {
              for (int y = 0; y < gridSize; y++) {
                for (int x = 0; x < gridSize; x++) {
                  if (outline[y][x] > 0) {
                    layerGrid[y][x] = outlineIdx;
                  }
                }
              }
            }
          }
        }
      }

      // Mode B: Direct ASCII rows (optionally with custom char->color legend)
      final rawRows = rawLayer['rows'] as List?;
      if (rawRows != null && rawRows.isNotEmpty) {
        final lines = rawRows.map((e) => e.toString()).toList();
        final offsetX = _parseInt(rawLayer['offsetX']) ?? 0;
        final offsetY = _parseInt(rawLayer['offsetY']) ?? 0;
        final rawLegend = rawLayer['legend'] as Map<String, dynamic>?;
        final legend = <String, int>{};
        if (rawLegend != null) {
          for (final entry in rawLegend.entries) {
            if (entry.key.isNotEmpty) {
              legend[entry.key[0]] = resolveColor(entry.value, fallback: 0);
            }
          }
        }

        for (int ry = 0; ry < lines.length; ry++) {
          final line = lines[ry];
          for (int rx = 0; rx < line.length; rx++) {
            final ch = line[rx];
            if (ch == '.' || ch == ' ') continue;
            int idx;
            if (legend.containsKey(ch)) {
              idx = legend[ch]!;
            } else if (ch == '0') {
              idx = 0;
            } else {
              final digit = int.tryParse(ch);
              if (digit != null) {
                idx = digit;
              } else {
                final code = ch.toUpperCase().codeUnitAt(0);
                if (code >= 65 && code <= 90) {
                  idx = code - 65 + 10;
                } else {
                  idx = 1;
                }
              }
            }

            final tx = rx + offsetX;
            final ty = ry + offsetY;
            if (tx >= 0 && tx < gridSize && ty >= 0 && ty < gridSize) {
              if (idx == 0) {
                layerGrid[ty][tx] = 0;
              } else if (idx <= palette.length) {
                layerGrid[ty][tx] = idx;
              } else {
                warnings.add(
                  'Layer "$layerName": row char "$ch" resolved to out-of-range color index $idx.',
                );
              }
            }
          }
        }
      }

      // Mode C: Direct multi-color ops
      final ops = rawLayer['ops'] as List?;
      if (ops != null && ops.isNotEmpty) {
        applyOps(ops, maskMode: false);
      }

      // Per-layer mirror (when not already applied in mask-only path)
      if (!hasMaskSpec) {
        if (rawLayer['mirrorH'] == true) {
          MirrorHorizontalCommand().execute(layerGrid, 0, gridSize);
        }
        if (rawLayer['mirrorV'] == true) {
          MirrorVerticalCommand().execute(layerGrid, 0, gridSize);
        }
      }

      // Composite layer onto main grid (0 = transparent)
      final eraseMode = rawLayer['blend'] == 'erase';
      for (int y = 0; y < gridSize; y++) {
        for (int x = 0; x < gridSize; x++) {
          final v = layerGrid[y][x];
          if (v > 0) {
            grid[y][x] = eraseMode ? 0 : v;
          }
        }
      }
    }

    // 3. Global postOps (refinements, outer silhouette outline, global mirror, pixel tweaks)
    final postOps = spec['postOps'] as List? ?? const [];
    for (final rawOp in postOps) {
      if (rawOp is! Map<String, dynamic>) continue;
      final tool = (rawOp['tool'] as String? ?? '').trim().toLowerCase();
      if (tool.isEmpty) continue;
      final params = _parseNumList(rawOp['params']);
      final colorIdx = resolveColor(
        rawOp['color'] ?? rawOp['colorIndex'],
        fallback: 1,
      );
      final cmd = DrawingCommandFactory.create(tool, params);
      if (cmd == null) {
        warnings.add('postOps: invalid command "$tool" with params $params.');
        continue;
      }
      cmd.execute(grid, colorIdx, gridSize);
    }

    // Scene-level symmetry shortcuts
    if (spec['mirrorH'] == true) {
      MirrorHorizontalCommand().execute(grid, 0, gridSize);
    }
    if (spec['mirrorV'] == true) {
      MirrorVerticalCommand().execute(grid, 0, gridSize);
    }

    return SceneRenderResult(
      title: title,
      gridSize: gridSize,
      palette: palette,
      colorNames: colorNames,
      grid: grid,
      warnings: warnings,
    );
  }

  static void _parsePalette(
    dynamic rawPalette,
    List<PixelColor> palette,
    Map<String, int> colorNames,
    List<String> warnings,
  ) {
    if (rawPalette == null) return;

    if (rawPalette is String) {
      final preset = PaletteRegistry.findById(rawPalette);
      if (preset != null) {
        palette.addAll(preset.colors);
      } else {
        warnings.add('Unknown palette preset "$rawPalette".');
      }
      return;
    }

    if (rawPalette is List) {
      for (final item in rawPalette) {
        if (item is String) {
          final c = PixelColor.tryParseHex(item);
          if (c != null) {
            palette.add(c);
          } else {
            warnings.add('Invalid hex color in palette: "$item".');
          }
        } else if (item is Map<String, dynamic>) {
          final name = item['name']?.toString().trim();
          final hex = item['hex']?.toString() ?? item['color']?.toString();
          final c = PixelColor.tryParseHex(hex);
          if (c != null) {
            palette.add(c);
            if (name != null && name.isNotEmpty) {
              colorNames[name.toLowerCase()] = palette.length;
            }
          } else {
            warnings.add('Invalid palette entry: $item');
          }
        }
      }
      return;
    }

    if (rawPalette is Map<String, dynamic>) {
      for (final entry in rawPalette.entries) {
        final c = PixelColor.tryParseHex(entry.value?.toString());
        if (c != null) {
          palette.add(c);
          colorNames[entry.key.trim().toLowerCase()] = palette.length;
        } else {
          warnings.add(
            'Invalid hex color for "${entry.key}": "${entry.value}".',
          );
        }
      }
    }
  }

  static NormalizedRect? _parseBounds(dynamic raw, int gridSize) {
    if (raw is! Map<String, dynamic>) return null;
    if (raw.containsKey('left') || raw.containsKey('width')) {
      return NormalizedRect.fromJson(raw);
    }
    if (raw.containsKey('minX') && raw.containsKey('maxX')) {
      final minX = _parseInt(raw['minX']) ?? 0;
      final maxX = _parseInt(raw['maxX']) ?? (gridSize - 1);
      final minY = _parseInt(raw['minY']) ?? 0;
      final maxY = _parseInt(raw['maxY']) ?? (gridSize - 1);
      return NormalizedRect.fromLTWH(
        minX / gridSize,
        minY / gridSize,
        (maxX - minX + 1) / gridSize,
        (maxY - minY + 1) / gridSize,
      );
    }
    return null;
  }

  static void _applyCoordList(
    List<List<int>> grid,
    List<dynamic>? coords,
    int value,
    int gridSize,
    BoundedCanvas? bounded,
    List<String> warnings,
    String layerName,
  ) {
    if (coords == null) return;
    for (final item in coords) {
      int? x, y;
      if (item is List && item.length >= 2) {
        x = _parseInt(item[0]);
        y = _parseInt(item[1]);
      } else if (item is Map) {
        x = _parseInt(item['x']);
        y = _parseInt(item['y']);
      }
      if (x == null || y == null) continue;
      if (x < 0 || x >= gridSize || y < 0 || y >= gridSize) {
        warnings.add('Layer "$layerName": coord ($x,$y) out of grid bounds.');
        continue;
      }
      if (bounded != null) {
        bounded.setPixel(x, y, value);
      } else {
        grid[y][x] = value;
      }
    }
  }

  static void _blitGrid(
    List<List<int>> dst,
    List<List<int>> src,
    int gridSize,
  ) {
    for (int y = 0; y < src.length && y < gridSize; y++) {
      for (int x = 0; x < src[y].length && x < gridSize; x++) {
        if (src[y][x] > 0) {
          dst[y][x] = src[y][x];
        }
      }
    }
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static num? _parseNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return null;
  }

  static List<num> _parseNumList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <num>[];
    for (final e in raw) {
      final n = _parseNum(e);
      if (n != null) out.add(n);
    }
    return out;
  }
}

// === bin/pixel_art.dart ===


void main(List<String> args) {
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    _printUsage();
    return;
  }

  final command = args.first;
  final rest = args.sublist(1);

  try {
    switch (command) {
      case 'render':
        _handleRender(rest);
      case 'inspect':
        _handleInspect(rest);
      case 'palettes':
        _handlePalettes();
      case 'tools':
        _handleTools();
      default:
        stderr.writeln('Unknown command: "$command"\n');
        _printUsage();
        exitCode = 64;
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    exitCode = 1;
  }
}

void _printUsage() {
  stdout.writeln('''
pixel_art — Pure-Dart BadPixelArt CLI engine

Usage:
  pixel_art render <scene.json> [options]
  pixel_art inspect <scene.json>
  pixel_art palettes
  pixel_art tools

Render options:
  --out <path.png>        Write clean pixel-art PNG (supports --scale, --bg)
  --svg <path.svg>        Write run-length-optimized crispEdges SVG
  --preview <path.png>    Write upscaled debug preview PNG with grid & coordinate rulers
  --scale <int>           Integer scale factor for --out PNG / --svg (default: 16)
  --cell-size <int>       Cell size in pixels for --preview PNG (default: 20)
  --bg <#RRGGBB>          Solid background hex color for --out / --svg (default: transparent)
  --no-grid               Hide gridlines in --preview PNG
  --no-rulers             Hide coordinate rulers in --preview PNG
  --no-palette            Hide palette legend bar in --preview PNG
  --ascii                 Print ASCII grid with coordinate rulers to stdout
  --json-grid <path.json> Dump resolved {gridSize, palette, grid} JSON
''');
}

void _handleRender(List<String> args) {
  String? inputPath;
  String? outPngPath;
  String? outSvgPath;
  String? previewPath;
  String? jsonGridPath;
  int scale = 16;
  int cellSize = 20;
  PixelColor? bgColor;
  bool showGrid = true;
  bool showRulers = true;
  bool showPalette = true;
  bool printAscii = false;

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--out':
      case '-o':
        outPngPath = _requireValue(args, ++i, arg);
      case '--svg':
        outSvgPath = _requireValue(args, ++i, arg);
      case '--preview':
        previewPath = _requireValue(args, ++i, arg);
      case '--json-grid':
        jsonGridPath = _requireValue(args, ++i, arg);
      case '--scale':
        scale = int.parse(_requireValue(args, ++i, arg));
      case '--cell-size':
        cellSize = int.parse(_requireValue(args, ++i, arg));
      case '--bg':
        bgColor = PixelColor.parseHex(_requireValue(args, ++i, arg));
      case '--no-grid':
        showGrid = false;
      case '--no-rulers':
        showRulers = false;
      case '--no-palette':
        showPalette = false;
      case '--ascii':
        printAscii = true;
      default:
        if (arg.startsWith('-')) {
          throw ArgumentError('Unknown option: $arg');
        }
        inputPath ??= arg;
    }
  }

  if (inputPath == null) {
    throw ArgumentError('Missing required <scene.json> input path.');
  }

  final file = File(inputPath);
  if (!file.existsSync()) {
    throw FileSystemException('Scene file not found', inputPath);
  }

  final scene = PixelArtScene.fromJsonString(file.readAsStringSync());
  final result = scene.render();

  final transparent = bgColor == null;
  final effectiveBg = bgColor ?? const PixelColor(0xFF1E1E1E);

  if (outPngPath != null) {
    final bytes = PngEncoder.encodeGrid(
      result.grid,
      result.palette,
      scale: scale,
      transparentBackground: transparent,
      backgroundColor: effectiveBg,
    );
    _writeBytes(outPngPath, bytes);
    stdout.writeln(
      'Wrote PNG: $outPngPath (${result.gridSize * scale}x${result.gridSize * scale}, ${bytes.length} bytes)',
    );
  }

  if (outSvgPath != null) {
    final svg = generateSvgString(
      result.grid,
      result.palette,
      scale: scale,
      transparentBackground: transparent,
      backgroundColor: effectiveBg,
    );
    _writeString(outSvgPath, svg);
    stdout.writeln('Wrote SVG: $outSvgPath (${svg.length} chars)');
  }

  if (previewPath != null) {
    final previewBytes = PreviewRenderer.renderPreviewPng(
      result.grid,
      result.palette,
      cellSize: cellSize,
      showGridLines: showGrid,
      showRulers: showRulers,
      showPaletteBar: showPalette,
    );
    _writeBytes(previewPath, previewBytes);
    stdout.writeln(
      'Wrote preview PNG: $previewPath (${previewBytes.length} bytes)',
    );
  }

  if (jsonGridPath != null) {
    final payload = const JsonEncoder.withIndent('  ').convert({
      'title': result.title,
      'gridSize': result.gridSize,
      'palette': result.palette.map((c) => c.toHex(uppercase: true)).toList(),
      'grid': result.grid,
    });
    _writeString(jsonGridPath, payload);
    stdout.writeln('Wrote grid JSON: $jsonGridPath');
  }

  if (printAscii ||
      (outPngPath == null &&
          outSvgPath == null &&
          previewPath == null &&
          jsonGridPath == null)) {
    stdout.writeln(PreviewRenderer.formatAsciiGrid(result.grid));
  }

  if (result.warnings.isNotEmpty) {
    stderr.writeln('Warnings (${result.warnings.length}):');
    for (final w in result.warnings) {
      stderr.writeln('  - $w');
    }
  }
}

void _handleInspect(List<String> args) {
  if (args.isEmpty) {
    throw ArgumentError('Missing required <scene.json> input path.');
  }
  final file = File(args.first);
  final scene = PixelArtScene.fromJsonString(file.readAsStringSync());
  final result = scene.render();

  final totalCells = result.gridSize * result.gridSize;
  final filled = result.filledPixelCount;
  final pct = totalCells > 0
      ? (filled * 100.0 / totalCells).toStringAsFixed(1)
      : '0.0';

  stdout.writeln('Title: ${result.title}');
  stdout.writeln(
    'Grid: ${result.gridSize}x${result.gridSize} ($filled/$totalCells pixels filled, $pct%)',
  );
  stdout.writeln('Palette (${result.palette.length} colors):');

  final usage = result.colorUsage;
  final indexToName = <int, String>{};
  for (final e in result.colorNames.entries) {
    indexToName[e.value] = e.key;
  }

  for (int i = 0; i < result.palette.length; i++) {
    final idx = i + 1;
    final sym = PreviewRenderer.indexToSymbol(idx);
    final hex = result.palette[i].toHex(uppercase: true);
    final name = indexToName[idx] != null ? ' (${indexToName[idx]})' : '';
    final count = usage[idx] ?? 0;
    stdout.writeln('  [$sym] #$idx $hex$name — $count px');
  }

  stdout.writeln();
  stdout.write(PreviewRenderer.formatAsciiGrid(result.grid));

  if (result.warnings.isNotEmpty) {
    stdout.writeln('\nWarnings (${result.warnings.length}):');
    for (final w in result.warnings) {
      stdout.writeln('  - $w');
    }
  }
}

void _handlePalettes() {
  for (final p in PaletteRegistry.presets) {
    final hexes = p.colors.map((c) => c.toHex(uppercase: true)).join(', ');
    stdout.writeln('${p.id} (${p.displayName}, ${p.colors.length} colors):');
    stdout.writeln('  $hexes');
  }
}

void _handleTools() {
  for (final entry in DrawingCommandFactory.toolInstructions.entries) {
    if (entry.key == 'undo') continue;
    stdout.writeln('- ${entry.key}: ${entry.value}');
  }
}

String _requireValue(List<String> args, int idx, String flag) {
  if (idx >= args.length) {
    throw ArgumentError('Option $flag requires a value.');
  }
  return args[idx];
}

void _writeBytes(String path, List<int> bytes) {
  final f = File(path);
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(bytes);
}

void _writeString(String path, String content) {
  final f = File(path);
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(content);
}

