import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/shape_decomposition_list.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_agent/local_agent.dart';
import '../test_helper.dart';

class LocalMockAiService extends AiService {
  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    return '''
    [
      {"type": "rectangle", "relativeBoundingBox": {"left": 0.0, "top": 0.0, "width": 1.0, "height": 0.8}, "description": "steel body"},
      {"type": "triangle", "relativeBoundingBox": {"left": 0.0, "top": 0.8, "width": 1.0, "height": 0.2}, "description": "pointy tip"}
    ]
    ''';
  }

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) async {}
}

void main() {
  group('ShapeDecompositionList Widget & Golden Tests', () {
    testWidgets(
      'renders initial state correctly when no components are present',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const Scaffold(body: ShapeDecompositionList()),
          ),
        );

        // Verify the header title
        expect(find.text('Shape Decomposition'), findsOneWidget);
        expect(
          find.textContaining('No drawing plan generated yet'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'collapses and expands on header tap, showing components count',
      (tester) async {
        final container = ProviderContainer();
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
              home: Scaffold(body: ShapeDecompositionList()),
            ),
          ),
        );

        // Verify initially expanded
        expect(find.text('BLADE'), findsOneWidget);
        expect(find.text('vertical blade'), findsOneWidget);

        // Tap the header to collapse
        await tester.tap(find.text('Shape Decomposition'));
        await tester.pumpAndSettle();

        // Verify now collapsed (items are hidden, badge is shown)
        expect(find.text('BLADE'), findsNothing);
        expect(find.text('1 parts'), findsOneWidget);

        // Tap again to expand
        await tester.tap(find.text('Shape Decomposition'));
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
            home: Scaffold(body: ShapeDecompositionList()),
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

    testWidgets('renders component fundamental shape chips', (tester) async {
      final container = ProviderContainer();
      final components = [
        PixelArtComponent(
          name: 'blade',
          description: 'vertical blade',
          relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
          shapes: [
            FundamentalShape(
              type: 'rectangle',
              description: 'steel body',
              relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 0.8),
            ),
            FundamentalShape(
              type: 'triangle',
              description: 'pointy tip',
              relativeBoundingBox: const Rect.fromLTWH(0.0, 0.8, 1.0, 0.2),
            ),
          ],
        ),
      ];
      container.read(canvasStateProvider.notifier).state = container
          .read(canvasStateProvider)
          .copyWith(decomposedComponents: components, activeComponentIndex: 0);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ShapeDecompositionList()),
          ),
        ),
      );

      // Verify the shapes chips description text is rendered
      expect(find.text('steel body'), findsOneWidget);
      expect(find.text('pointy tip'), findsOneWidget);
    });

    testWidgets(
      'triggers shape decomposition for individual component on tap',
      (tester) async {
        final mockService = LocalMockAiService();
        final notifier = CanvasNotifier(mockService);
        final components = [
          PixelArtComponent(
            name: 'blade',
            description: 'vertical blade',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
          ),
        ];
        notifier.state = notifier.state.copyWith(
          decomposedComponents: components,
          userPrompt: 'sword',
          referenceImage: Uint8List.fromList([0, 0, 0, 0]),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiServiceProvider.overrideWithValue(mockService),
              canvasStateProvider.overrideWith((ref) => notifier),
            ],
            child: const MaterialApp(
              home: Scaffold(body: ShapeDecompositionList()),
            ),
          ),
        );

        // Find the Decompose into Shapes button (IconButton)
        final buttonFinder = find.byTooltip('Decompose into Shapes');
        expect(buttonFinder, findsOneWidget);

        // Tap to decompose
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        // Verify it updates state and calls AI
        expect(notifier.state.decomposedComponents[0].shapes, isNotEmpty);
      },
    );

    testGoldens('ShapeDecompositionList renders disabled state by default', (
      tester,
    ) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
        ..addScenario(
          'Expanded Empty State (Disabled)',
          const ShapeDecompositionList(),
        )
        ..addScenario(
          'Collapsed Empty State',
          const ShapeDecompositionList(initialCollapsed: true),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'shape_decomposition_list_disabled');
    });

    testGoldens(
      'ShapeDecompositionList renders enabled state with components',
      (tester) async {
        final mockNotifier = CanvasNotifier(TestMockAiService());
        final components = [
          PixelArtComponent(
            name: 'blade',
            description: 'vertical blade',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
            shapes: [
              FundamentalShape(
                type: 'rectangle',
                description: 'steel body',
                relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 0.8),
              ),
            ],
          ),
        ];
        mockNotifier.state = mockNotifier.state.copyWith(
          decomposedComponents: components,
          userPrompt: 'sword',
          referenceImage: Uint8List.fromList([0, 0, 0, 0]),
        );

        final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
          ..addScenario(
            'Expanded State with Components',
            const ShapeDecompositionList(),
          );

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: testMaterialAppWrapper(
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
            ],
          ),
        );
        await screenMatchesGolden(tester, 'shape_decomposition_list_enabled');
      },
    );
  });
}
