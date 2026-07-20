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

  _MockLayerCanvasNotifier(super.aiService, {this.onReorder, this.onMerge});

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
}
