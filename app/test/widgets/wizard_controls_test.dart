import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_agent/local_agent.dart';
import 'package:bad_pixel_art/screens/pixel_art_screen.dart';
import 'package:bad_pixel_art/widgets/wizard_controls.dart';
import 'package:bad_pixel_art/widgets/reference_image_prompt.dart';
import 'package:bad_pixel_art/widgets/color_palette_generator.dart';
import 'package:bad_pixel_art/widgets/decomposed_components_list.dart';
import 'package:bad_pixel_art/widgets/shape_decomposition_list.dart';
import 'package:bad_pixel_art/widgets/ai_history_dock.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import '../test_helper.dart';

class WizardMockAiService extends AiService {
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
      'shows ReferenceImagePrompt in Step 0 and navigates correctly across 4 steps using FABs',
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
            child: const PixelArtScreen(),
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
          ),
        );

        // Verify Step 0 widgets are present
        expect(find.byType(ReferenceImagePrompt), findsOneWidget);
        expect(find.byType(ColorPaletteGenerator), findsNothing);

        // Next FAB should be disabled initially (no prompt provided)
        final nextButtonFinder = find.byKey(const ValueKey('wizard_next_fab'));
        expect(
          tester.widget<FloatingActionButton>(nextButtonFinder).onPressed,
          isNull,
        );

        // Update prompt in state to enable Next FAB
        notifier.updatePrompt('a cool sword');
        await tester.pumpAndSettle();

        expect(
          tester.widget<FloatingActionButton>(nextButtonFinder).onPressed,
          isNotNull,
        );

        // Tap Next FAB to go to Step 1
        await tester.tap(nextButtonFinder);
        await tester.pumpAndSettle();

        // Verify Step 1 widgets are present
        expect(find.byType(ReferenceImagePrompt), findsNothing);
        expect(find.byType(ColorPaletteGenerator), findsOneWidget);

        // Tap Back FAB to go back to Step 0
        final backButtonFinder = find.byKey(const ValueKey('wizard_back_fab'));
        await tester.tap(backButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(ReferenceImagePrompt), findsOneWidget);
        expect(find.byType(ColorPaletteGenerator), findsNothing);

        // Navigate back to Step 1
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        // Tap Next FAB in Step 1 to go to Step 2
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        // Next FAB should be disabled initially in Step 2 (no drawing plan generated yet)
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byKey(const ValueKey('wizard_next_fab')),
              )
              .onPressed,
          isNull,
        );

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

        // Next FAB should now be enabled
        expect(
          tester
              .widget<FloatingActionButton>(
                find.byKey(const ValueKey('wizard_next_fab')),
              )
              .onPressed,
          isNotNull,
        );

        // Verify Step 2 widgets are present (Semantic plan component list)
        expect(find.byType(ColorPaletteGenerator), findsNothing);
        expect(find.byType(SemanticComponentsList), findsOneWidget);
        expect(find.byType(AiHistoryDock), findsOneWidget); // Always visible!

        // Tap Back FAB in Step 2 to go back to Step 1
        await tester.tap(find.byKey(const ValueKey('wizard_back_fab')));
        await tester.pumpAndSettle();

        expect(find.byType(ColorPaletteGenerator), findsOneWidget);
        expect(find.byType(SemanticComponentsList), findsNothing);

        // Navigate back to Step 2
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        // Tap Next FAB in Step 2 to run AI and go to Step 3
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        // Verify Step 3 widgets are present
        expect(find.byType(ShapeDecompositionList), findsOneWidget);
        expect(
          find.byType(AiHistoryDock),
          findsOneWidget,
        ); // History dock is in step 3!

        // Tap Back to Semantic Components to go back to Step 2
        await tester.tap(find.byKey(const ValueKey('wizard_back_fab')));
        await tester.pumpAndSettle();

        expect(find.byType(SemanticComponentsList), findsOneWidget);
        expect(find.byType(AiHistoryDock), findsOneWidget);
      },
    );

    testGoldens('WizardControls renders each step correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.5)
        ..addScenario(
          'Step 0: Reference & Prompt',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(0)),
            ],
            child: const WizardControls(),
          ),
        )
        ..addScenario(
          'Step 1: Color Palette',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(1)),
            ],
            child: const WizardControls(),
          ),
        )
        ..addScenario(
          'Step 2: Semantic Plan',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(2)),
            ],
            child: const WizardControls(),
          ),
        )
        ..addScenario(
          'Step 3: Shapes Plan & Sketching',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(3)),
            ],
            child: const WizardControls(),
          ),
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
        surfaceSize: const Size(500, 3200),
      );
      await multiScreenGolden(
        tester,
        'wizard_controls_steps',
        devices: [const Device(name: 'wizard_panel', size: Size(500, 3200))],
      );
    });
  });
}
