import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/decomposed_components_list.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../test_helper.dart';

void main() {
  group('DecomposedComponentsList Widget & Golden Tests', () {
    testWidgets(
      'renders initial state correctly when no components are present',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const Scaffold(body: SemanticComponentsList()),
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
            home: Scaffold(body: SemanticComponentsList()),
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

    testGoldens('SemanticComponentsList renders disabled state by default', (
      tester,
    ) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
        ..addScenario('Empty State (Disabled)', const SemanticComponentsList());

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'decomposed_components_list_disabled');
    });

    testGoldens(
      'SemanticComponentsList renders enabled state with prompt and ref image',
      (tester) async {
        final mockNotifier = CanvasNotifier(TestMockAiService());
        mockNotifier.state = mockNotifier.state.copyWith(
          userPrompt: 'sword with red guard',
          referenceImage: Uint8List.fromList([0, 0, 0, 0]),
        );

        final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
          ..addScenario(
            'Expanded Empty State (Enabled)',
            const SemanticComponentsList(),
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

    testWidgets(
      'displays pixel coordinates and removes component when delete button is pressed',
      (tester) async {
        final container = ProviderContainer();
        final components = [
          PixelArtComponent(
            name: 'blade',
            description: 'vertical blade',
            relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 0.5, 1.0),
          ),
          PixelArtComponent(
            name: 'hilt',
            description: 'wooden handle',
            relativeBoundingBox: const Rect.fromLTWH(0.5, 0.0, 0.5, 0.5),
          ),
        ];
        container.read(canvasStateProvider.notifier).state = container
            .read(canvasStateProvider)
            .copyWith(
              decomposedComponents: components,
              activeComponentIndex: 0,
              gridSize: 16,
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: SemanticComponentsList()),
            ),
          ),
        );

        // Verify pixel coordinates are displayed (e.g. X: 0..7, Y: 0..15)
        expect(find.text('[X: 0..7, Y: 0..15]'), findsOneWidget);
        expect(find.text('[X: 8..15, Y: 0..7]'), findsOneWidget);

        // Verify 2 delete icon buttons
        final deleteButtons = find.byTooltip('Delete Component');
        expect(deleteButtons, findsNWidgets(2));

        // Delete first component ('blade')
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Verify 'BLADE' was deleted and only 'HILT' remains
        final remaining = container
            .read(canvasStateProvider)
            .decomposedComponents;
        expect(remaining.length, equals(1));
        expect(remaining.first.name, equals('hilt'));
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
