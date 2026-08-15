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

    test(
      'pre-computes outlineGrid, cosA, and sinA on construction and preserves in copyWith',
      () {
        final grid = [
          [0, 0, 0],
          [0, 1, 0],
          [0, 0, 0],
        ];
        final comp = PixelArtComponent(
          name: 'dot',
          description: 'dot',
          relativeBoundingBox: Rect.zero,
          grid: grid,
          gradientAngle: 0.0,
        );

        expect(comp.outlineGrid, isNotNull);
        expect(comp.outlineGrid![1][1], equals(1));
        expect(identical(comp.getOutlineGrid(), comp.outlineGrid), isTrue);
        expect(comp.cosA, closeTo(1.0, 1e-6));
        expect(comp.sinA, closeTo(0.0, 1e-6));

        // copyWith without modifying grid or angle preserves cached instances
        final copied = comp.copyWith(name: 'new_dot');
        expect(identical(copied.outlineGrid, comp.outlineGrid), isTrue);
        expect(copied.cosA, equals(comp.cosA));
        expect(copied.sinA, equals(comp.sinA));

        // copyWith with new angle recomputes cosA and sinA
        final rotated = comp.copyWith(gradientAngle: 90.0);
        expect(rotated.cosA, closeTo(0.0, 1e-6));
        expect(rotated.sinA, closeTo(1.0, 1e-6));
        expect(identical(rotated.outlineGrid, comp.outlineGrid), isTrue);

        // copyWith with new grid recomputes outlineGrid
        final newGrid = [
          [1, 1, 1],
          [1, 1, 1],
          [1, 1, 1],
        ];
        final updatedGrid = comp.copyWith(grid: newGrid);
        expect(identical(updatedGrid.outlineGrid, comp.outlineGrid), isFalse);
        expect(updatedGrid.outlineGrid![0][0], equals(1));
        expect(updatedGrid.outlineGrid![1][1], equals(0)); // interior cell
      },
    );

    test('FundamentalShape equality and hashCode', () {
      final shape1 = FundamentalShape(
        type: 'circle',
        relativeBoundingBox: const Rect.fromLTWH(0.1, 0.2, 0.3, 0.4),
        description: 'circle',
      );
      final shape2 = FundamentalShape(
        type: 'circle',
        relativeBoundingBox: const Rect.fromLTWH(0.1, 0.2, 0.3, 0.4),
        description: 'circle',
      );
      final shapeDiffType = FundamentalShape(
        type: 'rect',
        relativeBoundingBox: const Rect.fromLTWH(0.1, 0.2, 0.3, 0.4),
        description: 'circle',
      );
      final shapeDiffBox = FundamentalShape(
        type: 'circle',
        relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 0.5, 0.5),
        description: 'circle',
      );
      final shapeDiffDesc = FundamentalShape(
        type: 'circle',
        relativeBoundingBox: const Rect.fromLTWH(0.1, 0.2, 0.3, 0.4),
        description: 'other circle',
      );

      expect(shape1, equals(shape2));
      expect(shape1.hashCode, equals(shape2.hashCode));
      expect(shape1, isNot(equals(shapeDiffType)));
      expect(shape1, isNot(equals(shapeDiffBox)));
      expect(shape1, isNot(equals(shapeDiffDesc)));
    });

    test('PixelArtComponent equality and hashCode', () {
      final shape = FundamentalShape(
        type: 'rectangle',
        relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
        description: 'shape',
      );
      final comp1 = PixelArtComponent(
        name: 'Head',
        description: 'character head',
        relativeBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
        grid: [
          [0, 1],
          [1, 0],
        ],
        shapes: [shape],
        fillColor: Colors.blue,
        fillColor2: Colors.red,
        gradientAngle: 45.0,
        outlineColor: Colors.black,
        isSculpted: true,
      );
      final comp2 = PixelArtComponent(
        name: 'Head',
        description: 'character head',
        relativeBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
        grid: [
          [0, 1],
          [1, 0],
        ],
        shapes: [
          FundamentalShape(
            type: 'rectangle',
            relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
            description: 'shape',
          ),
        ],
        fillColor: Colors.blue,
        fillColor2: Colors.red,
        gradientAngle: 45.0,
        outlineColor: Colors.black,
        isSculpted: true,
      );

      expect(comp1, equals(comp2));
      expect(comp1.hashCode, equals(comp2.hashCode));

      // Test different properties
      expect(comp1, isNot(equals(comp1.copyWith(name: 'Body'))));
      expect(comp1, isNot(equals(comp1.copyWith(description: 'diff'))));
      expect(
        comp1,
        isNot(
          equals(
            comp1.copyWith(
              relativeBoundingBox: const Rect.fromLTWH(0.1, 0.1, 0.5, 0.5),
            ),
          ),
        ),
      );
      expect(
        comp1,
        isNot(
          equals(
            comp1.copyWith(
              grid: [
                [1, 1],
                [1, 1],
              ],
            ),
          ),
        ),
      );
      expect(comp1, isNot(equals(comp1.copyWith(shapes: []))));
      expect(
        comp1,
        isNot(equals(comp1.copyWith(fillColor: () => Colors.green))),
      );
      expect(
        comp1,
        isNot(equals(comp1.copyWith(fillColor2: () => Colors.yellow))),
      );
      expect(comp1, isNot(equals(comp1.copyWith(gradientAngle: 90.0))));
      expect(
        comp1,
        isNot(equals(comp1.copyWith(outlineColor: () => Colors.white))),
      );
      expect(comp1, isNot(equals(comp1.copyWith(isSculpted: false))));
    });
  });
}
