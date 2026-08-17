import 'package:bad_pixel_art/widgets/gradient_angle_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GradientAngleSelector Tests', () {
    testWidgets('renders presets and updates angle when chip tapped', (
      tester,
    ) async {
      double currentAngle = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return GradientAngleSelector(
                  angle: currentAngle,
                  onAngleChanged: (newAngle) {
                    setState(() {
                      currentAngle = newAngle;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify label and presets exist
      expect(find.text('Angle'), findsOneWidget);
      expect(find.text('0°'), findsWidgets);
      expect(find.text('45°'), findsOneWidget);
      expect(find.text('90°'), findsOneWidget);
      expect(find.text('180°'), findsOneWidget);

      // Tap 90° chip
      await tester.tap(find.widgetWithText(ChoiceChip, '90°'));
      await tester.pumpAndSettle();

      expect(currentAngle, equals(90.0));
      expect(find.text('90°'), findsWidgets);
    });

    testWidgets('slider interaction triggers onAngleChanged', (tester) async {
      double currentAngle = 45.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return GradientAngleSelector(
                  angle: currentAngle,
                  onAngleChanged: (newAngle) {
                    setState(() {
                      currentAngle = newAngle;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(Slider), findsOneWidget);

      // Drag slider
      final sliderFinder = find.byType(Slider);
      await tester.drag(sliderFinder, const Offset(100.0, 0.0));
      await tester.pumpAndSettle();

      expect(currentAngle, isNot(equals(45.0)));
    });
  });
}
