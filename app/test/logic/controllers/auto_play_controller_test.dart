import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';
import 'package:bad_pixel_art/logic/controllers/auto_play_controller.dart';
import '../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoPlayWizardController', () {
    late TestMockAiService mockAiService;
    late WizardNotifier wizardNotifier;
    late CanvasNotifier canvasNotifier;
    late AutoPlayWizardController controller;

    setUp(() {
      mockAiService = TestMockAiService(
        response: jsonEncode({
          'description': 'A small sword',
          'palette': ['#000000', '#ffffff', '#ff0000'],
          'components': [
            {
              'name': 'blade',
              'description': 'metal blade',
              'box_2d': [0, 0, 1000, 500],
            },
          ],
        }),
      );
      wizardNotifier = WizardNotifier();
      controller = AutoPlayWizardController();
      canvasNotifier = CanvasNotifier(
        mockAiService,
        autoPlayController: controller,
        wizardNotifier: wizardNotifier,
      );
    });

    tearDown(() {
      canvasNotifier.stopAutoPlay();
    });

    test('startAutoPlay does nothing when referenceImage is null', () async {
      canvasNotifier.state = canvasNotifier.state.copyWith(
        referenceImage: null,
      );

      await controller.startAutoPlay(canvasNotifier, wizardNotifier);

      expect(canvasNotifier.state.autoRun, isFalse);
      expect(
        wizardNotifier.state.currentStep,
        equals(WizardStep.selectGridSize),
      );
    });

    test(
      'startAutoPlay does nothing when already running (autoRun is true)',
      () async {
        canvasNotifier.state = canvasNotifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          autoRun: true,
        );

        await controller.startAutoPlay(canvasNotifier, wizardNotifier);

        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.selectGridSize),
        );
      },
    );

    test('startAutoPlay stops early when paused (isPausing is true)', () async {
      canvasNotifier.state = canvasNotifier.state.copyWith(
        referenceImage: Uint8List.fromList([1, 2, 3]),
        isPausing: true,
      );

      await controller.startAutoPlay(canvasNotifier, wizardNotifier);

      expect(canvasNotifier.state.autoRun, isFalse);
      expect(canvasNotifier.state.isPausing, isFalse);
    });

    test(
      'startAutoPlay finishes when reaching WizardStep.refinement',
      () async {
        wizardNotifier.setStep(WizardStep.refinement);
        canvasNotifier.state = canvasNotifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
        );

        await controller.startAutoPlay(canvasNotifier, wizardNotifier);

        expect(canvasNotifier.state.autoRun, isFalse);
        expect(canvasNotifier.state.isPausing, isFalse);
      },
    );

    test(
      'startAutoPlay advances from selectGridSize when autoRun remains active',
      () async {
        wizardNotifier.setStep(WizardStep.selectGridSize);
        canvasNotifier.state = canvasNotifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
        );

        // Start autoplay asynchronously
        final future = controller.startAutoPlay(canvasNotifier, wizardNotifier);

        // Stop autoplay after brief delay so loop terminates
        await Future.delayed(const Duration(milliseconds: 100));
        canvasNotifier.stopAutoPlay();
        await future;

        expect(canvasNotifier.state.autoRun, isFalse);
      },
    );

    test(
      'startAutoPlay executes color suggestion on WizardStep.colorAndOutline',
      () async {
        wizardNotifier.setStep(WizardStep.colorAndOutline);
        final solidGrid = List.generate(16, (_) => List.filled(16, 1));
        canvasNotifier.state = canvasNotifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          userPrompt: 'magic sword',
          palette: [
            const Color(0xFF000000),
            const Color(0xFF0000FF),
            const Color(0xFFFF0000),
          ],
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'solid blade',
              relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
              grid: solidGrid,
            ),
          ],
        );

        final mockAi = TestMockAiService(
          response: TestJsonFixtures.colorSelectionResponse,
        );
        canvasNotifier = CanvasNotifier(
          mockAi,
          autoPlayController: controller,
          wizardNotifier: wizardNotifier,
        );
        canvasNotifier.state = canvasNotifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          userPrompt: 'magic sword',
          palette: [
            const Color(0xFF000000),
            const Color(0xFF0000FF),
            const Color(0xFFFF0000),
          ],
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'solid blade',
              relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
              grid: solidGrid,
            ),
          ],
        );

        final future = controller.startAutoPlay(canvasNotifier, wizardNotifier);
        await Future.delayed(const Duration(milliseconds: 100));
        canvasNotifier.stopAutoPlay();
        await future;

        expect(
          canvasNotifier.state.decomposedComponents.first.fillColor,
          isNotNull,
        );
        expect(
          canvasNotifier.state.decomposedComponents.first.fillColor2,
          isNotNull,
        );
        expect(
          canvasNotifier.state.decomposedComponents.first.gradientAngle,
          equals(45.0),
        );
      },
    );

    test(
      'startAutoPlay executes merge on WizardStep.layerOrderingAndMerge',
      () async {
        wizardNotifier.setStep(WizardStep.layerOrderingAndMerge);
        final solidGrid = List.generate(16, (y) => List.generate(16, (x) => 1));
        canvasNotifier.state = canvasNotifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          userPrompt: 'magic sword',
          palette: [const Color(0xFF000000), const Color(0xFF0000FF)],
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'solid blade',
              relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
              grid: solidGrid,
              fillColor: const Color(0xFF0000FF),
            ),
          ],
        );

        final future = controller.startAutoPlay(canvasNotifier, wizardNotifier);
        await Future.delayed(const Duration(milliseconds: 100));
        canvasNotifier.stopAutoPlay();
        await future;

        // Ensure canvas grid was merged with component color (color index 2)
        expect(canvasNotifier.state.grid[0][0], equals(2));
      },
    );

    test(
      'startAutoPlay executes refinement on WizardStep.refinement and completes',
      () async {
        wizardNotifier.setStep(WizardStep.refinement);
        final mockAi = TestMockAiService(
          response:
              '{"thought": "done", "tool": "pixel", "params": [0, 0], "colorIndex": 1}',
        );
        canvasNotifier = CanvasNotifier(
          mockAi,
          autoPlayController: controller,
          wizardNotifier: wizardNotifier,
        );
        canvasNotifier.state = canvasNotifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          userPrompt: 'magic sword',
          palette: [const Color(0xFF000000), const Color(0xFF0000FF)],
        );

        await controller.startAutoPlay(canvasNotifier, wizardNotifier);

        expect(canvasNotifier.state.autoRun, isFalse);
        expect(mockAi.callCount, greaterThanOrEqualTo(1));
      },
    );
  });

  group('CanvasNotifier.startAutoPlay integration', () {
    late TestMockAiService mockAiService;

    setUp(() {
      mockAiService = TestMockAiService();
    });

    test(
      'startAutoPlay no-ops if wizardNotifier is null and none provided',
      () async {
        final notifier = CanvasNotifier(mockAiService, wizardNotifier: null);
        notifier.state = notifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
        );

        await notifier.startAutoPlay();

        expect(notifier.state.autoRun, isFalse);
      },
    );

    test('startAutoPlay uses injected wizardNotifier', () async {
      final wizardNotifier = WizardNotifier();
      wizardNotifier.setStep(WizardStep.refinement);

      final notifier = CanvasNotifier(
        mockAiService,
        wizardNotifier: wizardNotifier,
      );
      notifier.state = notifier.state.copyWith(
        referenceImage: Uint8List.fromList([1, 2, 3]),
      );

      await notifier.startAutoPlay();

      expect(notifier.state.autoRun, isFalse);
    });

    test(
      'startAutoPlay accepts explicit wizardNotifier override parameter',
      () async {
        final wizardNotifier = WizardNotifier();
        wizardNotifier.setStep(WizardStep.refinement);

        final notifier = CanvasNotifier(mockAiService, wizardNotifier: null);
        notifier.state = notifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
        );

        await notifier.startAutoPlay(wizardNotifier);

        expect(notifier.state.autoRun, isFalse);
      },
    );

    test(
      'canvasStateProvider resolves wizardNotifier from ProviderContainer',
      () {
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAiService)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(canvasStateProvider.notifier);
        final wizardNotifier = container.read(wizardStateProvider.notifier);

        wizardNotifier.setStep(WizardStep.refinement);
        notifier.state = notifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
        );

        expect(() => notifier.startAutoPlay(), returnsNormally);
      },
    );
  });
}
