import 'package:bad_pixel_art/widgets/gradient_angle_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GradientAngleSelector Tests', () {
    test(
      'getGradientAngleDescription returns correct direction descriptions',
      () {
        expect(getGradientAngleDescription(0.0), equals('Left to Right (→)'));
        expect(
          getGradientAngleDescription(45.0),
          equals('Top-Left to Bottom-Right (↘)'),
        );
        expect(getGradientAngleDescription(90.0), equals('Top to Bottom (↓)'));
        expect(
          getGradientAngleDescription(135.0),
          equals('Top-Right to Bottom-Left (↙)'),
        );
        expect(getGradientAngleDescription(180.0), equals('Right to Left (←)'));
        expect(
          getGradientAngleDescription(225.0),
          equals('Bottom-Right to Top-Left (↖)'),
        );
        expect(getGradientAngleDescription(270.0), equals('Bottom to Top (↑)'));
        expect(
          getGradientAngleDescription(315.0),
          equals('Bottom-Left to Top-Right (↗)'),
        );
        // Wrap around test
        expect(getGradientAngleDescription(360.0), equals('Left to Right (→)'));
        expect(getGradientAngleDescription(450.0), equals('Top to Bottom (↓)'));
      },
    );

    testWidgets(
      'renders circular dial, descriptions, and updates angle when chip tapped',
      (tester) async {
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

        // Verify title and plain direction description exist
        expect(find.text('Gradient Direction:'), findsOneWidget);
        expect(find.text('0° — Left to Right (→)'), findsOneWidget);
        expect(find.byType(CircularAngleDial), findsOneWidget);

        // Verify preset chips with descriptive directions
        expect(find.text('0° (→ Left to Right)'), findsOneWidget);
        expect(find.text('90° (↓ Top to Bottom)'), findsOneWidget);
        expect(find.text('180° (← Right to Left)'), findsOneWidget);
        expect(find.text('270° (↑ Bottom to Top)'), findsOneWidget);

        // Tap 90° preset chip
        await tester.tap(find.byKey(const ValueKey('gradient_preset_90')));
        await tester.pumpAndSettle();

        expect(currentAngle, equals(90.0));
        expect(find.text('90° — Top to Bottom (↓)'), findsOneWidget);
      },
    );

    testWidgets('circular dial tap/drag interaction triggers onAngleChanged', (
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

      expect(find.byType(CircularAngleDial), findsOneWidget);

      // Tap bottom of circular dial (should rotate towards ~90 degrees)
      final dialFinder = find.byKey(
        const ValueKey('circular_gradient_dial_gesture'),
      );
      expect(dialFinder, findsOneWidget);

      final dialCenter = tester.getCenter(dialFinder);
      // Tap below center (positive dy, dx = 0) -> angle 90 degrees
      await tester.tapAt(dialCenter + const Offset(0.0, 30.0));
      await tester.pumpAndSettle();

      expect(currentAngle, equals(90.0));

      // Tap left of center (negative dx, dy = 0) -> angle 180 degrees
      await tester.tapAt(dialCenter + const Offset(-30.0, 0.0));
      await tester.pumpAndSettle();

      expect(currentAngle, equals(180.0));
    });
  });
}
