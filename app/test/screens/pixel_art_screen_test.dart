import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/screens/pixel_art_screen.dart';
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
          const Device(
            name: 'landscape_tablet',
            size: Size(1280, 800),
          ),
        ],
      );
    });
  });
}
