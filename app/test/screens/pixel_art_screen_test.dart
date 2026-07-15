import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/screens/pixel_art_screen.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import 'package:local_agent/local_agent.dart';
import '../test_helper.dart';

void main() {
  group('PixelArtScreen Screen & Golden Tests', () {
    testWidgets('renders full responsive layout components', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const PixelArtScreen()),
      );

      // Verify the appBar title is visible
      expect(find.text('Bad Pixel Art'), findsOneWidget);
    });

    testGoldens('PixelArtScreen portrait golden render', (tester) async {
      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'pixel_art_screen_portrait');
    });

    testGoldens('PixelArtScreen landscape golden render', (tester) async {
      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(),
      );
      await multiScreenGolden(
        tester,
        'pixel_art_screen_landscape',
        devices: [
          const Device(name: 'landscape_tablet', size: Size(1280, 800)),
        ],
      );
    });

    testGoldens('PixelArtScreen suggested palette dialog golden render', (
      tester,
    ) async {
      final mockAiService = MockAiService();
      final mockNotifier = CanvasNotifier(mockAiService);
      mockNotifier.state = mockNotifier.state.copyWith(
        suggestedPalette: List.generate(
          16,
          (i) => Color(0xFF000000 | (i * 0x111111)),
        ),
        showPaletteSuggestion: true,
      );

      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(
          overrides: [canvasStateProvider.overrideWith((ref) => mockNotifier)],
        ),
      );

      await screenMatchesGolden(tester, 'pixel_art_screen_palette_suggestion');
    });

    testGoldens('PixelArtScreen component confirmation dialog golden render', (
      tester,
    ) async {
      final mockAiService = MockAiService();
      final mockNotifier = CanvasNotifier(mockAiService);
      mockNotifier.state = mockNotifier.state.copyWith(
        decomposedComponents: [
          PixelArtComponent(
            name: 'blade',
            description: 'vertical steel blade',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
          ),
        ],
        confirmingComponentIndex: null,
      );

      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(
          overrides: [canvasStateProvider.overrideWith((ref) => mockNotifier)],
        ),
      );

      // Now change it to trigger the listener
      mockNotifier.state = mockNotifier.state.copyWith(
        confirmingComponentIndex: 0,
      );

      // Let dialog anim settle
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('component_confirmation_dialog')),
        findsOneWidget,
      );

      await screenMatchesGolden(
        tester,
        'pixel_art_screen_component_confirmation',
      );
    });

    testGoldens('PixelArtScreen palette generation loading golden render', (
      tester,
    ) async {
      final mockAiService = MockAiService();
      final mockNotifier = CanvasNotifier(mockAiService);
      mockNotifier.state = mockNotifier.state.copyWith(
        isSuggestingPalette: true,
      );

      await tester.pumpWidgetBuilder(
        const PixelArtScreen(),
        wrapper: testMaterialAppWrapper(
          overrides: [canvasStateProvider.overrideWith((ref) => mockNotifier)],
        ),
      );

      await screenMatchesGolden(
        tester,
        'pixel_art_screen_palette_loading',
        customPump: (tester) async => tester.pump(),
      );
    });
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
