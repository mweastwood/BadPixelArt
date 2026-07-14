import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/color_palette_generator.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_agent/local_agent.dart';
import '../test_helper.dart';

void main() {
  group('ColorPaletteGenerator Widget & Golden Tests', () {
    testWidgets(
      'renders preset selector and disabled AI/Quant options when no ref image',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const Scaffold(body: ColorPaletteGenerator()),
          ),
        );

        // Verify the header title
        expect(find.text('Color Palette'), findsOneWidget);
        expect(find.text('Select Preset'), findsOneWidget);

        // AI Suggest and Local Quant buttons should be disabled because referenceImage is null
        final aiSuggestBtn = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('AI Suggest'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(aiSuggestBtn.onPressed, isNull);

        final localQuantBtn = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('K-Means Quantization'),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(localQuantBtn.onPressed, isNull);

        // Helper message should be displayed
        expect(
          find.text(
            'Upload a reference image to unlock AI & Local Quantization.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('collapses and expands on header tap, showing mini swatches', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const Scaffold(body: ColorPaletteGenerator()),
        ),
      );

      // Initially expanded: Select Preset should be visible
      expect(find.text('Select Preset'), findsOneWidget);

      // Tap the header to collapse
      await tester.tap(find.text('Color Palette'));
      await tester.pumpAndSettle();

      // Now collapsed: Select Preset should be hidden
      expect(find.text('Select Preset'), findsNothing);

      // Tap the header again to expand
      await tester.tap(find.text('Color Palette'));
      await tester.pumpAndSettle();

      // Verify elements are visible again
      expect(find.text('Select Preset'), findsOneWidget);
    });

    testWidgets('enables AI/Quant options when reference image is present', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(TestMockAiService())],
      );
      final notifier = container.read(canvasStateProvider.notifier);

      final mockBmp = generateBmp(
        List.generate(16, (_) => List.filled(16, 0)),
        CanvasNotifier.primaryPalette,
      );

      // Set reference image bytes
      notifier.setReferenceImage(mockBmp);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const Scaffold(body: ColorPaletteGenerator()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify buttons are now enabled
      final aiSuggestBtn = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('AI Suggest'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(aiSuggestBtn.onPressed, isNotNull);

      final localQuantBtn = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('K-Means Quantization'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(localQuantBtn.onPressed, isNotNull);
    });

    testWidgets(
      'shows confirmation banner when showPaletteSuggestion is true',
      (tester) async {
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(TestMockAiService())],
        );
        final notifier = container.read(canvasStateProvider.notifier);

        final mockBmp = generateBmp(
          List.generate(16, (_) => List.filled(16, 0)),
          CanvasNotifier.primaryPalette,
        );

        // Set mock suggested palette & show flag
        notifier.setReferenceImage(mockBmp);

        // Manually trigger or override state to show suggestion
        container.read(canvasStateProvider.notifier).state = container
            .read(canvasStateProvider)
            .copyWith(
              suggestedPalette: const [Colors.red, Colors.green, Colors.blue],
              showPaletteSuggestion: true,
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: const Scaffold(body: ColorPaletteGenerator()),
            ),
          ),
        );

        await tester.pump();

        // Verify the confirmation elements
        expect(find.text('AI Suggestion Available'), findsOneWidget);
        expect(find.text('Accept'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
      },
    );

    testGoldens('ColorPaletteGenerator renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
        ..addScenario(
          'Primary Preset Selected (Expanded)',
          const ColorPaletteGenerator(),
        )
        ..addScenario(
          'Collapsed State',
          const ColorPaletteGenerator(initialCollapsed: true),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'color_palette_generator');
    });
  });
}
