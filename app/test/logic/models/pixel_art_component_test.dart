import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';

void main() {
  group('PixelArtComponent Unit Tests', () {
    test('FundamentalShape toJson / fromJson matches', () {
      final shape = FundamentalShape(
        type: 'circle',
        relativeBoundingBox: const Rect.fromLTWH(0.1, 0.2, 0.3, 0.4),
        description: 'a circle shape',
      );

      final json = shape.toJson();
      final decoded = FundamentalShape.fromJson(json);

      expect(decoded.type, equals('circle'));
      expect(decoded.description, equals('a circle shape'));
      expect(
        decoded.relativeBoundingBox,
        equals(const Rect.fromLTWH(0.1, 0.2, 0.3, 0.4)),
      );
    });

    test('PixelArtComponent initializeDefaultGrid sets correct values', () {
      final comp = PixelArtComponent(
        name: 'test_component',
        description: 'a component',
        relativeBoundingBox: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
      );

      final initialized = comp.initializeDefaultGrid(8);
      expect(initialized.grid, isNotNull);

      // Verify a 8x8 grid has a 4x4 filled center region
      // normalized 0.25 * 8 = 2, width 0.5 * 8 = 4 => cols 2, 3, 4, 5
      expect(initialized.grid![0][0], equals(0));
      expect(initialized.grid![2][2], equals(1));
      expect(initialized.grid![5][5], equals(1));
      expect(initialized.grid![6][6], equals(0));
    });

    test('PixelArtComponent getOutlineGrid computes outline correctly', () {
      final grid = [
        [0, 0, 0],
        [0, 1, 0],
        [0, 0, 0],
      ];
      final comp = PixelArtComponent(
        name: 'center_dot',
        description: 'dot',
        relativeBoundingBox: Rect.zero,
        grid: grid,
      );

      final outline = comp.getOutlineGrid();
      expect(outline, isNotNull);
      // Since y=1, x=1 is next to y=0 which is background 0, it should be outline 1
      expect(outline![1][1], equals(1));
    });

    test('PixelArtComponent toJson / fromJson matches including colors', () {
      final comp = PixelArtComponent(
        name: 'Blade',
        description: 'sharp blade',
        relativeBoundingBox: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
        fillColor: Colors.red,
        outlineColor: Colors.black,
        shapes: [
          FundamentalShape(
            type: 'rectangle',
            relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
            description: 'blade box',
          ),
        ],
      );

      final json = comp.toJson();
      final decoded = PixelArtComponent.fromJson(json);

      expect(decoded.name, equals('Blade'));
      expect(decoded.description, equals('sharp blade'));
      expect(decoded.fillColor!.toARGB32(), equals(Colors.red.toARGB32()));
      expect(decoded.outlineColor!.toARGB32(), equals(Colors.black.toARGB32()));
      expect(decoded.shapes, hasLength(1));
      expect(decoded.shapes.first.type, equals('rectangle'));
    });
  });
}
