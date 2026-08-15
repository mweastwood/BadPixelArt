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
    }) {
      return CanvasPainter(
        grid: grid ?? baseGrid,
        palette: palette ?? basePalette,
        decomposedComponents: decomposedComponents ?? baseComponents,
        activeComponentIndex: activeComponentIndex,
        currentStep: currentStep,
        isGenerating: isGenerating,
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
  });
}
