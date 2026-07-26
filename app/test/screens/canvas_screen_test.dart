import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/screens/canvas_screen.dart';
import 'package:bad_pixel_art/widgets/canvas_grid.dart';
import 'package:bad_pixel_art/widgets/wizard_controls.dart';
import 'package:bad_pixel_art/widgets/grid_size_selection_card.dart';
import '../test_helper.dart';

void main() {
  group('CanvasScreen Unit & Golden Tests', () {
    testWidgets('renders CanvasGrid and WizardControls components', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: CanvasScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CanvasGrid), findsOneWidget);
      expect(find.byType(WizardControls), findsOneWidget);
      expect(find.byType(GridSizeSelectionCard), findsOneWidget);
    });

    testWidgets('CanvasScreen portrait golden render', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: CanvasScreen())),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(CanvasScreen),
        matchesGoldenFile('goldens/canvas_screen_portrait.png'),
      );
    }, tags: 'golden');

    testWidgets('CanvasScreen landscape golden render', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: CanvasScreen())),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(CanvasScreen),
        matchesGoldenFile('goldens/canvas_screen_landscape.png'),
      );
    }, tags: 'golden');
  });
}
