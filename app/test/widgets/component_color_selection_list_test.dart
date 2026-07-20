import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';
import 'package:bad_pixel_art/widgets/component_color_selection_list.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/utils/logging_ai_service.dart';
import '../test_helper.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('ComponentColorSelectionList Widget & Golden Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      AppDatabaseHelper.db = db;
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('renders components and triggers notifier updates on color tap', (
      tester,
    ) async {
      final mockPalette = [Colors.red, Colors.green, Colors.blue];
      final mockComponents = [
        PixelArtComponent(
          name: 'Blade',
          description: 'A sharp blade',
          relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
          shapes: [],
        ),
      ];

      int? selectedComponentIndex;
      Color? selectedFillColor;
      Color? selectedOutlineColor;

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            canvasStateProvider.overrideWith((ref) {
              final aiService = ref.watch(loggingAiServiceProvider);
              final notifier = _MockColorCanvasNotifier(
                aiService,
                onSelect: (index) => selectedComponentIndex = index,
                onUpdateColors: (index, fill, outline) {
                  selectedFillColor = fill;
                  selectedOutlineColor = outline;
                },
              );
              notifier.state = notifier.state.copyWith(
                palette: mockPalette,
                decomposedComponents: mockComponents,
                activeComponentIndex: 0,
              );
              return notifier;
            }),
          ],
          child: const Scaffold(body: ComponentColorSelectionList()),
        ),
      );

      // Verify names and headers are shown
      expect(find.text('Blade'), findsOneWidget);
      expect(find.text('A sharp blade'), findsOneWidget);

      // Tap on row to select component (already active, but let's test tap)
      await tester.tap(find.text('Blade'));
      await tester.pumpAndSettle();
      expect(selectedComponentIndex, equals(0));

      // Tap on a color in the Fill Color selector
      // Find specific color buttons.
      // In the Row, there are multiple GestureDetector circles.
      // To find the blue color circle specifically, we can use a key or just look for the Container with blue color.
      final greenCircleFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.green,
      );

      // Tap green color circle
      await tester.tap(greenCircleFinder.first);
      await tester.pumpAndSettle();

      expect(selectedFillColor?.toARGB32(), equals(Colors.green.toARGB32()));
      expect(selectedOutlineColor, isNull);
    });

    testGoldens(
      'ComponentColorSelectionList renders correctly in multiple states',
      (tester) async {
        final mockPalette = [
          Colors.red,
          Colors.green,
          Colors.blue,
          Colors.white,
        ];

        final builder = GoldenBuilder.column()
          ..addScenario(
            'Empty Components State',
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
              child: const SizedBox(
                width: 350,
                child: ComponentColorSelectionList(),
              ),
            ),
          )
          ..addScenario(
            'Configured Colors State',
            ProviderScope(
              overrides: [
                canvasStateProvider.overrideWith((ref) {
                  final aiService = ref.watch(loggingAiServiceProvider);
                  final notifier = CanvasNotifier(aiService);
                  notifier.state = notifier.state.copyWith(
                    palette: mockPalette,
                    decomposedComponents: [
                      PixelArtComponent(
                        name: 'Sword Blade',
                        description: 'Ice blue blade',
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
                        name: 'Sword Hilt',
                        description: 'Leather wrapped hilt',
                        relativeBoundingBox: const Rect.fromLTWH(
                          0.4,
                          0.7,
                          0.2,
                          0.2,
                        ),
                        fillColor: Colors.red,
                        outlineColor: null, // Transparent outline
                      ),
                    ],
                    activeComponentIndex: 0,
                  );
                  return notifier;
                }),
              ],
              child: const SizedBox(
                width: 350,
                child: ComponentColorSelectionList(),
              ),
            ),
          );

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: testMaterialAppWrapper(),
          surfaceSize: const Size(400, 1100),
        );

        await screenMatchesGolden(tester, 'component_color_selection_list');
      },
    );
  });
}

class _MockColorCanvasNotifier extends CanvasNotifier {
  final Function(int)? onSelect;
  final Function(int, Color?, Color?)? onUpdateColors;

  _MockColorCanvasNotifier(
    super.aiService, {
    this.onSelect,
    this.onUpdateColors,
  });

  @override
  void selectComponent(int index) {
    if (onSelect != null) onSelect!(index);
    super.selectComponent(index);
  }

  @override
  void updateComponentColors(int index, Color? fillColor, Color? outlineColor) {
    if (onUpdateColors != null) onUpdateColors!(index, fillColor, outlineColor);
    super.updateComponentColors(index, fillColor, outlineColor);
  }
}
