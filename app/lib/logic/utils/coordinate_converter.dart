import 'package:flutter/material.dart';

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
  int get maxX => (rightCol - 1 < leftCol) ? leftCol : rightCol - 1;

  /// 0-indexed inclusive minimum Y pixel coordinate.
  int get minY => topRow;

  /// 0-indexed inclusive maximum Y pixel coordinate.
  int get maxY => (bottomRow - 1 < topRow) ? topRow : bottomRow - 1;

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

  /// Converts integer grid bounds back to a normalized `0.0..1.0` double [Rect].
  Rect toNormalizedRect(int gridSize) {
    if (gridSize <= 0) return Rect.zero;
    return Rect.fromLTWH(
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
  int get hashCode =>
      leftCol.hashCode ^
      topRow.hashCode ^
      rightCol.hashCode ^
      bottomRow.hashCode;

  @override
  String toString() =>
      'GridBounds(leftCol: $leftCol, topRow: $topRow, rightCol: $rightCol, bottomRow: $bottomRow)';
}

/// Extension on [Rect] for normalized double coordinate to integer pixel grid conversions.
extension RectGridExtension on Rect {
  /// Converts a normalized [Rect] (coordinates 0.0 to 1.0) to integer pixel [GridBounds] for a given [gridSize].
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
      if (x2 <= x1) x2 = (x1 + 1).clamp(0, gridSize);
      if (y2 <= y1) y2 = (y1 + 1).clamp(0, gridSize);
    }

    return GridBounds(
      leftCol: x1,
      topRow: y1,
      rightCol: x2,
      bottomRow: y2,
    );
  }

  /// Converts relative shape bounds (0.0 to 1.0 within parent component) to sub-grid bounds within [parentBounds].
  GridBounds toSubGridBounds(GridBounds parentBounds) {
    final parentWidth = parentBounds.width;
    final parentHeight = parentBounds.height;

    final sMinX = (parentBounds.minX + left * parentWidth).round();
    final sMaxX =
        (parentBounds.minX + (left + width) * parentWidth).round() - 1;
    final sMinY = (parentBounds.minY + top * parentHeight).round();
    final sMaxY =
        (parentBounds.minY + (top + height) * parentHeight).round() - 1;

    final clampedMinX = sMinX.clamp(parentBounds.minX, parentBounds.maxX);
    final clampedMaxX = sMaxX.clamp(parentBounds.minX, parentBounds.maxX);
    final clampedMinY = sMinY.clamp(parentBounds.minY, parentBounds.maxY);
    final clampedMaxY = sMaxY.clamp(parentBounds.minY, parentBounds.maxY);

    return GridBounds.fromMinMax(
      minX: clampedMinX,
      maxX: clampedMaxX,
      minY: clampedMinY,
      maxY: clampedMaxY,
    );
  }
}

/// Domain converter helper for bounding box coordinate transformations.
abstract class CoordinateConverter {
  /// Snaps a normalized [rect] to integer grid pixels and returns a normalized [Rect].
  static Rect alignRectToGrid(Rect rect, int gridSize) {
    return rect
        .toGridBounds(gridSize, ensureNonEmpty: true)
        .toNormalizedRect(gridSize);
  }
}
