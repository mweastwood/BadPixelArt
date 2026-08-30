import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/controllers/component_bounding_box_gesture_handler.dart';
import 'package:bad_pixel_art/logic/models/drag_handle.dart';

void main() {
  group('ComponentBoundingBoxGestureHandler Unit Tests', () {
    const handler = ComponentBoundingBoxGestureHandler();

    group('hitTest', () {
      const rect = Rect.fromLTWH(100.0, 100.0, 200.0, 200.0);

      test('detects corner handles within threshold', () {
        expect(
          handler.hitTest(const Offset(100.0, 100.0), rect),
          equals(DragHandle.topLeft),
        );
        expect(
          handler.hitTest(const Offset(95.0, 95.0), rect),
          equals(DragHandle.topLeft),
        );

        expect(
          handler.hitTest(const Offset(300.0, 100.0), rect),
          equals(DragHandle.topRight),
        );
        expect(
          handler.hitTest(const Offset(305.0, 95.0), rect),
          equals(DragHandle.topRight),
        );

        expect(
          handler.hitTest(const Offset(100.0, 300.0), rect),
          equals(DragHandle.bottomLeft),
        );
        expect(
          handler.hitTest(const Offset(95.0, 305.0), rect),
          equals(DragHandle.bottomLeft),
        );

        expect(
          handler.hitTest(const Offset(300.0, 300.0), rect),
          equals(DragHandle.bottomRight),
        );
        expect(
          handler.hitTest(const Offset(305.0, 305.0), rect),
          equals(DragHandle.bottomRight),
        );
      });

      test('detects edge midpoint handles within threshold', () {
        // Top edge midpoint: (200, 100)
        expect(
          handler.hitTest(const Offset(200.0, 100.0), rect),
          equals(DragHandle.top),
        );
        expect(
          handler.hitTest(const Offset(200.0, 95.0), rect),
          equals(DragHandle.top),
        );

        // Bottom edge midpoint: (200, 300)
        expect(
          handler.hitTest(const Offset(200.0, 300.0), rect),
          equals(DragHandle.bottom),
        );
        expect(
          handler.hitTest(const Offset(200.0, 305.0), rect),
          equals(DragHandle.bottom),
        );

        // Left edge midpoint: (100, 200)
        expect(
          handler.hitTest(const Offset(100.0, 200.0), rect),
          equals(DragHandle.left),
        );
        expect(
          handler.hitTest(const Offset(95.0, 200.0), rect),
          equals(DragHandle.left),
        );

        // Right edge midpoint: (300, 200)
        expect(
          handler.hitTest(const Offset(300.0, 200.0), rect),
          equals(DragHandle.right),
        );
        expect(
          handler.hitTest(const Offset(305.0, 200.0), rect),
          equals(DragHandle.right),
        );
      });

      test('detects center handle inside rect away from handles', () {
        expect(
          handler.hitTest(const Offset(200.0, 200.0), rect),
          equals(DragHandle.center),
        );
      });

      test('detects none outside rect away from handles', () {
        expect(
          handler.hitTest(const Offset(50.0, 50.0), rect),
          equals(DragHandle.none),
        );
        expect(
          handler.hitTest(const Offset(400.0, 400.0), rect),
          equals(DragHandle.none),
        );
      });

      test('respects custom threshold', () {
        expect(
          handler.hitTest(const Offset(105.0, 105.0), rect, threshold: 2.0),
          equals(DragHandle.center),
        );
      });
    });

    group('snapToGrid', () {
      test('snaps exact and nearby values to grid lines', () {
        expect(handler.snapToGrid(0.25, 4), equals(0.25));
        expect(handler.snapToGrid(0.26, 4), equals(0.25));
        expect(handler.snapToGrid(0.40, 4), equals(0.50));
      });

      test('clamps snap output to [0.0, 1.0]', () {
        expect(handler.snapToGrid(-0.2, 8), equals(0.0));
        expect(handler.snapToGrid(1.5, 8), equals(1.0));
      });

      test('handles non-positive gridSize safely', () {
        expect(handler.snapToGrid(0.5, 0), equals(0.5));
        expect(handler.snapToGrid(-0.1, -1), equals(0.0));
        expect(handler.snapToGrid(1.2, -5), equals(1.0));
      });
    });

    group('applyDelta', () {
      const startRect = Rect.fromLTWH(0.25, 0.25, 0.5, 0.5);
      const canvasSize = 100.0;
      const gridSize = 8; // minSize = 1/8 = 0.125

      test(
        'returns null for DragHandle.none, canvasSize <= 0, or gridSize <= 0',
        () {
          expect(
            handler.applyDelta(
              handle: DragHandle.none,
              startRect: startRect,
              pixelDelta: const Offset(10.0, 10.0),
              canvasSize: canvasSize,
              gridSize: gridSize,
            ),
            isNull,
          );

          expect(
            handler.applyDelta(
              handle: DragHandle.topLeft,
              startRect: startRect,
              pixelDelta: const Offset(10.0, 10.0),
              canvasSize: 0.0,
              gridSize: gridSize,
            ),
            isNull,
          );

          expect(
            handler.applyDelta(
              handle: DragHandle.topLeft,
              startRect: startRect,
              pixelDelta: const Offset(10.0, 10.0),
              canvasSize: canvasSize,
              gridSize: 0,
            ),
            isNull,
          );
        },
      );

      test('applies topLeft drag and enforces minSize on width and height', () {
        // Delta (12.5, 12.5) -> normalized delta (+0.125, +0.125)
        // startRect: left=0.25, top=0.25, right=0.75, bottom=0.75
        // newLeft = snapToGrid(0.375) = 0.375
        // newTop = snapToGrid(0.375) = 0.375
        // newWidth = 0.75 - 0.375 = 0.375
        // newHeight = 0.75 - 0.375 = 0.375
        final result = handler.applyDelta(
          handle: DragHandle.topLeft,
          startRect: startRect,
          pixelDelta: const Offset(12.5, 12.5),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(result, equals(const Rect.fromLTWH(0.375, 0.375, 0.375, 0.375)));

        // Large positive delta causing collapse past minSize
        final collapsed = handler.applyDelta(
          handle: DragHandle.topLeft,
          startRect: startRect,
          pixelDelta: const Offset(80.0, 80.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        // minSize = 0.125, right=0.75 => newLeft = 0.75 - 0.125 = 0.625, newWidth = 0.125
        // bottom=0.75 => newTop = 0.75 - 0.125 = 0.625, newHeight = 0.125
        expect(
          collapsed,
          equals(const Rect.fromLTWH(0.625, 0.625, 0.125, 0.125)),
        );

        // Only width collapsed
        final widthCollapsed = handler.applyDelta(
          handle: DragHandle.topLeft,
          startRect: startRect,
          pixelDelta: const Offset(80.0, 0.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(widthCollapsed!.width, equals(0.125));
        expect(widthCollapsed.left, equals(0.625));
        expect(widthCollapsed.top, equals(0.25));

        // Only height collapsed
        final heightCollapsed = handler.applyDelta(
          handle: DragHandle.topLeft,
          startRect: startRect,
          pixelDelta: const Offset(0.0, 80.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(heightCollapsed!.height, equals(0.125));
        expect(heightCollapsed.top, equals(0.625));
        expect(heightCollapsed.left, equals(0.25));
      });

      test('applies topRight drag and enforces minSize', () {
        // Delta (12.5, 12.5)
        // startRect: left=0.25, top=0.25, width=0.5, bottom=0.75
        // newTop = snapToGrid(0.375) = 0.375
        // newWidth = snapToGrid(0.5 + 0.125) = snapToGrid(0.625) = 0.625
        // newHeight = 0.75 - 0.375 = 0.375
        final result = handler.applyDelta(
          handle: DragHandle.topRight,
          startRect: startRect,
          pixelDelta: const Offset(12.5, 12.5),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(result, equals(const Rect.fromLTWH(0.25, 0.375, 0.625, 0.375)));

        // Negative width delta and positive height collapse
        final collapsed = handler.applyDelta(
          handle: DragHandle.topRight,
          startRect: startRect,
          pixelDelta: const Offset(-80.0, 80.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(
          collapsed,
          equals(const Rect.fromLTWH(0.25, 0.625, 0.125, 0.125)),
        );
      });

      test('applies bottomLeft drag and enforces minSize', () {
        // Delta (12.5, 12.5)
        // newLeft = snapToGrid(0.375) = 0.375
        // newWidth = 0.75 - 0.375 = 0.375
        // newHeight = snapToGrid(0.5 + 0.125) = 0.625
        final result = handler.applyDelta(
          handle: DragHandle.bottomLeft,
          startRect: startRect,
          pixelDelta: const Offset(12.5, 12.5),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(result, equals(const Rect.fromLTWH(0.375, 0.25, 0.375, 0.625)));

        // Large delta collapsing width and height
        final collapsed = handler.applyDelta(
          handle: DragHandle.bottomLeft,
          startRect: startRect,
          pixelDelta: const Offset(80.0, -80.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(
          collapsed,
          equals(const Rect.fromLTWH(0.625, 0.25, 0.125, 0.125)),
        );
      });

      test('applies bottomRight drag and enforces minSize', () {
        final result = handler.applyDelta(
          handle: DragHandle.bottomRight,
          startRect: startRect,
          pixelDelta: const Offset(12.5, 12.5),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(result, equals(const Rect.fromLTWH(0.25, 0.25, 0.625, 0.625)));

        final collapsed = handler.applyDelta(
          handle: DragHandle.bottomRight,
          startRect: startRect,
          pixelDelta: const Offset(-80.0, -80.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(
          collapsed,
          equals(const Rect.fromLTWH(0.25, 0.25, 0.125, 0.125)),
        );
      });

      test('applies top drag and enforces minSize', () {
        final result = handler.applyDelta(
          handle: DragHandle.top,
          startRect: startRect,
          pixelDelta: const Offset(0.0, 12.5),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(result, equals(const Rect.fromLTWH(0.25, 0.375, 0.5, 0.375)));

        final collapsed = handler.applyDelta(
          handle: DragHandle.top,
          startRect: startRect,
          pixelDelta: const Offset(0.0, 80.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(collapsed, equals(const Rect.fromLTWH(0.25, 0.625, 0.5, 0.125)));
      });

      test('applies bottom drag and enforces minSize', () {
        final result = handler.applyDelta(
          handle: DragHandle.bottom,
          startRect: startRect,
          pixelDelta: const Offset(0.0, 12.5),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(result, equals(const Rect.fromLTWH(0.25, 0.25, 0.5, 0.625)));

        final collapsed = handler.applyDelta(
          handle: DragHandle.bottom,
          startRect: startRect,
          pixelDelta: const Offset(0.0, -80.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(collapsed, equals(const Rect.fromLTWH(0.25, 0.25, 0.5, 0.125)));
      });

      test('applies left drag and enforces minSize', () {
        final result = handler.applyDelta(
          handle: DragHandle.left,
          startRect: startRect,
          pixelDelta: const Offset(12.5, 0.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(result, equals(const Rect.fromLTWH(0.375, 0.25, 0.375, 0.5)));

        final collapsed = handler.applyDelta(
          handle: DragHandle.left,
          startRect: startRect,
          pixelDelta: const Offset(80.0, 0.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(collapsed, equals(const Rect.fromLTWH(0.625, 0.25, 0.125, 0.5)));
      });

      test('applies right drag and enforces minSize', () {
        final result = handler.applyDelta(
          handle: DragHandle.right,
          startRect: startRect,
          pixelDelta: const Offset(12.5, 0.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(result, equals(const Rect.fromLTWH(0.25, 0.25, 0.625, 0.5)));

        final collapsed = handler.applyDelta(
          handle: DragHandle.right,
          startRect: startRect,
          pixelDelta: const Offset(-80.0, 0.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(collapsed, equals(const Rect.fromLTWH(0.25, 0.25, 0.125, 0.5)));
      });

      test(
        'applies center drag and clamps within normalized canvas bounds',
        () {
          final translated = handler.applyDelta(
            handle: DragHandle.center,
            startRect: startRect,
            pixelDelta: const Offset(12.5, 12.5),
            canvasSize: canvasSize,
            gridSize: gridSize,
          );
          expect(
            translated,
            equals(const Rect.fromLTWH(0.375, 0.375, 0.5, 0.5)),
          );

          // Clamped top-left
          final clampTopLeft = handler.applyDelta(
            handle: DragHandle.center,
            startRect: startRect,
            pixelDelta: const Offset(-80.0, -80.0),
            canvasSize: canvasSize,
            gridSize: gridSize,
          );
          expect(clampTopLeft, equals(const Rect.fromLTWH(0.0, 0.0, 0.5, 0.5)));

          // Clamped bottom-right (max left is 1.0 - 0.5 = 0.5, max top is 0.5)
          final clampBottomRight = handler.applyDelta(
            handle: DragHandle.center,
            startRect: startRect,
            pixelDelta: const Offset(80.0, 80.0),
            canvasSize: canvasSize,
            gridSize: gridSize,
          );
          expect(
            clampBottomRight,
            equals(const Rect.fromLTWH(0.5, 0.5, 0.5, 0.5)),
          );
        },
      );

      test(
        'guards center drag against ArgumentError crash when startRect width or height exceeds 1.0',
        () {
          final oversizedResult = handler.applyDelta(
            handle: DragHandle.center,
            startRect: const Rect.fromLTWH(0.0, 0.0, 1.1, 1.1),
            pixelDelta: Offset.zero,
            canvasSize: canvasSize,
            gridSize: gridSize,
          );
          expect(
            oversizedResult,
            equals(const Rect.fromLTWH(0.0, 0.0, 1.1, 1.1)),
          );

          final oversizedWithDelta = handler.applyDelta(
            handle: DragHandle.center,
            startRect: const Rect.fromLTWH(0.2, 0.2, 1.2, 1.3),
            pixelDelta: const Offset(50.0, 50.0),
            canvasSize: canvasSize,
            gridSize: gridSize,
          );
          expect(
            oversizedWithDelta,
            equals(const Rect.fromLTWH(0.0, 0.0, 1.2, 1.3)),
          );
        },
      );

      test('clamps right resize handles within normalized canvas bounds', () {
        // startRect: left=0.75, width=0.125. Remaining width available on canvas = 1.0 - 0.75 = 0.25
        const rightEdgeRect = Rect.fromLTWH(0.75, 0.25, 0.125, 0.5);

        // Drag right handle past canvas edge
        final rightResult = handler.applyDelta(
          handle: DragHandle.right,
          startRect: rightEdgeRect,
          pixelDelta: const Offset(100.0, 0.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(rightResult, isNotNull);
        expect(rightResult!.left + rightResult.width, lessThanOrEqualTo(1.0));
        expect(rightResult.width, equals(0.25));

        // Drag topRight handle past canvas edge
        final topRightResult = handler.applyDelta(
          handle: DragHandle.topRight,
          startRect: rightEdgeRect,
          pixelDelta: const Offset(100.0, 0.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(topRightResult, isNotNull);
        expect(
          topRightResult!.left + topRightResult.width,
          lessThanOrEqualTo(1.0),
        );
        expect(topRightResult.width, equals(0.25));

        // Drag bottomRight handle past canvas edge
        final bottomRightResult = handler.applyDelta(
          handle: DragHandle.bottomRight,
          startRect: rightEdgeRect,
          pixelDelta: const Offset(100.0, 0.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(bottomRightResult, isNotNull);
        expect(
          bottomRightResult!.left + bottomRightResult.width,
          lessThanOrEqualTo(1.0),
        );
        expect(bottomRightResult.width, equals(0.25));
      });

      test('clamps bottom resize handles within normalized canvas bounds', () {
        // startRect: top=0.75, height=0.125. Remaining height available on canvas = 1.0 - 0.75 = 0.25
        const bottomEdgeRect = Rect.fromLTWH(0.25, 0.75, 0.5, 0.125);

        // Drag bottom handle past canvas edge
        final bottomResult = handler.applyDelta(
          handle: DragHandle.bottom,
          startRect: bottomEdgeRect,
          pixelDelta: const Offset(0.0, 100.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(bottomResult, isNotNull);
        expect(bottomResult!.top + bottomResult.height, lessThanOrEqualTo(1.0));
        expect(bottomResult.height, equals(0.25));

        // Drag bottomLeft handle past canvas edge
        final bottomLeftResult = handler.applyDelta(
          handle: DragHandle.bottomLeft,
          startRect: bottomEdgeRect,
          pixelDelta: const Offset(0.0, 100.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(bottomLeftResult, isNotNull);
        expect(
          bottomLeftResult!.top + bottomLeftResult.height,
          lessThanOrEqualTo(1.0),
        );
        expect(bottomLeftResult.height, equals(0.25));

        // Drag bottomRight handle past canvas edge
        final bottomRightResult = handler.applyDelta(
          handle: DragHandle.bottomRight,
          startRect: bottomEdgeRect,
          pixelDelta: const Offset(0.0, 100.0),
          canvasSize: canvasSize,
          gridSize: gridSize,
        );
        expect(bottomRightResult, isNotNull);
        expect(
          bottomRightResult!.top + bottomRightResult.height,
          lessThanOrEqualTo(1.0),
        );
        expect(bottomRightResult.height, equals(0.25));
      });
    });
  });
}
