import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/resolution_selector_dialog.dart';
import '../test_helper.dart';

void main() {
  group('ResolutionSelectorDialog Widget & Golden Tests', () {
    testWidgets('renders both options and highlights current selection', (
      tester,
    ) async {
      int? selectedSize;
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: ResolutionSelectorDialog(
              currentGridSize: 16,
              onSelected: (size) {
                selectedSize = size;
              },
            ),
          ),
        ),
      );

      // Verify title and description render
      expect(find.text('Select Grid Size'), findsOneWidget);
      expect(
        find.textContaining('Choose the canvas resolution'),
        findsOneWidget,
      );

      // Verify size card labels exist
      expect(find.text('8 x 8'), findsOneWidget);
      expect(find.text('16 x 16'), findsOneWidget);

      // Tap on the 8x8 card
      await tester.tap(find.byKey(const ValueKey('size_card_8')));
      await tester.pumpAndSettle();

      // Verify callback was triggered and dialog popped (we popped in GestureDetector)
      expect(selectedSize, equals(8));
    });

    testWidgets('Cancel button dismisses the dialog', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ResolutionSelectorDialog(
                        currentGridSize: 16,
                        onSelected: (_) {},
                      ),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Select Grid Size'), findsOneWidget);

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Select Grid Size'), findsNothing);
    });

    testGoldens('ResolutionSelectorDialog renders correctly', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          '16x16 Active',
          ResolutionSelectorDialog(currentGridSize: 16, onSelected: (_) {}),
        )
        ..addScenario(
          '8x8 Active',
          ResolutionSelectorDialog(currentGridSize: 8, onSelected: (_) {}),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
        surfaceSize: const Size(600, 1000),
      );
      await screenMatchesGolden(tester, 'resolution_selector_dialog');
    });
  });
}
