import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/widgets/ai_color_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiColorConfirmationDialog Tests', () {
    final mockComponents = [
      PixelArtComponent(
        name: 'Blade',
        description: 'Sharp blade',
        relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        fillColor: Colors.blue,
        fillColor2: Colors.cyan,
        gradientAngle: 45.0,
        outlineColor: Colors.white,
      ),
      PixelArtComponent(
        name: 'Hilt',
        description: 'Wood hilt',
        relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        fillColor: Colors.brown,
        outlineColor: Colors.black,
      ),
    ];

    final sampleResult = AiColorSelectionResult(
      reasoning: 'Applied vibrant ocean gradient for blade and brown for hilt.',
      updatedComponents: mockComponents,
    );

    testWidgets('renders reasoning, component preview badges, and buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AiColorConfirmationDialog(
                        result: sampleResult,
                        onRetry: () {},
                        onConfirm: (_) {},
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('AI Color Suggestions'), findsOneWidget);
      expect(
        find.text(
          'Applied vibrant ocean gradient for blade and brown for hilt.',
        ),
        findsOneWidget,
      );
      expect(find.text('Blade'), findsOneWidget);
      expect(find.text('(45°)'), findsOneWidget);
      expect(find.text('Hilt'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Re-suggest'), findsOneWidget);
      expect(find.text('Confirm Colors'), findsOneWidget);
    });

    testWidgets('Cancel button dismisses dialog without action', (
      tester,
    ) async {
      bool retryCalled = false;
      bool confirmCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AiColorConfirmationDialog(
                        result: sampleResult,
                        onRetry: () => retryCalled = true,
                        onConfirm: (_) => confirmCalled = true,
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(retryCalled, isFalse);
      expect(confirmCalled, isFalse);
    });

    testWidgets('Re-suggest button invokes onRetry callback', (tester) async {
      bool retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AiColorConfirmationDialog(
                        result: sampleResult,
                        onRetry: () => retryCalled = true,
                        onConfirm: (_) {},
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Re-suggest'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(retryCalled, isTrue);
    });

    testWidgets('Confirm Colors button invokes onConfirm callback', (
      tester,
    ) async {
      List<PixelArtComponent>? confirmedComponents;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AiColorConfirmationDialog(
                        result: sampleResult,
                        onConfirm: (comps) => confirmedComponents = comps,
                        onRetry: () {},
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Colors'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(confirmedComponents, equals(mockComponents));
    });
  });
}
