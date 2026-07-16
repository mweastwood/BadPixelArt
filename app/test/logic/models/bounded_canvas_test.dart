import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/models/bounded_canvas.dart';

void main() {
  group('BoundedCanvas Unit Tests', () {
    test('isWithinBounds returns correct values based on bounding box', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      // Bounding box: left 0.25, top 0.25, width 0.5, height 0.5.
      // With gridSize 8:
      // minX = (0.25 * 8).round() = 2
      // maxX = ((0.25 + 0.5) * 8).round() - 1 = 6 - 1 = 5
      // minY = (0.25 * 8).round() = 2
      // maxY = ((0.25 + 0.5) * 8).round() - 1 = 6 - 1 = 5
      final bounded = BoundedCanvas(
        grid: grid,
        boundingBox: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
        gridSize: 8,
      );

      expect(bounded.isWithinBounds(2, 2), isTrue);
      expect(bounded.isWithinBounds(5, 5), isTrue);
      expect(bounded.isWithinBounds(1, 2), isFalse); // X too small
      expect(bounded.isWithinBounds(6, 2), isFalse); // X too large
      expect(bounded.isWithinBounds(2, 1), isFalse); // Y too small
      expect(bounded.isWithinBounds(2, 6), isFalse); // Y too large
    });

    test('setPixel only modifies grid within bounds', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      final bounded = BoundedCanvas(
        grid: grid,
        boundingBox: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
        gridSize: 8,
      );

      // Set pixel inside bounds
      bounded.setPixel(3, 3, 5);
      expect(grid[3][3], equals(5));

      // Attempt to set pixel outside bounds
      bounded.setPixel(1, 1, 3);
      expect(grid[1][1], equals(0));

      // Attempt to set pixel out of grid bounds (should not crash)
      bounded.setPixel(-1, 3, 2);
      bounded.setPixel(10, 3, 2);
    });

    test('executeClamped only copies modified pixels within bounds', () {
      final grid = List.generate(8, (_) => List.filled(8, 0));
      final bounded = BoundedCanvas(
        grid: grid,
        boundingBox: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
        gridSize: 8,
      );

      bounded.executeClamped((tempGrid) {
        // Modify pixel inside bounds in the temp grid
        tempGrid[3][3] = 4;
        // Modify pixel outside bounds in the temp grid
        tempGrid[1][1] = 9;
      });

      expect(grid[3][3], equals(4)); // Within bounds: copied
      expect(grid[1][1], equals(0)); // Outside bounds: not copied
    });
  });
}
