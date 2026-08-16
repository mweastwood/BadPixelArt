import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_helper.dart';

void main() {
  group('Canvas Decomposition Tests', () {
    late TestMockAiService mockAiService;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAiService = TestMockAiService();
      container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(mockAiService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'triggerDecomposition runs DecomposerAgent and populates decomposedComponents directly',
      () async {
        final notifier = container.read(canvasStateProvider.notifier);
        expect(
          container.read(canvasStateProvider).decomposedComponents,
          isEmpty,
        );

        await notifier.triggerDecomposition();

        final model = container.read(canvasStateProvider);
        expect(model.pendingDecompositionOptions, isEmpty);
        expect(model.decomposedComponents, hasLength(1));
        expect(model.decomposedComponents.first.name, equals('blade'));
        expect(
          model.decomposedComponents.first.description,
          equals('vertical blade'),
        );
        // Snapped bounds verification:
        // After scaling and centering relative to the center of mass
        expect(
          model.decomposedComponents.first.relativeBoundingBox,
          equals(const Rect.fromLTWH(0.3125, 0.0, 0.375, 1.0)),
        );
      },
    );

    test('reorderComponents reorders correctly and bounds checks inputs', () {
      final notifier = container.read(canvasStateProvider.notifier);

      final compA = PixelArtComponent(
        name: 'Component A',
        description: 'A',
        relativeBoundingBox: Rect.zero,
      );
      final compB = PixelArtComponent(
        name: 'Component B',
        description: 'B',
        relativeBoundingBox: Rect.zero,
      );
      final compC = PixelArtComponent(
        name: 'Component C',
        description: 'C',
        relativeBoundingBox: Rect.zero,
      );

      notifier.state = notifier.state.copyWith(
        decomposedComponents: [compA, compB, compC],
      );

      // Valid reorder: move A (0) to after B (newIndex: 2)
      notifier.reorderComponents(0, 2);
      expect(
        container
            .read(canvasStateProvider)
            .decomposedComponents
            .map((c) => c.name),
        equals(['Component B', 'Component A', 'Component C']),
      );

      // Invalid oldIndex (negative)
      notifier.reorderComponents(-1, 1);
      expect(
        container
            .read(canvasStateProvider)
            .decomposedComponents
            .map((c) => c.name),
        equals(['Component B', 'Component A', 'Component C']),
      );

      // Invalid oldIndex (too large)
      notifier.reorderComponents(3, 1);
      expect(
        container
            .read(canvasStateProvider)
            .decomposedComponents
            .map((c) => c.name),
        equals(['Component B', 'Component A', 'Component C']),
      );

      // Invalid newIndex (negative)
      notifier.reorderComponents(1, -1);
      expect(
        container
            .read(canvasStateProvider)
            .decomposedComponents
            .map((c) => c.name),
        equals(['Component B', 'Component A', 'Component C']),
      );

      // Invalid newIndex (too large)
      notifier.reorderComponents(1, 4);
      expect(
        container
            .read(canvasStateProvider)
            .decomposedComponents
            .map((c) => c.name),
        equals(['Component B', 'Component A', 'Component C']),
      );
    });

    test(
      'invalidates future steps when user prompt or reference image changes',
      () {
        final mockAiService = TestMockAiService();
        final notifier = CanvasNotifier(mockAiService);

        notifier.state = notifier.state.copyWith(
          userPrompt: 'sword',
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'steel blade',
              relativeBoundingBox: Rect.zero,
            ),
          ],
        );

        expect(notifier.state.decomposedComponents, isNotEmpty);

        notifier.updatePrompt('shield');
        expect(notifier.state.decomposedComponents, isEmpty);
      },
    );

    test(
      'startAutoPlay during componentSculpting sculpts components and advances to colorAndOutline without getting stuck',
      () async {
        final mockAiService = TestMockAiService(
          response: jsonEncode({
            'thought': 'sketching rectangle',
            'tool': 'rectangle_filled',
            'params': [6, 2, 9, 10],
            'isComplete': true,
          }),
        );
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAiService)],
        );
        addTearDown(container.dispose);
        final notifier = container.read(canvasStateProvider.notifier);

        container
            .read(wizardStateProvider.notifier)
            .setStep(WizardStep.componentSculpting);

        notifier.state = notifier.state.copyWith(
          autoRun: true,
          userPrompt: 'sword',
          referenceImage: Uint8List.fromList([1, 2, 3]),
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'steel blade',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
            ),
            PixelArtComponent(
              name: 'handle',
              description: 'leather handle',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.7, 0.2, 0.2),
            ),
          ],
        );

        await notifier.sketchComponents();

        final comps = notifier.state.decomposedComponents;
        expect(comps[0].grid, isNotNull);
        expect(comps[1].grid, isNotNull);
      },
    );

    test(
      'triggerDecomposition resets isGenerating and autoRun to false on error and preserves state',
      () async {
        final throwingAi = TestMockAiService(
          shouldThrow: true,
          exceptionMessage: 'Network down',
        );
        final errContainer = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(throwingAi)],
        );
        addTearDown(errContainer.dispose);

        final notifier = errContainer.read(canvasStateProvider.notifier);
        notifier.setAutoRunState(autoRun: true, isPausing: false);

        await notifier.triggerDecomposition();

        final state = errContainer.read(canvasStateProvider);
        expect(state.isGenerating, isFalse);
        expect(state.autoRun, isFalse);
      },
    );

    test(
      'sketchComponents resets isGenerating and autoRun to false on error',
      () async {
        final throwingAi = TestMockAiService(
          shouldThrow: true,
          exceptionMessage: 'AI execution failed',
        );
        final errContainer = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(throwingAi)],
        );
        addTearDown(errContainer.dispose);

        final notifier = errContainer.read(canvasStateProvider.notifier);
        notifier.state = notifier.state.copyWith(
          autoRun: true,
          decomposedComponents: [
            PixelArtComponent(
              name: 'comp1',
              description: 'desc',
              relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
            ),
          ],
        );

        await notifier.sketchComponents();

        final state = errContainer.read(canvasStateProvider);
        expect(state.isGenerating, isFalse);
        expect(state.autoRun, isFalse);
      },
    );

    test(
      'refineCanvas resets isGenerating and autoRun to false on error',
      () async {
        final throwingAi = TestMockAiService(
          shouldThrow: true,
          exceptionMessage: 'AI execution failed',
        );
        final errContainer = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(throwingAi)],
        );
        addTearDown(errContainer.dispose);

        final notifier = errContainer.read(canvasStateProvider.notifier);
        notifier.setAutoRunState(autoRun: true, isPausing: false);

        await notifier.refineCanvas('refine prompt');

        final state = errContainer.read(canvasStateProvider);
        expect(state.isGenerating, isFalse);
        expect(state.autoRun, isFalse);
      },
    );
  });
}
