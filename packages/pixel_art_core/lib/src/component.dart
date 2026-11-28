import 'dart:math' as math;

import 'coordinate_converter.dart';
import 'types.dart';

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
