import 'package:bad_pixel_art/widgets/palette_color_selector_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaletteColorSelectorRow Tests', () {
    testWidgets(
      'renders title and palette swatches and responds to selection',
      (tester) async {
        Color? selectedColor = Colors.red;
        final palette = [Colors.red, Colors.green, Colors.blue];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return PaletteColorSelectorRow(
                    title: 'Fill Color',
                    selectedColor: selectedColor,
                    palette: palette,
                    onColorSelected: (color) {
                      setState(() {
                        selectedColor = color;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );

        // Verify title is rendered
        expect(find.text('Fill Color'), findsOneWidget);

        // Verify block icon for "None" is present
        expect(find.byIcon(Icons.block), findsOneWidget);

        // Tap green color swatch
        final greenFinder = find.byWidgetPredicate(
          (widget) =>
              widget is AnimatedContainer &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == Colors.green,
        );
        expect(greenFinder, findsOneWidget);

        await tester.tap(greenFinder);
        await tester.pumpAndSettle();

        expect(selectedColor, equals(Colors.green));

        // Tap "None" (block icon) to clear color
        await tester.tap(find.byIcon(Icons.block));
        await tester.pumpAndSettle();

        expect(selectedColor, isNull);
      },
    );
  });
}
