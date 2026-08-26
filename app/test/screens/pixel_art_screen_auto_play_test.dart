import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/screens/pixel_art_screen.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/wizard_state.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import '../test_helper.dart';

void main() {
  group('PixelArtScreen Auto-Play Tests', () {
    testWidgets('Auto-Play FAB is disabled when reference image is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const PixelArtScreen()),
      );
      await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(
        find.byKey(const ValueKey('auto_play_fab')),
      );
      expect(fab.onPressed, isNull);
    });

    testWidgets(
      'Auto-Play FAB is enabled with reference image, toggles auto-play and displays Pause FAB',
      (tester) async {
        final mockAi = MockAiService();
        late CanvasNotifier notifier;

        await tester.pumpWidget(
          buildTestableWidget(
            child: const PixelArtScreen(),
            overrides: [
              canvasStateProvider.overrideWith((ref) {
                notifier = CanvasNotifier(
                  mockAi,
                  wizardNotifier: ref.read(wizardStateProvider.notifier),
                );
                notifier.state = notifier.state.copyWith(
                  referenceImage: Uint8List.fromList([1, 2, 3]),
                );
                return notifier;
              }),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // FAB is enabled with play icon
        final playFab = tester.widget<FloatingActionButton>(
          find.byKey(const ValueKey('auto_play_fab')),
        );
        expect(playFab.onPressed, isNotNull);

        // Tap Auto-Play FAB
        await tester.tap(find.byKey(const ValueKey('auto_play_fab')));
        await tester.pump();

        // Verify Auto-Play active state
        expect(notifier.state.autoRun, isTrue);
        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(
          find.byKey(const ValueKey('auto_play_active_banner')),
          findsOneWidget,
        );

        // Clean up active loop before ending test
        notifier.stopAutoPlay();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets('navigating away from Canvas tab keeps auto-play running', (
      tester,
    ) async {
      final mockAi = MockAiService();
      late CanvasNotifier notifier;

      await tester.pumpWidget(
        buildTestableWidget(
          child: const PixelArtScreen(),
          overrides: [
            canvasStateProvider.overrideWith((ref) {
              notifier = CanvasNotifier(
                mockAi,
                wizardNotifier: ref.read(wizardStateProvider.notifier),
              );
              notifier.state = notifier.state.copyWith(
                referenceImage: Uint8List.fromList([1, 2, 3]),
                autoRun: true,
              );
              return notifier;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(notifier.state.autoRun, isTrue);

      // Switch to Creations tab
      await tester.tap(find.text('Creations'));
      await tester.pumpAndSettle();

      // Auto-play should remain active
      expect(notifier.state.autoRun, isTrue);

      // Clean up before finishing test
      notifier.stopAutoPlay();
    });
  });
}
