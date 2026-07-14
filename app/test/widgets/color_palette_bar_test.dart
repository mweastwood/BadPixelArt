import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/color_palette_bar.dart';
import '../test_helper.dart';

void main() {
  group('ColorPaletteBar Widget & Golden Tests', () {
    testWidgets('renders palette choices and tool actions', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: ColorPaletteBar())),
      );

      // Verify basic labels and actions exist
      expect(find.text('Primary 8'), findsOneWidget);
      expect(find.text('Grayscale 4'), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.byIcon(Icons.redo), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
    testWidgets('collapses and expands on header tap', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: ColorPaletteBar())),
      );

      // Verify started as expanded (elements are visible)
      expect(find.text('Primary 8'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('Color Palette'));
      await tester.pumpAndSettle();

      // Verify elements are now hidden
      expect(find.text('Primary 8'), findsNothing);

      // Tap header to expand again
      await tester.tap(find.text('Color Palette'));
      await tester.pumpAndSettle();

      // Verify elements are visible again
      expect(find.text('Primary 8'), findsOneWidget);
    });
    testGoldens('ColorPaletteBar renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 3)
        ..addScenario('Primary Palette Selected', const ColorPaletteBar());

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'color_palette_bar');
    });
  });
}
