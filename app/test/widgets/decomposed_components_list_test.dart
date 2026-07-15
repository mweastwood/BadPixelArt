import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/decomposed_components_list.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../test_helper.dart';

void main() {
  group('DecomposedComponentsList Widget & Golden Tests', () {
    testWidgets(
      'renders initial state correctly when no components are present',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const Scaffold(body: DecomposedComponentsList()),
          ),
        );

        // Verify the header title
        expect(find.text('Drawing Plan Components'), findsOneWidget);
        expect(
          find.textContaining('No components decomposed yet'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'collapses and expands on header tap, showing components count',
      (tester) async {
        final container = ProviderContainer();
        // Setup some components
        final components = [
          PixelArtComponent(
            name: 'blade',
            description: 'vertical blade',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
          ),
        ];
        container.read(canvasStateProvider.notifier).state = container
            .read(canvasStateProvider)
            .copyWith(decomposedComponents: components);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: DecomposedComponentsList()),
            ),
          ),
        );

        // Verify initially expanded
        expect(find.text('BLADE'), findsOneWidget);
        expect(find.text('vertical blade'), findsOneWidget);

        // Tap the header to collapse
        await tester.tap(find.text('Drawing Plan Components'));
        await tester.pumpAndSettle();

        // Verify now collapsed (items are hidden, badge is shown)
        expect(find.text('BLADE'), findsNothing);
        expect(find.text('1 parts'), findsOneWidget);

        // Tap again to expand
        await tester.tap(find.text('Drawing Plan Components'));
        await tester.pumpAndSettle();

        expect(find.text('BLADE'), findsOneWidget);
      },
    );

    testWidgets('renders component details and updates selection on tap', (
      tester,
    ) async {
      final container = ProviderContainer();
      final components = [
        PixelArtComponent(
          name: 'blade',
          description: 'vertical blade',
          relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
        ),
        PixelArtComponent(
          name: 'hilt',
          description: 'wooden handle',
          relativeBoundingBox: const Rect.fromLTWH(0.45, 0.7, 0.1, 0.2),
        ),
      ];
      container.read(canvasStateProvider.notifier).state = container
          .read(canvasStateProvider)
          .copyWith(decomposedComponents: components, activeComponentIndex: 0);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: DecomposedComponentsList()),
          ),
        ),
      );

      // Verify both components are present
      expect(find.text('BLADE'), findsOneWidget);
      expect(find.text('HILT'), findsOneWidget);

      // Active component index should be 0 initially
      expect(
        container.read(canvasStateProvider).activeComponentIndex,
        equals(0),
      );

      // Tap on Hilt
      await tester.tap(find.text('HILT'));
      await tester.pumpAndSettle();

      // Active component index should update to 1
      expect(
        container.read(canvasStateProvider).activeComponentIndex,
        equals(1),
      );
    });

    testGoldens('DecomposedComponentsList renders disabled state by default', (
      tester,
    ) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
        ..addScenario(
          'Expanded Empty State (Disabled)',
          const DecomposedComponentsList(),
        )
        ..addScenario(
          'Collapsed Empty State',
          const DecomposedComponentsList(initialCollapsed: true),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'decomposed_components_list_disabled');
    });

    testGoldens(
      'DecomposedComponentsList renders enabled state with prompt and ref image',
      (tester) async {
        final mockNotifier = CanvasNotifier(TestMockAiService());
        mockNotifier.state = mockNotifier.state.copyWith(
          userPrompt: 'sword with red guard',
          referenceImage: Uint8List.fromList([0, 0, 0, 0]),
        );

        final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
          ..addScenario(
            'Expanded Empty State (Enabled)',
            const DecomposedComponentsList(),
          );

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: testMaterialAppWrapper(
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
            ],
          ),
        );
        await screenMatchesGolden(tester, 'decomposed_components_list_enabled');
      },
    );

    testGoldens('DecompositionOptionsDialog renders correctly', (tester) async {
      final option = [
        PixelArtComponent(
          name: 'blade',
          description: 'vertical blade',
          relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
        ),
      ];

      await tester.pumpWidgetBuilder(
        DecompositionOptionsDialog(
          options: [option, option, option, option],
          onSelected: (_) {},
          onCancel: () {},
        ),
        wrapper: testMaterialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'decomposition_options_dialog');
    });
  });
}
