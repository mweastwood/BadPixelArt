import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_agent/local_agent.dart';
import 'package:bad_pixel_art/widgets/wizard_controls.dart';
import 'package:bad_pixel_art/widgets/reference_image_prompt.dart';
import 'package:bad_pixel_art/widgets/color_palette_generator.dart';
import 'package:bad_pixel_art/widgets/decomposed_components_list.dart';
import 'package:bad_pixel_art/widgets/ai_history_dock.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import '../test_helper.dart';

class WizardMockAiService implements AiService {
  final String? responseToReturn;

  WizardMockAiService({this.responseToReturn});

  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double? temperature,
    int? maxOutputTokens,
  }) async {
    if (responseToReturn != null) return responseToReturn;
    if (prompt.contains('palette') || prompt.contains('colors')) {
      return '["#000000", "#ffffff", "#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff"]';
    }
    return null;
  }
}

void main() {
  group('WizardControls Widget & Golden Tests', () {
    testWidgets(
      'shows ReferenceImagePrompt in Step 0 and navigates correctly across 4 steps',
      (tester) async {
        final mockAiService = WizardMockAiService(
          responseToReturn:
              '[{"type": "rectangle", "description": "steel body", "relativeBoundingBox": {"left":0.0, "top":0.0, "width":1.0, "height":0.8}}]',
        );
        final notifier = CanvasNotifier(mockAiService);
        // Setup initial component to allow step 2 -> step 3 decomposition
        notifier.state = notifier.state.copyWith(
          decomposedComponents: const [],
        );

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
        final nextToDecomposedButton = find.byKey(
          const ValueKey('wizard_next_to_decomposed'),
        );
        await tester.tap(nextToDecomposedButton);
        await tester.pumpAndSettle();

        // Inject components once we are in Step 2 so we have items to show/decompose
        notifier.state = notifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'sharp blade',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
            ),
          ],
        );
        await tester.pumpAndSettle();

        // Verify Step 2 widgets are present (Semantic plan component list)
        expect(find.byType(ColorPaletteGenerator), findsNothing);
        expect(find.byType(DecomposedComponentsList), findsOneWidget);
        expect(find.byType(AiHistoryDock), findsNothing); // Not in step 2!

        // Tap Back button in Step 2 to go back to Step 1
        final backToPaletteButton = find.byKey(
          const ValueKey('wizard_back_to_palette'),
        );
        await tester.tap(backToPaletteButton);
        await tester.pumpAndSettle();

        expect(find.byType(ColorPaletteGenerator), findsOneWidget);
        expect(find.byType(DecomposedComponentsList), findsNothing);

        // Navigate back to Step 2
        await tester.tap(
          find.byKey(const ValueKey('wizard_next_to_decomposed')),
        );
        await tester.pumpAndSettle();

        // Tap Next: Decompose to Shapes in Step 2 to run AI and go to Step 3
        final nextToShapesButton = find.byKey(
          const ValueKey('wizard_next_to_shapes'),
        );
        await tester.tap(nextToShapesButton);
        await tester.pumpAndSettle();

        // Verify Step 3 widgets are present
        expect(find.byType(DecomposedComponentsList), findsOneWidget);
        expect(
          find.byType(AiHistoryDock),
          findsOneWidget,
        ); // History dock is in step 3!

        // Tap Back to Semantic Components to go back to Step 2
        final backToComponentsButton = find.byKey(
          const ValueKey('wizard_back_to_components'),
        );
        await tester.tap(backToComponentsButton);
        await tester.pumpAndSettle();

        expect(find.byType(DecomposedComponentsList), findsOneWidget);
        expect(find.byType(AiHistoryDock), findsNothing);
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
          'Step 2: Semantic Plan',
          const WizardControls(initialStep: 2),
        )
        ..addScenario(
          'Step 3: Shapes Plan & Sketching',
          const WizardControls(initialStep: 3),
        );

      Widget customWrapper(Widget child) {
        return ProviderScope(
          overrides: [
            aiServiceProvider.overrideWithValue(WizardMockAiService()),
          ],
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
        surfaceSize: const Size(500, 5000),
      );
      await multiScreenGolden(
        tester,
        'wizard_controls_steps',
        devices: [const Device(name: 'wizard_panel', size: Size(500, 5000))],
      );
    });
  });
}
