import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_agent/local_agent.dart';
import 'package:bad_pixel_art/widgets/wizard_controls.dart';
import 'package:bad_pixel_art/widgets/reference_image_prompt.dart';
import 'package:bad_pixel_art/widgets/color_palette_generator.dart';
import 'package:bad_pixel_art/widgets/decomposed_components_list.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import '../test_helper.dart';

void main() {
  group('WizardControls Widget & Golden Tests', () {
    testWidgets(
      'shows ReferenceImagePrompt in Step 0 and navigates correctly',
      (tester) async {
        final mockAiService = TestMockAiService();
        final notifier = CanvasNotifier(mockAiService);

        await tester.pumpWidget(
          buildTestableWidget(
            child: const WizardControls(),
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
          ),
        );

        // Verify Step 0 widgets are present
        expect(find.byType(ReferenceImagePrompt), findsOneWidget);
        expect(find.byType(ColorPaletteGenerator), findsNothing);

        // Next button should be disabled initially (no prompt provided)
        final nextButtonFinder = find.byKey(
          const ValueKey('wizard_next_to_palette'),
        );
        expect(
          tester.widget<ElevatedButton>(nextButtonFinder).onPressed,
          isNull,
        );

        // Update prompt in state to enable Next button
        notifier.updatePrompt('a cool sword');
        await tester.pumpAndSettle();

        expect(
          tester.widget<ElevatedButton>(nextButtonFinder).onPressed,
          isNotNull,
        );

        // Tap Next button to go to Step 1
        await tester.tap(nextButtonFinder);
        await tester.pumpAndSettle();

        // Verify Step 1 widgets are present
        expect(find.byType(ReferenceImagePrompt), findsNothing);
        expect(find.byType(ColorPaletteGenerator), findsOneWidget);

        // Tap Back button to go back to Step 0
        final backButtonFinder = find.byKey(
          const ValueKey('wizard_back_to_prompt'),
        );
        await tester.tap(backButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(ReferenceImagePrompt), findsOneWidget);
        expect(find.byType(ColorPaletteGenerator), findsNothing);

        // Navigate back to Step 1
        await tester.tap(find.byKey(const ValueKey('wizard_next_to_palette')));
        await tester.pumpAndSettle();

        // Tap Next button in Step 1 to go to Step 2
        final nextToSketchButton = find.byKey(
          const ValueKey('wizard_next_to_decomposed'),
        );
        await tester.tap(nextToSketchButton);
        await tester.pumpAndSettle();

        // Verify Step 2 widgets are present
        expect(find.byType(ColorPaletteGenerator), findsNothing);
        expect(find.byType(DecomposedComponentsList), findsOneWidget);

        // Tap Back button in Step 2 to go back to Step 1
        final backToPaletteButton = find.byKey(
          const ValueKey('wizard_back_to_palette'),
        );
        await tester.tap(backToPaletteButton);
        await tester.pumpAndSettle();

        expect(find.byType(ColorPaletteGenerator), findsOneWidget);
        expect(find.byType(DecomposedComponentsList), findsNothing);
      },
    );

    testGoldens('WizardControls renders each step correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.4)
        ..addScenario(
          'Step 0: Reference & Prompt',
          const WizardControls(initialStep: 0),
        )
        ..addScenario(
          'Step 1: Color Palette',
          const WizardControls(initialStep: 1),
        )
        ..addScenario(
          'Step 2: Drawing Plan',
          const WizardControls(initialStep: 2),
        );

      Widget customWrapper(Widget child) {
        return ProviderScope(
          overrides: [aiServiceProvider.overrideWithValue(TestMockAiService())],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Padding(padding: const EdgeInsets.all(8.0), child: child),
            ),
          ),
        );
      }

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: customWrapper,
        surfaceSize: const Size(500, 3800),
      );
      await multiScreenGolden(
        tester,
        'wizard_controls_steps',
        devices: [const Device(name: 'wizard_panel', size: Size(500, 3800))],
      );
    });
  });
}
