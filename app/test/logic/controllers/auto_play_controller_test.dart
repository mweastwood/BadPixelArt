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

    test(
      'startAutoPlay in WizardMode.direct skips intermediate decomposition steps and advances straight from selectPalette to refinement',
      () async {
        wizardNotifier.setMode(WizardMode.direct);
        wizardNotifier.setStep(WizardStep.selectPalette);

        final mockAi = TestMockAiService(
          responses: [
            '["#000000", "#ffffff", "#ff0000"]', // palette suggestion
            '{"thought": "done", "tool": "pixel", "params": [0, 0], "colorIndex": 1}', // refinement
          ],
        );
        canvasNotifier = CanvasNotifier(
          mockAi,
          autoPlayController: controller,
          wizardNotifier: wizardNotifier,
        );
        canvasNotifier.state = canvasNotifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          userPrompt: 'pixel sword',
        );

        final future = controller.startAutoPlay(canvasNotifier, wizardNotifier);
        await Future.delayed(const Duration(milliseconds: 50));
        canvasNotifier.stopAutoPlay();
        await future;

        // In direct mode, selectPalette should advance straight to refinement (not sketchingPlan)
        expect(
          wizardNotifier.state.currentStep,
          anyOf(
            equals(WizardStep.selectPalette),
            equals(WizardStep.refinement),
          ),
        );
        expect(canvasNotifier.state.decomposedComponents, isEmpty);
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

  group('AutoPlay Error Recovery & Restart Tests', () {
    test(
      'error during setupPrompt terminates at setupPrompt and restarting continues from setupPrompt',
      () async {
        final mockAi = TestMockAiService(
          response: 'A majestic pixel art dragon',
          shouldThrow: true,
          exceptionMessage: '503 Service Unavailable',
        );
        final wizardNotifier = WizardNotifier();
        wizardNotifier.setStep(WizardStep.setupPrompt);
        final controller = AutoPlayWizardController();
        final notifier = CanvasNotifier(
          mockAi,
          autoPlayController: controller,
          wizardNotifier: wizardNotifier,
        );
        notifier.state = notifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          userPrompt: '',
        );

        // Run auto play - should fail on 503 error
        await controller.startAutoPlay(notifier, wizardNotifier);

        // Verify wizard stopped at setupPrompt
        expect(notifier.state.autoRun, isFalse);
        expect(wizardNotifier.currentStep, equals(WizardStep.setupPrompt));
        expect(notifier.state.userPrompt, isEmpty);

        // Fix AI service (model back online)
        mockAi.shouldThrow = false;
        mockAi.response = 'A majestic pixel art dragon';

        // Restart wizard
        final future = controller.startAutoPlay(notifier, wizardNotifier);
        await Future.delayed(const Duration(milliseconds: 50));
        notifier.stopAutoPlay();
        await future;

        // Prompt was generated and wizard moved past setupPrompt
        expect(
          notifier.state.userPrompt,
          equals('A majestic pixel art dragon'),
        );
      },
    );

    test(
      'error during selectPalette terminates at selectPalette and restarting continues from selectPalette',
      () async {
        final mockAi = TestMockAiService(
          response: '["#112233", "#445566", "#778899"]',
          shouldThrow: true,
          exceptionMessage: '503 Service Unavailable',
        );
        final wizardNotifier = WizardNotifier();
        wizardNotifier.setStep(WizardStep.selectPalette);
        final controller = AutoPlayWizardController();
        final notifier = CanvasNotifier(
          mockAi,
          autoPlayController: controller,
          wizardNotifier: wizardNotifier,
        );
        notifier.state = notifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          userPrompt: 'A dragon',
        );

        await controller.startAutoPlay(notifier, wizardNotifier);

        expect(notifier.state.autoRun, isFalse);
        expect(wizardNotifier.currentStep, equals(WizardStep.selectPalette));
        expect(notifier.state.suggestedPalette, isNull);

        // Model recovers
        mockAi.shouldThrow = false;
        mockAi.response = '["#112233", "#445566", "#778899"]';

        final future = controller.startAutoPlay(notifier, wizardNotifier);
        await Future.delayed(const Duration(milliseconds: 50));
        notifier.stopAutoPlay();
        await future;

        expect(notifier.state.paletteName, equals('suggested'));
      },
    );

    test(
      'error during sketchingPlan terminates at sketchingPlan and restarting continues from sketchingPlan',
      () async {
        final mockAi = TestMockAiService(
          shouldThrow: true,
          exceptionMessage: '503 Service Unavailable',
        );
        final wizardNotifier = WizardNotifier();
        wizardNotifier.setStep(WizardStep.sketchingPlan);
        final controller = AutoPlayWizardController();
        final notifier = CanvasNotifier(
          mockAi,
          autoPlayController: controller,
          wizardNotifier: wizardNotifier,
        );
        notifier.state = notifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          userPrompt: 'A dragon',
          decomposedComponents: const [],
        );

        await controller.startAutoPlay(notifier, wizardNotifier);

        expect(notifier.state.autoRun, isFalse);
        expect(wizardNotifier.currentStep, equals(WizardStep.sketchingPlan));
        expect(notifier.state.decomposedComponents, isEmpty);

        // Model recovers
        mockAi.shouldThrow = false;
        mockAi.response = jsonEncode([
          {
            'name': 'head',
            'description': 'dragon head',
            'relativeBoundingBox': {
              'left': 0.1,
              'top': 0.1,
              'width': 0.3,
              'height': 0.3,
            },
          },
        ]);

        final future = controller.startAutoPlay(notifier, wizardNotifier);
        await Future.delayed(const Duration(milliseconds: 50));
        notifier.stopAutoPlay();
        await future;

        expect(notifier.state.decomposedComponents, isNotEmpty);
      },
    );

    test(
      'error during componentSculpting preserves already sculpted components, and restart skips them to finish remaining components',
      () async {
        final wizardNotifier = WizardNotifier();
        wizardNotifier.setStep(WizardStep.componentSculpting);
        final controller = AutoPlayWizardController();

        final comp0 = PixelArtComponent(
          name: 'head',
          description: 'dragon head',
          relativeBoundingBox: const Rect.fromLTWH(0.1, 0.1, 0.3, 0.3),
        );
        final comp1 = PixelArtComponent(
          name: 'tail',
          description: 'dragon tail',
          relativeBoundingBox: const Rect.fromLTWH(0.6, 0.6, 0.3, 0.3),
        );

        // Mock AI succeeds on first component (head), then throws 503 on second component (tail)
        int call = 0;
        final mockAi = TestMockAiService(
          onGenerateContentRaw:
              ({required prompt, imageBytes, temperature, maxOutputTokens}) {
                call++;
                if (call == 1) {
                  return AiResponse(
                    text: jsonEncode({
                      'thought': 'sculpt head',
                      'tool': 'rectangle_filled',
                      'params': [1, 1, 3, 3],
                      'isComplete': true,
                    }),
                  );
                } else {
                  throw Exception('503 Service Unavailable');
                }
              },
        );

        final notifier = CanvasNotifier(
          mockAi,
          autoPlayController: controller,
          wizardNotifier: wizardNotifier,
        );
        notifier.state = notifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          userPrompt: 'A dragon',
          decomposedComponents: [comp0, comp1],
        );

        await controller.startAutoPlay(notifier, wizardNotifier);

        // AutoPlay stopped at componentSculpting
        expect(notifier.state.autoRun, isFalse);
        expect(
          wizardNotifier.currentStep,
          equals(WizardStep.componentSculpting),
        );
        // First component was sculpted and preserved!
        expect(notifier.state.decomposedComponents[0].isSculpted, isTrue);
        expect(notifier.state.decomposedComponents[0].grid, isNotNull);
        // Second component is not yet sculpted
        expect(notifier.state.decomposedComponents[1].isSculpted, isFalse);
        expect(notifier.state.decomposedComponents[1].grid, isNull);

        // Model recovers - now provide response for second component
        int resumeCalls = 0;
        mockAi.onGenerateContentRaw =
            ({required prompt, imageBytes, temperature, maxOutputTokens}) {
              resumeCalls++;
              return AiResponse(
                text: jsonEncode({
                  'thought': 'sculpt tail',
                  'tool': 'rectangle_filled',
                  'params': [6, 6, 8, 8],
                  'isComplete': true,
                }),
              );
            };

        // Restart wizard
        final future = controller.startAutoPlay(notifier, wizardNotifier);
        await Future.delayed(const Duration(milliseconds: 50));
        notifier.stopAutoPlay();
        await future;

        // Head was NOT re-sculpted; only tail was sculpted (resumeCalls == 1)
        expect(resumeCalls, equals(1));
        expect(notifier.state.decomposedComponents[0].isSculpted, isTrue);
        expect(notifier.state.decomposedComponents[1].isSculpted, isTrue);
        expect(notifier.state.decomposedComponents[1].grid, isNotNull);
      },
    );

    test(
      'error during colorAndOutline terminates at colorAndOutline and restart continues from colorAndOutline',
      () async {
        final mockAi = TestMockAiService(
          response: TestJsonFixtures.colorSelectionResponse,
          shouldThrow: true,
          exceptionMessage: '503 Service Unavailable',
        );
        final wizardNotifier = WizardNotifier();
        wizardNotifier.setStep(WizardStep.colorAndOutline);
        final controller = AutoPlayWizardController();
        final notifier = CanvasNotifier(
          mockAi,
          autoPlayController: controller,
          wizardNotifier: wizardNotifier,
        );
        final sculptedComp = PixelArtComponent(
          name: 'blade',
          description: 'sword blade',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          isSculpted: true,
          grid: List.generate(16, (_) => List.filled(16, 1)),
        );
        notifier.state = notifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          userPrompt: 'sword',
          palette: [
            const Color(0xFF000000),
            const Color(0xFF0000FF),
            const Color(0xFFFF0000),
          ],
          decomposedComponents: [sculptedComp],
        );

        await controller.startAutoPlay(notifier, wizardNotifier);

        expect(notifier.state.autoRun, isFalse);
        expect(wizardNotifier.currentStep, equals(WizardStep.colorAndOutline));
        expect(notifier.state.decomposedComponents.first.fillColor, isNull);

        // Model recovers
        mockAi.shouldThrow = false;
        mockAi.response = TestJsonFixtures.colorSelectionResponse;

        final future = controller.startAutoPlay(notifier, wizardNotifier);
        await Future.delayed(const Duration(milliseconds: 50));
        notifier.stopAutoPlay();
        await future;

        expect(notifier.state.decomposedComponents.first.fillColor, isNotNull);
      },
    );
  });
}
