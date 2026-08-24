import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';
import 'package:bad_pixel_art/widgets/layer_ordering_list.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/utils/logging_ai_service.dart';
import '../test_helper.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('LayerOrderingList Widget & Golden Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      AppDatabaseHelper.db = db;
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('renders layers and triggers reorder and merge actions', (
      tester,
    ) async {
      final mockComponents = [
        PixelArtComponent(
          name: 'Blade',
          description: 'A sharp blade',
          relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
          shapes: [],
        ),
        PixelArtComponent(
          name: 'Hilt',
          description: 'Hilt guard',
          relativeBoundingBox: const Rect.fromLTWH(0.4, 0.7, 0.2, 0.2),
          shapes: [],
        ),
      ];

      int? reorderedOldIndex;
      int? reorderedNewIndex;
      bool mergeCalled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            canvasStateProvider.overrideWith((ref) {
              final aiService = ref.watch(loggingAiServiceProvider);
              final notifier = _MockLayerCanvasNotifier(
                aiService,
                onReorder: (oldIdx, newIdx) {
                  reorderedOldIndex = oldIdx;
                  reorderedNewIndex = newIdx;
                },
                onMerge: () {
                  mergeCalled = true;
                },
              );
              notifier.state = notifier.state.copyWith(
                decomposedComponents: mockComponents,
              );
              return notifier;
            }),
          ],
          child: const Scaffold(body: LayerOrderingList()),
        ),
      );

      // Verify layers are rendered
      expect(find.text('Blade'), findsOneWidget);
      expect(find.text('Hilt'), findsOneWidget);

      // Tap on down arrow of first item to trigger reorder
      final downArrow = find.byIcon(Icons.keyboard_arrow_down).first;
      await tester.tap(downArrow);
      await tester.pumpAndSettle();

      expect(reorderedOldIndex, equals(0));
      expect(
        reorderedNewIndex,
        equals(2),
      ); // index + 2 is passed when shifting down

      // Tap on merge button
      final mergeButton = find.byType(ElevatedButton);
      await tester.tap(mergeButton);
      await tester.pumpAndSettle();

      expect(mergeCalled, isTrue);
    });

    testWidgets(
      'renders and reorders components with duplicate names without crash',
      (tester) async {
        final duplicateComponents = [
          PixelArtComponent(
            name: 'Eye',
            description: 'Left eye',
            relativeBoundingBox: const Rect.fromLTWH(0.2, 0.3, 0.1, 0.1),
            shapes: [],
          ),
          PixelArtComponent(
            name: 'Eye',
            description: 'Right eye',
            relativeBoundingBox: const Rect.fromLTWH(0.6, 0.3, 0.1, 0.1),
            shapes: [],
          ),
          PixelArtComponent(
            name: 'Eye',
            description: 'Third eye',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.2, 0.1, 0.1),
            shapes: [],
          ),
        ];

        int? reorderedOldIndex;
        int? reorderedNewIndex;

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              canvasStateProvider.overrideWith((ref) {
                final aiService = ref.watch(loggingAiServiceProvider);
                final notifier = _MockLayerCanvasNotifier(
                  aiService,
                  onReorder: (oldIdx, newIdx) {
                    reorderedOldIndex = oldIdx;
                    reorderedNewIndex = newIdx;
                  },
                );
                notifier.state = notifier.state.copyWith(
                  decomposedComponents: duplicateComponents,
                );
                return notifier;
              }),
            ],
            child: const Scaffold(body: LayerOrderingList()),
          ),
        );

        // Verify all 3 duplicate named layers are rendered without errors
        expect(find.text('Eye'), findsNWidgets(3));
        expect(tester.takeException(), isNull);

        // Tap on down arrow of first item to trigger reorder
        final downArrow = find.byIcon(Icons.keyboard_arrow_down).first;
        await tester.tap(downArrow);
        await tester.pumpAndSettle();

        expect(reorderedOldIndex, equals(0));
        expect(reorderedNewIndex, equals(2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('tapping AI Auto-Order button triggers reorderLayersWithAi', (
      tester,
    ) async {
      final mockComponents = [
        PixelArtComponent(
          name: 'Blade',
          description: 'A sharp blade',
          relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
          shapes: [],
        ),
        PixelArtComponent(
          name: 'Hilt',
          description: 'Hilt guard',
          relativeBoundingBox: const Rect.fromLTWH(0.4, 0.7, 0.2, 0.2),
          shapes: [],
        ),
      ];

      bool aiReorderCalled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            canvasStateProvider.overrideWith((ref) {
              final aiService = ref.watch(loggingAiServiceProvider);
              final notifier = _MockLayerCanvasNotifier(
                aiService,
                onAiReorder: () async {
                  aiReorderCalled = true;
                },
              );
              notifier.state = notifier.state.copyWith(
                decomposedComponents: mockComponents,
              );
              return notifier;
            }),
          ],
          child: const Scaffold(body: LayerOrderingList()),
        ),
      );

      expect(find.text('AI Auto-Order'), findsOneWidget);
      await tester.tap(find.text('AI Auto-Order'));
      await tester.pumpAndSettle();

      expect(aiReorderCalled, isTrue);
      expect(find.text('AI reordered layers by depth!'), findsOneWidget);
    });

    testGoldens('LayerOrderingList renders correctly in multiple states', (
      tester,
    ) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Empty Components Layer List',
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) {
                final aiService = ref.watch(loggingAiServiceProvider);
                final notifier = CanvasNotifier(aiService);
                notifier.state = notifier.state.copyWith(
                  decomposedComponents: const [],
                );
                return notifier;
              }),
            ],
            child: const SizedBox(width: 350, child: LayerOrderingList()),
          ),
        )
        ..addScenario(
          'Multiple Layer List State',
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) {
                final aiService = ref.watch(loggingAiServiceProvider);
                final notifier = CanvasNotifier(aiService);
                notifier.state = notifier.state.copyWith(
                  decomposedComponents: [
                    PixelArtComponent(
                      name: 'Top Blade Layer',
                      description: 'Drawn last',
                      relativeBoundingBox: const Rect.fromLTWH(
                        0.4,
                        0.1,
                        0.2,
                        0.6,
                      ),
                      fillColor: Colors.blue,
                      outlineColor: Colors.white,
                    ),
                    PixelArtComponent(
                      name: 'Background Shading',
                      description: 'Drawn first',
                      relativeBoundingBox: const Rect.fromLTWH(
                        0.4,
                        0.7,
                        0.2,
                        0.2,
                      ),
                      fillColor: Colors.red,
                    ),
                  ],
                );
                return notifier;
              }),
            ],
            child: const SizedBox(width: 350, child: LayerOrderingList()),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
        surfaceSize: const Size(400, 1100),
      );

      await screenMatchesGolden(tester, 'layer_ordering_list');
    });
  });
}

class _MockLayerCanvasNotifier extends CanvasNotifier {
  final Function(int, int)? onReorder;
  final VoidCallback? onMerge;
  final Future<void> Function()? onAiReorder;

  _MockLayerCanvasNotifier(
    super.aiService, {
    this.onReorder,
    this.onMerge,
    this.onAiReorder,
  });

  @override
  void reorderComponents(int oldIndex, int newIndex) {
    if (onReorder != null) onReorder!(oldIndex, newIndex);
    super.reorderComponents(oldIndex, newIndex);
  }

  @override
  void mergeComponentsToCanvas() {
    if (onMerge != null) onMerge!();
    super.mergeComponentsToCanvas();
  }

  @override
  Future<void> reorderLayersWithAi() async {
    if (onAiReorder != null) {
      await onAiReorder!();
    } else {
      await super.reorderLayersWithAi();
    }
  }
}
