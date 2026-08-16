import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/widgets/canvas/scaled_canvas_preview.dart';
import '../../test_helper.dart';

void main() {
  group('MiniPixelPainter & ScaledCanvasPreview Tests', () {
    test(
      'MiniPixelPainter paints grid with 1-based palette indexing without error',
      () {
        final palette = [Colors.red, Colors.green, Colors.blue];
        final grid = [
          [0, 1], // 0 is transparent, 1 is palette[0] (red)
          [2, 3], // 2 is palette[1] (green), 3 is palette[2] (blue)
        ];

        final painter = MiniPixelPainter(grid: grid, palette: palette);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(100, 100)),
          returnsNormally,
        );
      },
    );

    test(
      'MiniPixelPainter handles empty grid and out-of-bounds indices gracefully',
      () {
        final palette = [Colors.red];
        final painterEmpty = MiniPixelPainter(grid: [], palette: palette);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painterEmpty.paint(canvas, const Size(100, 100)),
          returnsNormally,
        );

        final painterOutOfBounds = MiniPixelPainter(
          grid: [
            [0, 5],
          ],
          palette: palette,
        );
        expect(
          () => painterOutOfBounds.paint(canvas, const Size(100, 100)),
          returnsNormally,
        );
      },
    );

    test('MiniPixelPainter shouldRepaint detects grid or palette changes', () {
      final grid1 = [
        [0, 1],
      ];
      final grid2 = [
        [1, 0],
      ];
      final palette1 = [Colors.red];
      final palette2 = [Colors.blue];

      final painter1 = MiniPixelPainter(grid: grid1, palette: palette1);
      final painterSame = MiniPixelPainter(grid: grid1, palette: palette1);
      final painterDiffGrid = MiniPixelPainter(grid: grid2, palette: palette1);
      final painterDiffPalette = MiniPixelPainter(
        grid: grid1,
        palette: palette2,
      );

      expect(painter1.shouldRepaint(painterSame), isFalse);
      expect(painterDiffGrid.shouldRepaint(painter1), isTrue);
      expect(painterDiffPalette.shouldRepaint(painter1), isTrue);
    });

    testWidgets(
      'ScaledCanvasPreview renders label, dimensions, and CustomPaint',
      (tester) async {
        final grid = [
          [0, 1],
          [2, 0],
        ];
        final palette = [Colors.red, Colors.blue];

        await tester.pumpWidget(
          buildTestableWidget(
            child: ScaledCanvasPreview(
              grid: grid,
              palette: palette,
              scaleFactor: 4.0,
              label: 'Preview 4x',
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('scaled_canvas_preview')),
          findsOneWidget,
        );
        expect(find.text('Preview 4x (8×8px)'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );
  });
}
