import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/coordinate_converter.dart';

class FundamentalShape {
  final String type; // 'rectangle', 'circle', 'triangle'
  final Rect
  relativeBoundingBox; // Relative to parent component's bounding box, from 0.0 to 1.0
  final String description;

  FundamentalShape({
    required this.type,
    required this.relativeBoundingBox,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'relativeBoundingBox': {
        'left': relativeBoundingBox.left,
        'top': relativeBoundingBox.top,
        'width': relativeBoundingBox.width,
        'height': relativeBoundingBox.height,
      },
      'description': description,
    };
  }

  factory FundamentalShape.fromJson(Map<String, dynamic> json) {
    final bbox = json['relativeBoundingBox'] as Map<String, dynamic>;
    return FundamentalShape(
      type: json['type'] as String,
      description: json['description'] as String,
      relativeBoundingBox: Rect.fromLTWH(
        (bbox['left'] as num).toDouble(),
        (bbox['top'] as num).toDouble(),
        (bbox['width'] as num).toDouble(),
        (bbox['height'] as num).toDouble(),
      ),
    );
  }

  /// Returns integer pixel grid bounds for this shape relative to [parentBounds].
  ///
  /// If [ensureNonEmpty] is `true`, ensures non-empty sub-grid bounds within non-empty [parentBounds].
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
  final Rect relativeBoundingBox; // Normalized bounding box (0.0 to 1.0)
  final List<List<int>>?
  grid; // Component specific sketch grid (0 = empty, 1 = filled volume)
  final List<FundamentalShape>
  shapes; // Fundamental geometric shapes composing this component
  final Color? fillColor;
  final Color? fillColor2;
  final double gradientAngle; // Angle in degrees (0..360)
  final Color? outlineColor;
  final bool isSculpted;
  final bool hasInterior;
  final double minP;
  final double maxP;
  final List<List<int>>? outlineGrid;
  final double cosA;
  final double sinA;

  PixelArtComponent({
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
    bool? hasInterior,
    double? minP,
    double? maxP,
    List<List<int>>? outlineGrid,
    double? cosA,
    double? sinA,
  }) : hasInterior = hasInterior ?? _calculateHasInterior(grid),
       cosA = cosA ?? math.cos(gradientAngle * (math.pi / 180.0)),
       sinA = sinA ?? math.sin(gradientAngle * (math.pi / 180.0)),
       minP =
           minP ??
           _calculateMinP(
             grid,
             cosA ?? math.cos(gradientAngle * (math.pi / 180.0)),
             sinA ?? math.sin(gradientAngle * (math.pi / 180.0)),
           ),
       maxP =
           maxP ??
           _calculateMaxP(
             grid,
             cosA ?? math.cos(gradientAngle * (math.pi / 180.0)),
             sinA ?? math.sin(gradientAngle * (math.pi / 180.0)),
           ),
       outlineGrid = outlineGrid ?? _calculateOutlineGrid(grid);

  /// Returns integer pixel grid bounds for this component for a given [gridSize].
  ///
  /// If [ensureNonEmpty] is `true`, ensures non-empty grid bounds (at least 1 pixel width and height).
  GridBounds gridBounds(int gridSize, {bool ensureNonEmpty = false}) {
    return relativeBoundingBox.toGridBounds(
      gridSize,
      ensureNonEmpty: ensureNonEmpty,
    );
  }

  static Color getColor(int index) {
    final colors = [
      Colors.blue,
      Colors.amber,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.orange,
    ];
    return colors[index % colors.length];
  }

