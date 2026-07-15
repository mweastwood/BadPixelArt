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
      'renders preset selector and limits custom modes when no ref image',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const Scaffold(body: ColorPaletteGenerator()),
          ),
        );

        // Verify the header title
        expect(find.text('Color Palette'), findsOneWidget);
        expect(find.text('Color Palette Mode'), findsOneWidget);

        // Helper message should be displayed
        expect(
          find.text(
            'Upload a reference image to unlock AI & K-Means Quantization.',
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

      // Initially expanded
      expect(find.text('Color Palette Mode'), findsOneWidget);

      // Tap the header to collapse
      await tester.tap(find.text('Color Palette'));
      await tester.pumpAndSettle();

      // Now collapsed
      expect(find.text('Color Palette Mode'), findsNothing);

      // Tap the header again to expand
      await tester.tap(find.text('Color Palette'));
      await tester.pumpAndSettle();

      expect(find.text('Color Palette Mode'), findsOneWidget);
    });

    testWidgets(
      'allows selecting AI Suggested and K-Means when ref image is present',
      (tester) async {
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(TestMockAiService())],
        );
        final notifier = container.read(canvasStateProvider.notifier);

        final mockBmp = generateBmp(
          List.generate(16, (_) => List.filled(16, 0)),
          CanvasNotifier.primaryPalette,
        );

        notifier.setReferenceImage(mockBmp);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: ColorPaletteGenerator()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Open the dropdown
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        // Verify custom items are present
        expect(find.text('AI Suggested'), findsOneWidget);
        expect(find.text('K-Means Quantized'), findsOneWidget);

        // Tap K-Means Quantized
        await tester.tap(find.text('K-Means Quantized'));
        await tester.pumpAndSettle();

        // K-Means options row should now be visible
        expect(find.text('Colors:'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
        expect(find.text('8'), findsOneWidget);
        expect(find.text('16'), findsOneWidget);
      },
    );

    testWidgets(
      'changing K-Means color counts calls extractPaletteAlgorithmic',
      (tester) async {
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(TestMockAiService())],
        );
        final notifier = container.read(canvasStateProvider.notifier);

        final mockBmp = generateBmp(
          List.generate(16, (_) => List.filled(16, 0)),
          CanvasNotifier.primaryPalette,
        );

        notifier.setReferenceImage(mockBmp);
        notifier.extractPaletteAlgorithmic(8);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: ColorPaletteGenerator()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify active mode is K-Means, and choice chips are shown
        expect(find.text('Colors:'), findsOneWidget);

        // Tap on the 16 colors chip
        await tester.tap(find.text('16'));
        await tester.pumpAndSettle();

        // Palette should now contain 16 colors
        expect(
          container.read(canvasStateProvider).paletteName,
          equals('algorithmic'),
        );
        expect(container.read(canvasStateProvider).palette.length, equals(16));
      },
    );

    testGoldens('ColorPaletteGenerator renders presets by default', (
      tester,
    ) async {
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
      await screenMatchesGolden(tester, 'color_palette_generator_presets');
    });

    testGoldens(
      'ColorPaletteGenerator renders K-Means Quantized active state',
      (tester) async {
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(TestMockAiService())],
        );
        final notifier = container.read(canvasStateProvider.notifier);
        final mockBmp = generateBmp(
          List.generate(16, (_) => List.filled(16, 0)),
          CanvasNotifier.primaryPalette,
        );
        notifier.setReferenceImage(mockBmp);
        notifier.extractPaletteAlgorithmic(8);

        final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
          ..addScenario(
            'K-Means Selected with Color Chips',
            const ColorPaletteGenerator(),
          );

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: testMaterialAppWrapper(
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
          ),
        );
        await screenMatchesGolden(tester, 'color_palette_generator_kmeans');
      },
    );

    testGoldens('ColorPaletteGenerator renders AI Suggested active state', (
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
      notifier.setReferenceImage(mockBmp);

      container.read(canvasStateProvider.notifier).state = container
          .read(canvasStateProvider)
          .copyWith(
            suggestedPalette: const [Colors.red, Colors.green, Colors.blue],
            paletteName: 'suggested',
            palette: const [Colors.red, Colors.green, Colors.blue],
          );

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
        ..addScenario('AI Suggested Selected', const ColorPaletteGenerator());

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(
          overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
        ),
      );
      await screenMatchesGolden(tester, 'color_palette_generator_suggested');
    });

    testGoldens(
      'ColorPaletteGenerator renders loading state when AI suggesting',
      (tester) async {
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(TestMockAiService())],
        );
        final notifier = container.read(canvasStateProvider.notifier);
        final mockBmp = generateBmp(
          List.generate(16, (_) => List.filled(16, 0)),
          CanvasNotifier.primaryPalette,
        );
        notifier.setReferenceImage(mockBmp);

        container.read(canvasStateProvider.notifier).state = container
            .read(canvasStateProvider)
            .copyWith(isSuggestingPalette: true, paletteName: 'suggested');

        final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
          ..addScenario(
            'AI Suggested Loading State',
            const ColorPaletteGenerator(),
          );

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: testMaterialAppWrapper(
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
          ),
        );
        await screenMatchesGolden(
          tester,
          'color_palette_generator_loading',
          customPump: (tester) async => tester.pump(),
        );
      },
    );
  });
}
