import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/screens/pixel_art_screen.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../test_helper.dart';

void main() {
  group('PixelArtScreen Dialogs Tests', () {
    testWidgets(
      'shows Choose Drawing Plan dialog when pendingDecompositionOptions is populated',
      (tester) async {
        final mockAiService = MockAiService();
        final mockNotifier = CanvasNotifier(mockAiService);
        final option = [
          PixelArtComponent(
            name: 'blade',
            description: 'vertical blade',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
          ),
        ];

        await tester.pumpWidget(
          buildTestableWidget(
            child: const PixelArtScreen(),
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
            ],
          ),
        );

        // Now populate pendingDecompositionOptions to trigger the listener
        mockNotifier.state = mockNotifier.state.copyWith(
          pendingDecompositionOptions: [option, option, option, option],
        );

        // Let the dialog open
        await tester.pumpAndSettle();

        // Verify the dialog is visible
        expect(find.text('Choose Drawing Plan'), findsOneWidget);
        expect(find.text('OPTION 1'), findsOneWidget);
        expect(find.text('• blade'), findsWidgets);

        // Tap on Option 1 card
        await tester.tap(find.text('OPTION 1'));
        await tester.pumpAndSettle();

        // Dialog should be dismissed, and option 1 applied
        expect(find.text('Choose Drawing Plan'), findsNothing);
        expect(mockNotifier.state.decomposedComponents, hasLength(1));
        expect(
          mockNotifier.state.decomposedComponents.first.name,
          equals('blade'),
        );
        expect(mockNotifier.state.pendingDecompositionOptions, isEmpty);
      },
    );
  });
}
