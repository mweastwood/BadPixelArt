import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/widgets/custom_palette_confirmation_dialog.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import '../test_helper.dart';

void main() {
  group('CustomPaletteConfirmationDialog Widget Tests', () {
    testWidgets(
      'renders dialog title, description, and custom palette swatches',
      (tester) async {
        final samplePalette = List.generate(
          16,
          (i) => Color(0xFF000000 | (i * 0x111111)),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: Scaffold(
              body: CustomPaletteConfirmationDialog(palette: samplePalette),
            ),
          ),
        );

        expect(find.text('Confirm Custom Palette'), findsOneWidget);
        expect(
          find.text(
            'The AI analyzed your reference image and suggested this 16-color palette:',
          ),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
        expect(find.text('Accept'), findsOneWidget);

        // Verify 16 color swatch containers rendered inside GridView
        final gridViewFinder = find.byType(GridView);
        expect(gridViewFinder, findsOneWidget);
        final gridView = tester.widget<GridView>(gridViewFinder);
        expect(
          (gridView.childrenDelegate as SliverChildBuilderDelegate).childCount,
          16,
        );
      },
    );

    testWidgets('triggers onRetry, onReject, and onAccept callbacks', (
      tester,
    ) async {
      bool retryCalled = false;
      bool rejectCalled = false;
      bool acceptCalled = false;

      final samplePalette = [Colors.red, Colors.green, Colors.blue];

      await tester.pumpWidget(
        buildTestableWidget(
          child: Scaffold(
            body: CustomPaletteConfirmationDialog(
              palette: samplePalette,
              onRetry: () => retryCalled = true,
              onReject: () => rejectCalled = true,
              onAccept: () => acceptCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retryCalled, isTrue);

      await tester.tap(find.text('Reject'));
      await tester.pump();
      expect(rejectCalled, isTrue);

      await tester.tap(find.text('Accept'));
      await tester.pump();
      expect(acceptCalled, isTrue);
    });

    testWidgets(
      'reads suggested palette and invokes notifier when using defaults',
      (tester) async {
        final mockNotifier = CanvasNotifier(TestMockAiService());
        final samplePalette = List.generate(
          8,
          (i) => Color(0xFF101010 * (i + 1)),
        );
        mockNotifier.state = mockNotifier.state.copyWith(
          suggestedPalette: samplePalette,
          showPaletteSuggestion: true,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
            ],
            child: const Scaffold(body: CustomPaletteConfirmationDialog()),
          ),
        );

        expect(find.text('Confirm Custom Palette'), findsOneWidget);
        final gridViewFinder = find.byType(GridView);
        expect(gridViewFinder, findsOneWidget);
        final gridView = tester.widget<GridView>(gridViewFinder);
        expect(
          (gridView.childrenDelegate as SliverChildBuilderDelegate).childCount,
          8,
        );

        // Tap Accept and verify state changes (showPaletteSuggestion becomes false)
        await tester.tap(find.text('Accept'));
        await tester.pump();
        expect(mockNotifier.state.showPaletteSuggestion, isFalse);
      },
    );
  });
}
