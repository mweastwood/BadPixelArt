import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bad_pixel_art/widgets/canvas_grid.dart';
import 'package:bad_pixel_art/widgets/wizard_controls.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
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

    testWidgets(
      'allows manual resizing of component bounding boxes via dragging in Step 2',
      (tester) async {
        final mockNotifier = CanvasNotifier(TestMockAiService());
        final compGrid = List.generate(16, (_) => List.filled(16, 0));
        mockNotifier.state = mockNotifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'vertical steel blade',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
              grid: compGrid,
            ),
          ],
          activeComponentIndex: 0,
        );

        final wizardNotifier = WizardNotifier(2); // Start at Step 2

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(width: 300, height: 300, child: CanvasGrid()),
              ),
            ),
          ),
        );

        expect(find.byType(CanvasGrid), findsOneWidget);

        // Perform a drag from the bottom-right corner to resize the bounding box
        // Relative bottom-right is (0.6, 0.7), which maps to (180, 210) in a 300x300 canvas
        final gesture = await tester.startGesture(const Offset(180, 210));
        await gesture.moveTo(const Offset(210, 240));
        await gesture.up();
        await tester.pumpAndSettle();

        final updatedComp = mockNotifier.state.decomposedComponents[0];
        expect(updatedComp.relativeBoundingBox.right, closeTo(0.7, 0.05));
        expect(updatedComp.relativeBoundingBox.bottom, closeTo(0.8, 0.05));
      },
    );

    testWidgets(
      'does not allow resizing of non-selected component bounding boxes',
      (tester) async {
        final mockNotifier = CanvasNotifier(TestMockAiService());
        final compGrid = List.generate(16, (_) => List.filled(16, 0));
        mockNotifier.state = mockNotifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'vertical steel blade',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
              grid: compGrid,
            ),
            PixelArtComponent(
              name: 'hilt',
              description: 'wooden handle',
              relativeBoundingBox: const Rect.fromLTWH(0.45, 0.7, 0.1, 0.2),
              grid: compGrid,
            ),
          ],
          activeComponentIndex: 0, // 'blade' is active, 'hilt' is inactive
        );

        final wizardNotifier = WizardNotifier(2); // Step 2

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(width: 300, height: 300, child: CanvasGrid()),
              ),
            ),
          ),
        );

        // Try to drag the bottom-right corner of the inactive 'hilt' component (relative 0.55, 0.9 -> absolute 165, 270)
        final gesture = await tester.startGesture(const Offset(165, 270));
        await gesture.moveTo(const Offset(195, 290));
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify the inactive hilt's bounding box remains unchanged
        final hiltComp = mockNotifier.state.decomposedComponents[1];
        expect(hiltComp.relativeBoundingBox.left, closeTo(0.45, 1e-9));
        expect(hiltComp.relativeBoundingBox.top, closeTo(0.7, 1e-9));
        expect(hiltComp.relativeBoundingBox.width, closeTo(0.1, 1e-9));
        expect(hiltComp.relativeBoundingBox.height, closeTo(0.2, 1e-9));
      },
    );

    testWidgets(
      'allows manual sculpting by tapping eligible pixels when AI is idle, but locks it while generating',
      (tester) async {
        final mockNotifier = CanvasNotifier(TestMockAiService());
        final compGrid = List.generate(16, (_) => List.filled(16, 0));
        compGrid[8][8] = 1;

        mockNotifier.state = mockNotifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'vertical steel blade',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
              grid: compGrid,
            ),
          ],
          activeComponentIndex: 0,
          isGenerating: false,
        );

        final wizardNotifier = WizardNotifier(3); // Step 3 - sculpting phase

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(width: 300, height: 300, child: CanvasGrid()),
              ),
            ),
          ),
        );

        // On a 300x300 canvas and 16x16 grid:
        // Each cell is 300/16 = 18.75 pixels.
        // Pixel (8, 7) is adjacent (outer border/add candidate), at Offset(8 * 18.75 + 9, 7 * 18.75 + 9) = Offset(159, 140).
        // Let's tap on (8, 7) (Offset 159, 140) to add it:
        await tester.tapAt(const Offset(159, 140));
        await tester.pumpAndSettle();

        // Verify that (8, 7) is now 1 (filled)
        expect(
          mockNotifier.state.decomposedComponents[0].grid![7][8],
          equals(1),
        );

        // Now set isGenerating = true to simulate AI running
        mockNotifier.state = mockNotifier.state.copyWith(isGenerating: true);
        await tester.pumpAndSettle();

        // Tap on (8, 8) (which is a remove candidate since it has background neighbors) at Offset(159, 159):
        await tester.tapAt(const Offset(159, 159));
        await tester.pumpAndSettle();

        // Verify that (8, 8) remains 1 (filled) because it is locked down while generating!
        expect(
          mockNotifier.state.decomposedComponents[0].grid![8][8],
          equals(1),
        );
      },
    );

    testGoldens('CanvasGrid renders active component drag handles correctly', (
      tester,
    ) async {
      final mockNotifier = CanvasNotifier(TestMockAiService());
      final compGrid = List.generate(16, (_) => List.filled(16, 0));
      mockNotifier.state = mockNotifier.state.copyWith(
        decomposedComponents: [
          PixelArtComponent(
            name: 'blade',
            description: 'vertical steel blade',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
            grid: compGrid,
          ),
        ],
        activeComponentIndex: 0,
      );

      final wizardNotifier = WizardNotifier(2); // Step 2

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 1)
        ..addScenario(
          'Canvas Grid with Drag Handles',
          const SizedBox(width: 300, height: 300, child: CanvasGrid()),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(
          overrides: [
            canvasStateProvider.overrideWith((ref) => mockNotifier),
            wizardStateProvider.overrideWith((ref) => wizardNotifier),
          ],
        ),
      );
      await screenMatchesGolden(tester, 'canvas_grid_drag_handles');
    });
  });
}
