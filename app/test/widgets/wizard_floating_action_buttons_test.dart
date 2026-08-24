import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/widgets/wizard_floating_action_buttons.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../test_helper.dart';

void main() {
  group('WizardFloatingActionButtons Widget & Strategy Tests', () {
    testWidgets(
      'Step 0 (selectGridSize): Back FAB is hidden, Next FAB advances to setupPrompt',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        final wizardNotifier = WizardNotifier(0);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const WizardFloatingActionButtons(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('wizard_back_fab')), findsNothing);
        expect(find.byKey(const ValueKey('auto_play_fab')), findsOneWidget);
        expect(find.byKey(const ValueKey('wizard_next_fab')), findsOneWidget);

        // Tap Next FAB
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.setupPrompt),
        );
      },
    );

    testWidgets(
      'Step 1 (setupPrompt): Back FAB goes to Step 0, Next FAB is gated by userPrompt',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        final wizardNotifier = WizardNotifier(1);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const WizardFloatingActionButtons(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('wizard_back_fab')), findsOneWidget);
        expect(find.byKey(const ValueKey('wizard_next_fab')), findsOneWidget);

        // Next FAB is disabled with empty prompt
        final nextFab = tester.widget<FloatingActionButton>(
          find.byKey(const ValueKey('wizard_next_fab')),
        );
        expect(nextFab.onPressed, isNull);

        // Set prompt
        notifier.updatePrompt('magic wand');
        await tester.pumpAndSettle();

        final enabledNextFab = tester.widget<FloatingActionButton>(
          find.byKey(const ValueKey('wizard_next_fab')),
        );
        expect(enabledNextFab.onPressed, isNotNull);

        // Tap Next FAB to advance to selectPalette
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();
        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.selectPalette),
        );

        // Tap Back FAB to return to selectGridSize
        wizardNotifier.setStep(WizardStep.setupPrompt);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('wizard_back_fab')));
        await tester.pumpAndSettle();
        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.selectGridSize),
        );
      },
    );

    testWidgets(
      'Step 2 (selectPalette): navigates to sketchingPlan and setupPrompt',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        final wizardNotifier = WizardNotifier(2);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const WizardFloatingActionButtons(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Advance to sketchingPlan
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();
        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.sketchingPlan),
        );

        // Back to setupPrompt
        wizardNotifier.setStep(WizardStep.selectPalette);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('wizard_back_fab')));
        await tester.pumpAndSettle();
        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.setupPrompt),
        );
      },
    );

    testWidgets(
      'Step 3 (sketchingPlan): Next FAB gated by isGenerating and decomposedComponents',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        final wizardNotifier = WizardNotifier(3);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const WizardFloatingActionButtons(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Initially disabled (no components)
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byKey(const ValueKey('wizard_next_fab')),
              )
              .onPressed,
          isNull,
        );

        // Add component
        notifier.state = notifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'hat',
              description: 'wizard hat',
              relativeBoundingBox: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<FloatingActionButton>(
                find.byKey(const ValueKey('wizard_next_fab')),
              )
              .onPressed,
          isNotNull,
        );

        // Disabled when generating
        notifier.state = notifier.state.copyWith(isGenerating: true);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byKey(const ValueKey('wizard_next_fab')),
              )
              .onPressed,
          isNull,
        );

        notifier.state = notifier.state.copyWith(isGenerating: false);
        await tester.pumpAndSettle();

        // Tap Next FAB to go to componentSculpting
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();
        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.componentSculpting),
        );
      },
    );

    testWidgets(
      'Step 4 (componentSculpting): Next FAB gated by decomposedComponents',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        final wizardNotifier = WizardNotifier(4);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const WizardFloatingActionButtons(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Disabled without components
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byKey(const ValueKey('wizard_next_fab')),
              )
              .onPressed,
          isNull,
        );

        notifier.state = notifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'body',
              description: 'shield',
              relativeBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
            ),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();
        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.colorAndOutline),
        );
      },
    );

    testWidgets(
      'Step 5 (colorAndOutline): Next FAB gated by decomposedComponents',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        final wizardNotifier = WizardNotifier(5);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const WizardFloatingActionButtons(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Disabled without components
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byKey(const ValueKey('wizard_next_fab')),
              )
              .onPressed,
          isNull,
        );

        notifier.state = notifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'gem',
              description: 'red gem',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.4, 0.2, 0.2),
            ),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();
        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.layerOrderingAndMerge),
        );
      },
    );

    testWidgets(
      'Step 6 (layerOrderingAndMerge): merges components and advances to refinement',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        final wizardNotifier = WizardNotifier(6);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const WizardFloatingActionButtons(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();
        expect(wizardNotifier.state.currentStep, equals(WizardStep.refinement));
      },
    );

    testWidgets(
      'Step 7 (refinement): Next FAB is hidden, Back FAB navigates to layerOrderingAndMerge',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        final wizardNotifier = WizardNotifier(7);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const WizardFloatingActionButtons(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('wizard_next_fab')), findsNothing);
        expect(find.byKey(const ValueKey('wizard_back_fab')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('wizard_back_fab')));
        await tester.pumpAndSettle();
        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.layerOrderingAndMerge),
        );
      },
    );

    testWidgets(
      'Auto-Play active and pausing states disable Next/Back navigation and show proper icons',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        final wizardNotifier = WizardNotifier(1);
        notifier.state = notifier.state.copyWith(
          referenceImage: Uint8List.fromList([1, 2, 3]),
          autoRun: true,
          isPausing: false,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: const WizardFloatingActionButtons(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // During auto-play, Back and Next are disabled
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byKey(const ValueKey('wizard_back_fab')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byKey(const ValueKey('wizard_next_fab')),
              )
              .onPressed,
          isNull,
        );
        expect(find.byIcon(Icons.pause), findsOneWidget);

        // Tap pause
        await tester.tap(find.byKey(const ValueKey('auto_play_fab')));
        await tester.pump();
        expect(notifier.state.autoRun, isFalse);

        // Test isPausing spinner state
        notifier.state = notifier.state.copyWith(
          autoRun: true,
          isPausing: true,
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        notifier.stopAutoPlay();
      },
    );

    testWidgets(
      'Direct Mode: Step 2 (selectPalette) navigates directly to refinement, and Step 3 (refinement) goes back to selectPalette',
      (tester) async {
        final mockAi = MockAiService();
        final notifier = CanvasNotifier(mockAi);
        final wizardNotifier = WizardNotifier(
          WizardStep.selectPalette,
          null,
          WizardMode.direct,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: const WizardFloatingActionButtons(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => notifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(wizardNotifier.mode, equals(WizardMode.direct));
        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.selectPalette),
        );

        // Advance forward from selectPalette -> refinement directly
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        expect(wizardNotifier.state.currentStep, equals(WizardStep.refinement));
        expect(find.byKey(const ValueKey('wizard_next_fab')), findsNothing);
        expect(find.byKey(const ValueKey('wizard_back_fab')), findsOneWidget);

        // Tap Back FAB in refinement -> returns directly to selectPalette
        await tester.tap(find.byKey(const ValueKey('wizard_back_fab')));
        await tester.pumpAndSettle();

        expect(
          wizardNotifier.state.currentStep,
          equals(WizardStep.selectPalette),
        );
      },
    );
  });
}
