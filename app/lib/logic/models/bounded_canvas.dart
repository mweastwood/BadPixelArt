import 'package:flutter/material.dart';
import '../utils/coordinate_converter.dart';

class BoundedCanvas {
  final List<List<int>> grid;
  final Rect boundingBox;
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
  bool isWithinBounds(int x, int y) {
    return bounds.containsPixel(x, y);
  }

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