  static bool _calculateHasInterior(List<List<int>>? grid) {
    if (grid == null) return false;
    final size = grid.length;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (grid[y][x] > 0) {
          if (y > 0 && y < size - 1 && x > 0 && x < size - 1) {
            if (grid[y - 1][x] > 0 &&
                grid[y + 1][x] > 0 &&
                grid[y][x - 1] > 0 &&
                grid[y][x + 1] > 0) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  static double _calculateMinP(
    List<List<int>>? grid,
    double cosA,
    double sinA,
  ) {
    if (grid == null) return double.infinity;
    final size = grid.length;

    double minP = double.infinity;
    for (int py = 0; py < size; py++) {
      for (int px = 0; px < size; px++) {
        if (grid[py][px] > 0) {
          final p = px * cosA + py * sinA;
          if (p < minP) minP = p;
        }
      }
    }
    return minP;
  }

  static double _calculateMaxP(
    List<List<int>>? grid,
    double cosA,
    double sinA,
  ) {
    if (grid == null) return -double.infinity;
    final size = grid.length;

    double maxP = -double.infinity;
    for (int py = 0; py < size; py++) {
      for (int px = 0; px < size; px++) {
        if (grid[py][px] > 0) {
          final p = px * cosA + py * sinA;
          if (p > maxP) maxP = p;
        }
      }
    }
    return maxP;
  }

  static const List<List<double>> bayerMatrix4x4 = [
    [0.0 / 16, 8.0 / 16, 2.0 / 16, 10.0 / 16],
    [12.0 / 16, 4.0 / 16, 14.0 / 16, 6.0 / 16],
    [3.0 / 16, 11.0 / 16, 1.0 / 16, 9.0 / 16],
    [15.0 / 16, 7.0 / 16, 13.0 / 16, 5.0 / 16],
  ];

  Color? getPixelFillColor(int x, int y) {
    if (grid == null || grid![y][x] == 0) return null;
    if (fillColor == null) return null;
    if (fillColor2 == null || !hasInterior) return fillColor;
    if (maxP <= minP) return fillColor;

    final currentP = x * cosA + y * sinA;
    final t = ((currentP - minP) / (maxP - minP)).clamp(0.0, 1.0);
    final ditherThreshold = bayerMatrix4x4[y % 4][x % 4];

    return t > ditherThreshold ? fillColor2 : fillColor;
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
    final size = grid.length;
    final outline = List.generate(size, (_) => List.filled(size, 0));
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (grid[y][x] > 0) {
          bool hasBackgroundNeighbor = false;
          if (y == 0 || y == size - 1 || x == 0 || x == size - 1) {
            hasBackgroundNeighbor = true;
          } else {
            if (grid[y - 1][x] == 0 ||
                grid[y + 1][x] == 0 ||
                grid[y][x - 1] == 0 ||
                grid[y][x + 1] == 0) {
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
    Rect? relativeBoundingBox,
    List<List<int>>? grid,
    List<FundamentalShape>? shapes,
    Color? Function()? fillColor,
    Color? Function()? fillColor2,
    double? gradientAngle,
    Color? Function()? outlineColor,
    bool? isSculpted,
    bool? hasInterior,
    double? minP,
    double? maxP,
    List<List<int>>? outlineGrid,
    double? cosA,
    double? sinA,
  }) {
    final newGrid = grid ?? this.grid;
    final newGradientAngle = gradientAngle ?? this.gradientAngle;
    final gridChanged = grid != null && grid != this.grid;
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
      hasInterior: hasInterior ?? (gridChanged ? null : this.hasInterior),
      minP: minP ?? ((gridChanged || angleChanged) ? null : this.minP),
      maxP: maxP ?? ((gridChanged || angleChanged) ? null : this.maxP),
      outlineGrid: outlineGrid ?? (gridChanged ? null : this.outlineGrid),
      cosA: cosA ?? (angleChanged ? null : this.cosA),
      sinA: sinA ?? (angleChanged ? null : this.sinA),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'relativeBoundingBox': {
        'left': relativeBoundingBox.left,
        'top': relativeBoundingBox.top,
        'width': relativeBoundingBox.width,
        'height': relativeBoundingBox.height,
      },
      if (grid != null) 'grid': grid,
      'shapes': shapes.map((s) => s.toJson()).toList(),
      if (fillColor != null) 'fillColor': fillColor!.toARGB32(),
      if (fillColor2 != null) 'fillColor2': fillColor2!.toARGB32(),
      'gradientAngle': gradientAngle,
      if (outlineColor != null) 'outlineColor': outlineColor!.toARGB32(),
      'isSculpted': isSculpted,
    };
  }

  factory PixelArtComponent.fromJson(Map<String, dynamic> json) {
    final bbox = json['relativeBoundingBox'] as Map<String, dynamic>;
    final gridRaw = json['grid'] as List?;
    List<List<int>>? parsedGrid;
    if (gridRaw != null) {
      parsedGrid = gridRaw.map((row) => List<int>.from(row as List)).toList();
    }
    final shapesRaw = json['shapes'] as List? ?? [];
    final parsedShapes = shapesRaw
        .map((s) => FundamentalShape.fromJson(s as Map<String, dynamic>))
        .toList();
    final fillColorRaw = json['fillColor'] as int?;
    final fillColor2Raw = json['fillColor2'] as int?;
    final gradientAngleRaw = json['gradientAngle'] as num?;
    final outlineColorRaw = json['outlineColor'] as int?;
    final isSculptedRaw = json['isSculpted'] as bool?;

    return PixelArtComponent(
      name: json['name'] as String,
      description: json['description'] as String,
      relativeBoundingBox: Rect.fromLTWH(
        (bbox['left'] as num).toDouble(),
        (bbox['top'] as num).toDouble(),
        (bbox['width'] as num).toDouble(),
        (bbox['height'] as num).toDouble(),
      ),
      grid: parsedGrid,
      shapes: parsedShapes,
      fillColor: fillColorRaw != null ? Color(fillColorRaw) : null,
      fillColor2: fillColor2Raw != null ? Color(fillColor2Raw) : null,
      gradientAngle: gradientAngleRaw?.toDouble() ?? 90.0,
      outlineColor: outlineColorRaw != null ? Color(outlineColorRaw) : null,
      isSculpted: isSculptedRaw ?? (parsedGrid != null),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PixelArtComponent) return false;
    return name == other.name &&
        description == other.description &&
        relativeBoundingBox == other.relativeBoundingBox &&
        _gridEquals(grid, other.grid) &&
        listEquals(shapes, other.shapes) &&
        fillColor == other.fillColor &&
        fillColor2 == other.fillColor2 &&
        gradientAngle == other.gradientAngle &&
        outlineColor == other.outlineColor &&
        isSculpted == other.isSculpted &&
        hasInterior == other.hasInterior &&
        minP == other.minP &&
        maxP == other.maxP &&
        _gridEquals(outlineGrid, other.outlineGrid) &&
        cosA == other.cosA &&
        sinA == other.sinA;
  }

  @override
  int get hashCode => Object.hash(
    Object.hash(
      name,
      description,
      relativeBoundingBox,
      grid != null ? Object.hashAll(grid!.map(Object.hashAll)) : null,
      Object.hashAll(shapes),
      fillColor,
      fillColor2,
      gradientAngle,
      outlineColor,
      isSculpted,
    ),
    Object.hash(
      hasInterior,
      minP,
      maxP,
      outlineGrid != null
          ? Object.hashAll(outlineGrid!.map(Object.hashAll))
          : null,
      cosA,
      sinA,
    ),
  );
}

bool _gridEquals(List<List<int>>? a, List<List<int>>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (!listEquals(a[i], b[i])) return false;
  }
  return true;
}
