import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';
import 'package:bad_pixel_art/logic/utils/coordinate_converter.dart';

void main() {
  group('CoordinateConverter & GridBounds tests', () {
    test('converts normalized Rect to GridBounds accurately', () {
      const rect = Rect.fromLTWH(0.25, 0.5, 0.5, 0.25);
      final bounds = rect.toGridBounds(16);

      expect(bounds.leftCol, equals(4));
      expect(bounds.topRow, equals(8));
      expect(bounds.rightCol, equals(12));
      expect(bounds.bottomRow, equals(12));
      expect(bounds.minX, equals(4));
      expect(bounds.maxX, equals(11));
      expect(bounds.minY, equals(8));
      expect(bounds.maxY, equals(11));
      expect(bounds.width, equals(8));
      expect(bounds.height, equals(4));
      expect(bounds.isNotEmpty, isTrue);
    });

    test('converts full canvas Rect.fromLTWH(0, 0, 1, 1) to GridBounds', () {
      const rect = Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
      final bounds = rect.toGridBounds(16);

      expect(bounds.leftCol, equals(0));
      expect(bounds.topRow, equals(0));
      expect(bounds.rightCol, equals(16));
      expect(bounds.bottomRow, equals(16));
      expect(bounds.minX, equals(0));
      expect(bounds.maxX, equals(15));
      expect(bounds.minY, equals(0));
      expect(bounds.maxY, equals(15));
    });

    test('handles clamping for out-of-bound normalized coordinates', () {
      const rect = Rect.fromLTWH(-0.2, -0.1, 1.5, 1.3);
      final bounds = rect.toGridBounds(16);

      expect(bounds.leftCol, equals(0));
      expect(bounds.topRow, equals(0));
      expect(bounds.rightCol, equals(16));
      expect(bounds.bottomRow, equals(16));
    });

    test('ensures non-empty bounds when ensureNonEmpty is true', () {
      const rect = Rect.fromLTWH(0.5, 0.5, 0.0, 0.0);
      final emptyBounds = rect.toGridBounds(16, ensureNonEmpty: false);
      expect(emptyBounds.leftCol, equals(8));
      expect(emptyBounds.rightCol, equals(8));
      expect(emptyBounds.isEmpty, isTrue);

      final nonEmptyBounds = rect.toGridBounds(16, ensureNonEmpty: true);
      expect(nonEmptyBounds.leftCol, equals(8));
      expect(nonEmptyBounds.rightCol, equals(9));
      expect(nonEmptyBounds.topRow, equals(8));
      expect(nonEmptyBounds.bottomRow, equals(9));
      expect(nonEmptyBounds.isNotEmpty, isTrue);
    });

    test('converts GridBounds back to normalized Rect', () {
      const bounds = GridBounds(
        leftCol: 4,
        topRow: 8,
        rightCol: 12,
        bottomRow: 12,
      );
      final rect = bounds.toNormalizedRect(16);

      expect(rect.left, equals(0.25));
      expect(rect.top, equals(0.5));
      expect(rect.width, equals(0.5));
      expect(rect.height, equals(0.25));
    });

    test('aligns Rect to grid using CoordinateConverter.alignRectToGrid', () {
      const rect = Rect.fromLTWH(0.24, 0.49, 0.51, 0.26);
      final aligned = CoordinateConverter.alignRectToGrid(rect, 16);

      expect(aligned.left, equals(0.25));
      expect(aligned.top, equals(0.5));
      expect(aligned.width, equals(0.5));
      expect(aligned.height, equals(0.25));
    });

    test('containsPixel correctly checks boundaries', () {
      const bounds = GridBounds(
        leftCol: 2,
        topRow: 4,
        rightCol: 6,
        bottomRow: 8,
      );

      expect(bounds.containsPixel(2, 4), isTrue);
      expect(bounds.containsPixel(5, 7), isTrue);
      expect(bounds.containsPixel(1, 4), isFalse);
      expect(bounds.containsPixel(6, 4), isFalse);
      expect(bounds.containsPixel(2, 8), isFalse);
    });

    test('FundamentalShape subGridBounds calculates relative bounds', () {
      final parentBounds = const GridBounds(
        leftCol: 4,
        topRow: 4,
        rightCol: 12,
        bottomRow: 12,
      );
      final shape = FundamentalShape(
        type: 'rectangle',
        relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 0.5, 0.5),
        description: 'top-left half',
      );

      final subBounds = shape.subGridBounds(parentBounds);
      expect(subBounds.minX, equals(4));
      expect(subBounds.maxX, equals(7));
      expect(subBounds.minY, equals(4));
      expect(subBounds.maxY, equals(7));
    });

    test('PixelArtComponent gridBounds returns component grid bounds', () {
      final comp = PixelArtComponent(
        name: 'test',
        description: 'test comp',
        relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 0.5, 1.0),
      );

      final bounds = comp.gridBounds(16);
      expect(bounds.leftCol, equals(0));
      expect(bounds.rightCol, equals(8));
      expect(bounds.topRow, equals(0));
      expect(bounds.bottomRow, equals(16));
    });

    test('0-width empty GridBounds reports empty range with maxX < minX', () {
      const emptyBounds = GridBounds(
        leftCol: 8,
        topRow: 8,
        rightCol: 8,
        bottomRow: 8,
      );

      expect(emptyBounds.isEmpty, isTrue);
      expect(emptyBounds.width, equals(0));
      expect(emptyBounds.height, equals(0));
      expect(emptyBounds.minX, equals(8));
      expect(emptyBounds.maxX, equals(7));
      expect(emptyBounds.minY, equals(8));
      expect(emptyBounds.maxY, equals(7));

      final recreated = GridBounds.fromMinMax(
        minX: emptyBounds.minX,
        maxX: emptyBounds.maxX,
        minY: emptyBounds.minY,
        maxY: emptyBounds.maxY,
      );
      expect(recreated, equals(emptyBounds));
    });

    test(
      'sub-grid bounds calculation within empty parent bounds does not overflow',
      () {
        const emptyParent = GridBounds(
          leftCol: 8,
          topRow: 8,
          rightCol: 8,
          bottomRow: 8,
        );
        const rect = Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
        final subBounds = rect.toSubGridBounds(emptyParent);

        expect(subBounds.isEmpty, isTrue);
        expect(subBounds.rightCol, lessThanOrEqualTo(emptyParent.rightCol));
        expect(subBounds.bottomRow, lessThanOrEqualTo(emptyParent.bottomRow));
        expect(subBounds.leftCol, equals(8));
        expect(subBounds.rightCol, equals(8));
      },
    );

    test(
      'out-of-bounds grid boundaries at gridSize clamp correctly when ensureNonEmpty is true',
      () {
        const rectAtBoundary = Rect.fromLTWH(1.0, 1.0, 0.0, 0.0);
        final boundsNonEmpty = rectAtBoundary.toGridBounds(
          16,
          ensureNonEmpty: true,
        );

        expect(boundsNonEmpty.leftCol, equals(15));
        expect(boundsNonEmpty.rightCol, equals(16));
        expect(boundsNonEmpty.topRow, equals(15));
        expect(boundsNonEmpty.bottomRow, equals(16));
        expect(boundsNonEmpty.minX, equals(15));
        expect(boundsNonEmpty.maxX, equals(15));
        expect(boundsNonEmpty.minY, equals(15));
        expect(boundsNonEmpty.maxY, equals(15));
        expect(boundsNonEmpty.isNotEmpty, isTrue);

        final boundsEmpty = rectAtBoundary.toGridBounds(
          16,
          ensureNonEmpty: false,
        );
        expect(boundsEmpty.leftCol, equals(16));
        expect(boundsEmpty.rightCol, equals(16));
        expect(boundsEmpty.minX, equals(16));
        expect(boundsEmpty.maxX, equals(15));
        expect(boundsEmpty.isEmpty, isTrue);
      },
    );
  });
}
