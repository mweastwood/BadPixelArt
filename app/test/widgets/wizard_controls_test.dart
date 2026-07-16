import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/widgets/wizard_controls.dart';
import 'package:bad_pixel_art/widgets/reference_image_prompt.dart';
import 'package:bad_pixel_art/widgets/color_palette_generator.dart';
import 'package:bad_pixel_art/widgets/decomposed_components_list.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import '../test_helper.dart';

void main() {
  group('WizardControls Widget Tests', () {
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
  });
}
