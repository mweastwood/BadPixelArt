import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/screens/pixel_art_screen.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/ai_service.dart';
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

      await screenMatchesGolden(tester, 'pixel_art_screen_palette_loading');
    });
  });
}
