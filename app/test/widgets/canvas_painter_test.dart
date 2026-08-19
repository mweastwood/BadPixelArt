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
  });
}
