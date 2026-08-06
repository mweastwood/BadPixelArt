import 'dart:math' as math;
import 'package:flutter/material.dart';

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
  }) : hasInterior = hasInterior ?? _calculateHasInterior(grid),
       minP = minP ?? _calculateMinP(grid, gradientAngle),
       maxP = maxP ?? _calculateMaxP(grid, gradientAngle);

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

  static double _calculateMinP(List<List<int>>? grid, double gradientAngle) {
    if (grid == null) return double.infinity;
    final size = grid.length;
    final rad = gradientAngle * (math.pi / 180.0);
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);

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

  static double _calculateMaxP(List<List<int>>? grid, double gradientAngle) {
    if (grid == null) return -double.infinity;
    final size = grid.length;
    final rad = gradientAngle * (math.pi / 180.0);
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);

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

    final rad = gradientAngle * (math.pi / 180.0);
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);

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
    final bbox = relativeBoundingBox;
    final leftCol = (bbox.left * gridSize).round().clamp(0, gridSize - 1);
    final topRow = (bbox.top * gridSize).round().clamp(0, gridSize - 1);
    final rightCol = ((bbox.left + bbox.width) * gridSize).round().clamp(
      0,
      gridSize,
    );
    final bottomRow = ((bbox.top + bbox.height) * gridSize).round().clamp(
      0,
      gridSize,
    );

    for (int y = topRow; y < bottomRow; y++) {
      for (int x = leftCol; x < rightCol; x++) {
        newGrid[y][x] = 1;
      }
    }
    return copyWith(grid: newGrid);
  }

  List<List<int>>? getOutlineGrid() {
    if (grid == null) return null;
    final size = grid!.length;
    final outline = List.generate(size, (_) => List.filled(size, 0));
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (grid![y][x] > 0) {
          bool hasBackgroundNeighbor = false;
          if (y == 0 || y == size - 1 || x == 0 || x == size - 1) {
            hasBackgroundNeighbor = true;
          } else {
            if (grid![y - 1][x] == 0 ||
                grid![y + 1][x] == 0 ||
                grid![y][x - 1] == 0 ||
                grid![y][x + 1] == 0) {
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
}
