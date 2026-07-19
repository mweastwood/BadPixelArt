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

  PixelArtComponent({
    required this.name,
    required this.description,
    required this.relativeBoundingBox,
    this.grid,
    this.shapes = const [],
  });

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
  }) {
    return PixelArtComponent(
      name: name ?? this.name,
      description: description ?? this.description,
      relativeBoundingBox: relativeBoundingBox ?? this.relativeBoundingBox,
      grid: grid ?? this.grid,
      shapes: shapes ?? this.shapes,
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
    );
  }
}
