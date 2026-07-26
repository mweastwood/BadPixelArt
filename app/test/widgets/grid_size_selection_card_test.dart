import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bad_pixel_art/widgets/grid_size_selection_card.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import '../test_helper.dart';

void main() {
  group('GridSizeSelectionCard Widget & Golden Tests', () {
    testWidgets(
      'renders 8x8 and 16x16 options and triggers resolution change on tap',
      (tester) async {
        final mockAiService = TestMockAiService();
        final notifier = CanvasNotifier(mockAiService);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: GridSizeSelectionCard()),
              ),
            ),
          ),
        );

        expect(find.byType(GridSizeSelectionCard), findsOneWidget);
        expect(find.text('8 x 8'), findsOneWidget);
        expect(find.text('16 x 16'), findsOneWidget);
        expect(notifier.state.gridSize, equals(16));

        // Tap 8x8 card option
        await tester.tap(find.byKey(const ValueKey('grid_size_card_8')));
        await tester.pumpAndSettle();

        expect(notifier.state.gridSize, equals(8));

        // Tap 16x16 card option
        await tester.tap(find.byKey(const ValueKey('grid_size_card_16')));
        await tester.pumpAndSettle();

        expect(notifier.state.gridSize, equals(16));
      },
    );

    testGoldens('GridSizeSelectionCard golden render', (tester) async {
      await tester.pumpWidgetBuilder(
        const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: GridSizeSelectionCard(),
            ),
          ),
        ),
        wrapper: testMaterialAppWrapper(),
      );

      await screenMatchesGolden(tester, 'grid_size_selection_card');
    });
  });
}
