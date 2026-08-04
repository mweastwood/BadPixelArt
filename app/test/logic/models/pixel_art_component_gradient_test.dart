import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';

void main() {
  group('PixelArtComponent Hatching Gradient & Interior Tests', () {
    test(
      'hasInterior returns false for thin lines/hollow grids and true for filled volumes',
      () {
        // Thin 1-pixel vertical line (16x16 grid)
        final thinGrid = List.generate(
          16,
          (y) =>
              List.generate(16, (x) => (x == 5 && y >= 2 && y <= 12) ? 1 : 0),
        );
        final thinComp = PixelArtComponent(
          name: 'line',
          description: 'line',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          grid: thinGrid,
        );
        expect(thinComp.hasInterior, isFalse);

        // Hollow 3x3 box (perimeter is filled, interior (2,2) is 0)
        final hollowGrid = List.generate(
          16,
          (y) => List.generate(16, (x) {
            if (x >= 1 && x <= 3 && y >= 1 && y <= 3) {
              if (x == 2 && y == 2) return 0;
              return 1;
            }
            return 0;
          }),
        );
        final hollowComp = PixelArtComponent(
          name: 'hollow',
          description: 'hollow box',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          grid: hollowGrid,
        );
        expect(hollowComp.hasInterior, isFalse);

        // Solid 4x4 box (pixels at (2,2), (2,3), (3,2), (3,3) are surrounded on all 4 sides)
        final solidGrid = List.generate(
          16,
          (y) => List.generate(
            16,
            (x) => (x >= 1 && x <= 4 && y >= 1 && y <= 4) ? 1 : 0,
          ),
        );
        final solidComp = PixelArtComponent(
          name: 'solid',
          description: 'solid box',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          grid: solidGrid,
        );
        expect(solidComp.hasInterior, isTrue);
      },
    );

    test(
      'getPixelFillColor calculates hatched gradient dither between 2 colors',
      () {
        final solidGrid = List.generate(
          16,
          (y) => List.generate(
            16,
            (x) => (x >= 1 && x <= 6 && y >= 1 && y <= 6) ? 1 : 0,
          ),
        );
        final comp = PixelArtComponent(
          name: 'box',
          description: 'box',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          grid: solidGrid,
          fillColor: Colors.blue,
          fillColor2: Colors.red,
          gradientAngle: 90.0, // Top to bottom gradient
        );

        // Top pixels (smaller Y) should evaluate closer to Color A (blue)
        // Bottom pixels (larger Y) should evaluate closer to Color B (red)
        final topColor = comp.getPixelFillColor(1, 1);
        final bottomColor = comp.getPixelFillColor(6, 6);

        expect(topColor, equals(Colors.blue));
        expect(bottomColor, equals(Colors.red));
      },
    );

    test(
      'toJson and fromJson serialize fillColor2 and gradientAngle correctly',
      () {
        final comp = PixelArtComponent(
          name: 'sword_blade',
          description: 'blade',
          relativeBoundingBox: const Rect.fromLTWH(0.2, 0.1, 0.6, 0.8),
          fillColor: Colors.blue,
          fillColor2: Colors.amber,
          gradientAngle: 135.0,
          outlineColor: Colors.black,
        );

        final json = comp.toJson();
        expect(json['fillColor2'], equals(Colors.amber.toARGB32()));
        expect(json['gradientAngle'], equals(135.0));

        final restored = PixelArtComponent.fromJson(json);
        expect(
          restored.fillColor2?.toARGB32(),
          equals(Colors.amber.toARGB32()),
        );
        expect(restored.gradientAngle, equals(135.0));
      },
    );
  });
}
