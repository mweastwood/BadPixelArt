import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/widgets/canvas/canvas_painter.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';

void main() {
  group('CanvasPainter shouldRepaint Tests', () {
    late List<List<int>> baseGrid;
    late List<Color> basePalette;
    late List<PixelArtComponent> baseComponents;

    setUp(() {
      baseGrid = [
        [0, 1],
        [1, 0],
      ];
      basePalette = [Colors.black, Colors.white, Colors.red];
      baseComponents = [
        PixelArtComponent(
          name: 'Head',
          description: 'head part',
          relativeBoundingBox: const Rect.fromLTWH(0.1, 0.1, 0.5, 0.5),
          fillColor: Colors.red,
          grid: [
            [1, 0],
            [0, 1],
          ],
        ),
      ];
    });

    CanvasPainter createPainter({
      List<List<int>>? grid,
      List<Color>? palette,
      List<PixelArtComponent>? decomposedComponents,
      int activeComponentIndex = 0,
      WizardStep currentStep = WizardStep.sketchingPlan,
      bool isGenerating = false,
      Map<String, List<Map<String, int>>>? sculptingCandidates,
    }) {
      return CanvasPainter(
        grid: grid ?? baseGrid,
        palette: palette ?? basePalette,
        decomposedComponents: decomposedComponents ?? baseComponents,
        activeComponentIndex: activeComponentIndex,
        currentStep: currentStep,
        isGenerating: isGenerating,
        sculptingCandidates: sculptingCandidates,
      );
    }

    test('returns false when properties are identical / value-equal', () {
      final painter1 = createPainter();
      final painter2 = createPainter(
        grid: [
          [0, 1],
          [1, 0],
        ],
        palette: [Colors.black, Colors.white, Colors.red],
        decomposedComponents: [
          PixelArtComponent(
            name: 'Head',
            description: 'head part',
            relativeBoundingBox: const Rect.fromLTWH(0.1, 0.1, 0.5, 0.5),
            fillColor: Colors.red,
            grid: [
              [1, 0],
              [0, 1],
            ],
          ),
        ],
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('returns true when grid cell is modified (new list instances)', () {
      final painter1 = createPainter();
      final painter2 = createPainter(
        grid: [
          [1, 1],
          [1, 0],
        ],
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('returns true when palette is modified', () {
      final painter1 = createPainter();
      final painter2 = createPainter(
        palette: [Colors.black, Colors.white, Colors.blue],
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('returns true when palette length changes', () {
      final painter1 = createPainter();
      final painter2 = createPainter(palette: [Colors.black, Colors.white]);

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('returns true when decomposedComponents attribute is modified', () {
      final painter1 = createPainter();
      final painter2 = createPainter(
        decomposedComponents: [
          baseComponents.first.copyWith(fillColor: () => Colors.green),
        ],
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('returns true when component grid is modified', () {
      final painter1 = createPainter();
      final painter2 = createPainter(
        decomposedComponents: [
          baseComponents.first.copyWith(
            grid: [
              [1, 1],
              [0, 1],
            ],
          ),
        ],
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('returns true when component bounding box is modified', () {
      final painter1 = createPainter();
      final painter2 = createPainter(
        decomposedComponents: [
          baseComponents.first.copyWith(
            relativeBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
          ),
        ],
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('returns true when activeComponentIndex changes', () {
      final painter1 = createPainter(activeComponentIndex: 0);
      final painter2 = createPainter(activeComponentIndex: 1);

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('returns true when currentStep changes across any wizard phase', () {
      final steps = [
        WizardStep.selectGridSize,
        WizardStep.sketchingPlan,
        WizardStep.componentSculpting,
        WizardStep.colorAndOutline,
        WizardStep.layerOrderingAndMerge,
        WizardStep.refinement,
      ];

      for (int i = 0; i < steps.length - 1; i++) {
        final painter1 = createPainter(currentStep: steps[i]);
        final painter2 = createPainter(currentStep: steps[i + 1]);

        expect(
          painter1.shouldRepaint(painter2),
          isTrue,
          reason: 'Expected repaint between ${steps[i]} and ${steps[i + 1]}',
        );
      }
    });

    test('returns true when isGenerating changes', () {
      final painter1 = createPainter(isGenerating: false);
      final painter2 = createPainter(isGenerating: true);

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('returns true when sculptingCandidates changes', () {
      final painter1 = createPainter(
        sculptingCandidates: {
          'add': [
            {'x': 1, 'y': 1},
          ],
          'remove': [],
        },
      );
      final painter2 = createPainter(
        sculptingCandidates: {
          'add': [
            {'x': 2, 'y': 2},
          ],
          'remove': [],
        },
      );
      final painterNull = createPainter(sculptingCandidates: null);

      expect(painter2.shouldRepaint(painter1), isTrue);
      expect(painterNull.shouldRepaint(painter1), isTrue);
      expect(painter1.shouldRepaint(painter1), isFalse);
    });
  });

  group('CanvasPainter paint Rendering Tests', () {
    test('paints sculpting candidate overlays with add and remove indicators', () {
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

      final recordingCanvas = _RecordingCanvas();
      // 320x320 with 16x16 grid gives exactly 20x20 per cell
      painter.paint(recordingCanvas, const Size(320, 320));

      final expectedAddColor = Colors.greenAccent.withValues(alpha: 0.3);
      final expectedRemoveColor = Colors.redAccent.withValues(alpha: 0.3);

      const expectedAddRect = Rect.fromLTWH(80, 60, 20, 20);
      const expectedRemoveRect = Rect.fromLTWH(80, 80, 20, 20);

      final hasAddOverlay = recordingCanvas.rectCalls.any(
        (c) =>
            c.rect == expectedAddRect &&
            c.paint.color.toARGB32() == expectedAddColor.toARGB32(),
      );
      expect(
        hasAddOverlay,
        isTrue,
        reason:
            'Candidate add overlay at (4,3) should be painted with greenAccent alpha 0.3',
      );

      final hasRemoveOverlay = recordingCanvas.rectCalls.any(
        (c) =>
            c.rect == expectedRemoveRect &&
            c.paint.color.toARGB32() == expectedRemoveColor.toARGB32(),
      );
      expect(
        hasRemoveOverlay,
        isTrue,
        reason:
            'Candidate remove overlay at (4,4) should be painted with redAccent alpha 0.3',
      );
    });

    test(
      'paints safely when grid contains out-of-bounds palette color indices without rendering invalid colors',
      () {
        final grid = List.generate(4, (_) => List.filled(4, 0));
        // Palette only has 2 colors (valid 1-based indices: 1 -> palette[0], 2 -> palette[1])
        grid[0][0] = 5; // out-of-bounds (> palette.length)
        grid[0][1] = 99; // well beyond bounds
        grid[1][0] = -1; // negative index
        grid[1][1] = 1; // valid index -> palette[0]
        final palette = [Colors.blue, Colors.white];

        final painter = CanvasPainter(
          grid: grid,
          palette: palette,
          decomposedComponents: const [],
          activeComponentIndex: 0,
          currentStep: WizardStep.selectGridSize,
          isGenerating: false,
        );

        final recordingCanvas = _RecordingCanvas();
        // 100x100 on 4x4 grid -> 25x25 cell size
        painter.paint(recordingCanvas, const Size(100, 100));

        // Valid cell at (1, 1) should be painted with palette[0] (Colors.blue)
        const expectedValidRect = Rect.fromLTWH(25, 25, 25, 25);
        final validCellPainted = recordingCanvas.rectCalls.any(
          (c) =>
              c.rect == expectedValidRect &&
              c.paint.color.toARGB32() == Colors.blue.toARGB32(),
        );
        expect(
          validCellPainted,
          isTrue,
          reason:
              'Valid cell (1, 1) should paint with palette[0] (Colors.blue)',
        );

        // Check that no palette colors are rendered for invalid cells at (0,0), (1,0), (0,1)
        final invalidCellRects = [
          const Rect.fromLTWH(0, 0, 25, 25), // (0, 0) -> 5
          const Rect.fromLTWH(25, 0, 25, 25), // (1, 0) -> 99
          const Rect.fromLTWH(0, 25, 25, 25), // (0, 1) -> -1
        ];

        for (final rect in invalidCellRects) {
          final paintedWithPalette = recordingCanvas.rectCalls.any(
            (c) =>
                c.rect == rect &&
                (c.paint.color.toARGB32() == Colors.blue.toARGB32() ||
                    c.paint.color.toARGB32() == Colors.white.toARGB32()),
          );
          expect(
            paintedWithPalette,
            isFalse,
            reason: 'Invalid cell at $rect must not paint palette colors',
          );
        }
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

class _DrawRectCall {
  final Rect rect;
  final Paint paint;
  _DrawRectCall(this.rect, this.paint);
}

class _RecordingCanvas extends Fake implements Canvas {
  final List<Paint> drawnPaints = [];
  final List<Rect> drawnRects = [];
  final List<_DrawRectCall> rectCalls = [];

  @override
  void drawRect(Rect rect, Paint paint) {
    final clonedPaint = Paint()
      ..color = paint.color
      ..style = paint.style
      ..isAntiAlias = paint.isAntiAlias
      ..strokeWidth = paint.strokeWidth;
    drawnRects.add(rect);
    drawnPaints.add(clonedPaint);
    rectCalls.add(_DrawRectCall(rect, clonedPaint));
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {}

  @override
  void drawPath(Path path, Paint paint) {}

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) {}
}
