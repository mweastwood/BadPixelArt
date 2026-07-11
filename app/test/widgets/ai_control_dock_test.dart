import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/ai_control_dock.dart';
import '../test_helper.dart';

void main() {
  group('AiControlDock Widget & Golden Tests', () {
    testWidgets('renders preset items and responds to collapse toggles', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: AiControlDock())),
      );

      // Verify started as expanded (Reference Image Presets should be visible)
      expect(find.text('Reference Image Presets'), findsOneWidget);
      expect(find.text('User Instructions / Prompt'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('AI Assistant Controls'));
      await tester.pumpAndSettle();

      // Verify controls are hidden
      expect(find.text('Reference Image Presets'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('AI Assistant Controls'));
      await tester.pumpAndSettle();

      // Verify controls are visible again
      expect(find.text('Reference Image Presets'), findsOneWidget);
    });

    testGoldens('AiControlDock renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
        ..addScenario('AI Control Dock Default', const AiControlDock());

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'ai_control_dock');
    });
  });
}
