import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/screens/pixel_art_screen.dart';
import 'package:bad_pixel_art/widgets/wizard_controls.dart';
import 'package:bad_pixel_art/widgets/grid_size_selection_card.dart';
import 'package:bad_pixel_art/widgets/reference_image_prompt.dart';
import 'package:bad_pixel_art/widgets/color_palette_generator.dart';
import 'package:bad_pixel_art/widgets/decomposed_components_list.dart';
import 'package:bad_pixel_art/widgets/shape_decomposition_list.dart';
import 'package:bad_pixel_art/widgets/component_color_selection_list.dart';
import 'package:bad_pixel_art/widgets/layer_ordering_list.dart';
import 'package:bad_pixel_art/widgets/refinement_panel.dart';

import 'package:bad_pixel_art/logic/canvas_state.dart';
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

  @override
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    return 100;
  }
}

void main() {
  group('WizardControls Widget & Golden Tests', () {
    testWidgets(
      'shows GridSizeSelectionCard in Step 0 and navigates correctly across steps using FABs',
      (tester) async {
        final mockAiService = WizardMockAiService(
          responseToReturn:
              '[{"type": "rectangle", "description": "steel body", "relativeBoundingBox": {"left":0.0, "top":0.0, "width":1.0, "height":0.8}}]',
        );
        final notifier = CanvasNotifier(mockAiService);
        notifier.state = notifier.state.copyWith(
          decomposedComponents: const [],
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: const PixelArtScreen(),
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
          ),
        );

        // Verify Step 0 widgets (GridSizeSelectionCard) are present
        expect(find.byType(GridSizeSelectionCard), findsOneWidget);

        // Tap Next FAB in Step 0 to go to Step 1 (ReferenceImagePrompt)
        final nextButtonFinder = find.byKey(const ValueKey('wizard_next_fab'));
        await tester.tap(nextButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(ReferenceImagePrompt), findsOneWidget);

        // Next FAB should be disabled initially in Step 1 (no prompt provided)
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

        // Tap Next FAB to go to Step 2 (ColorPaletteGenerator)
        await tester.tap(nextButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(ColorPaletteGenerator), findsOneWidget);

        // Tap Back FAB to return to Step 1
        final backButtonFinder = find.byKey(const ValueKey('wizard_back_fab'));
        await tester.tap(backButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(ReferenceImagePrompt), findsOneWidget);

        // Tap Next FAB to go to Step 2
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        // Tap Next FAB in Step 2 to go to Step 3 (SemanticComponentsList)
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        // Inject components for Step 3
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

        expect(find.byType(SemanticComponentsList), findsOneWidget);

        // Tap Next FAB in Step 3 to go to Step 4 (ShapeDecompositionList)
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        expect(find.byType(ShapeDecompositionList), findsOneWidget);

        // Tap Next FAB in Step 4 to go to Step 5 (ComponentColorSelectionList)
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        expect(find.byType(ComponentColorSelectionList), findsOneWidget);

        // Tap Next FAB in Step 5 to go to Step 6 (LayerOrderingList)
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        expect(find.byType(LayerOrderingList), findsOneWidget);

        // Tap Next FAB in Step 6 to go to Step 7 (RefinementPanel)
        await tester.tap(find.byKey(const ValueKey('wizard_next_fab')));
        await tester.pumpAndSettle();

        expect(find.byType(RefinementPanel), findsOneWidget);
      },
    );

    testGoldens('WizardControls renders each step correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 0.5)
        ..addScenario(
          'Step 0: Select Grid Size',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(0)),
            ],
            child: const WizardControls(),
          ),
        )
        ..addScenario(
          'Step 1: Reference & Prompt',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(1)),
            ],
            child: const WizardControls(),
          ),
        )
        ..addScenario(
          'Step 2: Color Palette',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(2)),
            ],
            child: const WizardControls(),
          ),
        )
        ..addScenario(
          'Step 3: Semantic Plan',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(3)),
            ],
            child: const WizardControls(),
          ),
        )
        ..addScenario(
          'Step 4: Shapes Plan & Sketching',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(4)),
            ],
            child: const WizardControls(),
          ),
        )
        ..addScenario(
          'Step 5: Pick Component Colors',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(5)),
            ],
            child: const WizardControls(),
          ),
        )
        ..addScenario(
          'Step 6: Define Layer Order',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(6)),
            ],
            child: const WizardControls(),
          ),
        )
        ..addScenario(
          'Step 7: Refine Pixel Art',
          ProviderScope(
            overrides: [
              wizardStateProvider.overrideWith((ref) => WizardNotifier(7)),
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
        surfaceSize: const Size(500, 6400),
      );
      await multiScreenGolden(
        tester,
        'wizard_controls_steps',
        devices: [const Device(name: 'wizard_panel', size: Size(500, 6400))],
      );
    });
  });
}
