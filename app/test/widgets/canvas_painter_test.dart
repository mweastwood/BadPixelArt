import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/widgets/canvas/canvas_painter.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';

void main() {
  group('CanvasPainter unit tests', () {
    test('shouldRepaint detects changes in sculptingCandidates', () {
      final grid = List.generate(16, (_) => List.filled(16, 0));
      final palette = [Colors.black, Colors.white];
      final components = <PixelArtComponent>[];

      final painter1 = CanvasPainter(
        grid: grid,
        palette: palette,
        decomposedComponents: components,
        activeComponentIndex: 0,
        currentStep: WizardStep.componentSculpting,
        isGenerating: false,
        sculptingCandidates: {
          'add': [
            {'x': 1, 'y': 1},
          ],
          'remove': [],
        },
      );

      final painter2 = CanvasPainter(
        grid: grid,
        palette: palette,
        decomposedComponents: components,
        activeComponentIndex: 0,
        currentStep: WizardStep.componentSculpting,
        isGenerating: false,
        sculptingCandidates: {
          'add': [
            {'x': 2, 'y': 2},
          ],
          'remove': [],
        },
      );

      final painterNull = CanvasPainter(
        grid: grid,
        palette: palette,
        decomposedComponents: components,
        activeComponentIndex: 0,
        currentStep: WizardStep.componentSculpting,
        isGenerating: false,
        sculptingCandidates: null,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
      expect(painterNull.shouldRepaint(painter1), isTrue);
      expect(painter1.shouldRepaint(painter1), isFalse);
    });

    test('CanvasPainter paints with sculptingCandidates without error', () {
      final grid = List.generate(16, (_) => List.filled(16, 0));
      final palette = [Colors.black, Colors.white];
      final compGrid = List.generate(16, (_) => List.filled(16, 0));
      compGrid[4][4] = 1;
      final components = [
        PixelArtComponent(
          name: 'test',
          description: 'test component',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          grid: compGrid,
        ),
      ];

      final painter = CanvasPainter(
        grid: grid,
        palette: palette,
        decomposedComponents: components,
        activeComponentIndex: 0,
        currentStep: WizardStep.componentSculpting,
        isGenerating: false,
        sculptingCandidates: {
          'add': [
            {'x': 4, 'y': 3},
          ],
          'remove': [
            {'x': 4, 'y': 4},
          ],
        },
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(300, 300)),
        returnsNormally,
      );
    });

    test(
      'CanvasPainter paints safely when grid contains out-of-bounds palette color indices',
      () {
        final grid = List.generate(16, (_) => List.filled(16, 0));
        // Palette only has 2 colors (valid: 1, 2)
        grid[0][0] = 5; // out-of-bounds (> palette.length)
        grid[0][1] = 99; // well beyond bounds
        grid[1][0] = -1; // negative index
        grid[1][1] = 1; // valid index -> palette[0]
        final palette = [Colors.black, Colors.white];

        final painter = CanvasPainter(
          grid: grid,
          palette: palette,
          decomposedComponents: const [],
          activeComponentIndex: 0,
          currentStep: WizardStep.selectGridSize,
          isGenerating: false,
        );

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(320, 320)),
          returnsNormally,
        );
      },
    );

    test(
      'CanvasPainter bypasses component outline overlay when in WizardStep.refinement',
      () {
        final grid = List.generate(4, (_) => List.filled(4, 1));
        final palette = [Colors.red];
        final compOutline = List.generate(4, (_) => List.filled(4, 0));
        compOutline[1][1] = 1;

        final components = [
          PixelArtComponent(
            name: 'test comp',
            description: 'desc',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
            grid: compOutline,
            outlineGrid: compOutline,
          ),
        ];

        final overlayColor = PixelArtComponent.getColor(
          0,
        ).withValues(alpha: 0.4);

        final refinementPainter = CanvasPainter(
          grid: grid,
          palette: palette,
          decomposedComponents: components,
          activeComponentIndex: 0,
          currentStep: WizardStep.refinement,
          isGenerating: false,
        );

        final testCanvasRefinement = _RecordingCanvas();
        refinementPainter.paint(testCanvasRefinement, const Size(100, 100));

        // Outline overlay paint should NOT be rendered in refinement step
        final renderedOverlayInRefinement = testCanvasRefinement.drawnPaints
            .any((p) => p.color.toARGB32() == overlayColor.toARGB32());
        expect(renderedOverlayInRefinement, isFalse);

        final sculptingPainter = CanvasPainter(
          grid: grid,
          palette: palette,
          decomposedComponents: components,
          activeComponentIndex: 0,
          currentStep: WizardStep.sketchingPlan,
          isGenerating: false,
        );

        final testCanvasSculpting = _RecordingCanvas();
        sculptingPainter.paint(testCanvasSculpting, const Size(100, 100));

        // Outline overlay paint SHOULD be rendered in drafting steps
        final renderedOverlayInSculpting = testCanvasSculpting.drawnPaints.any(
          (p) => p.color.toARGB32() == overlayColor.toARGB32(),
        );
        expect(renderedOverlayInSculpting, isTrue);
      },
    );
  });
}

class _RecordingCanvas extends Fake implements Canvas {
  final List<Paint> drawnPaints = [];
  final List<Rect> drawnRects = [];

  @override
  void drawRect(Rect rect, Paint paint) {
    drawnRects.add(rect);
    drawnPaints.add(
      Paint()
        ..color = paint.color
        ..style = paint.style
        ..isAntiAlias = paint.isAntiAlias,
    );
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {}

  @override
  void drawPath(Path path, Paint paint) {}

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) {}
}
