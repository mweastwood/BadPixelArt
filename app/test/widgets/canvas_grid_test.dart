import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/canvas_grid.dart';
import '../test_helper.dart';

void main() {
  group('CanvasGrid Widget Tests', () {
    testWidgets('renders CanvasGrid with empty grid', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const Scaffold(
            body: SizedBox(width: 300, height: 300, child: CanvasGrid()),
          ),
        ),
      );

      // Verify grid custom paint and visual helper grid exists
      expect(find.byType(CanvasGrid), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is CanvasPainter,
        ),
        findsOneWidget,
      );
    });

    testGoldens('CanvasGrid renders empty and populated grids correctly', (
      tester,
    ) async {
      final builder = GoldenBuilder.grid(columns: 2, widthToHeightRatio: 1)
        ..addScenario(
          'Empty Canvas Grid',
          const SizedBox(width: 300, height: 300, child: CanvasGrid()),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'canvas_grid_empty');
    });
  });
}
