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
