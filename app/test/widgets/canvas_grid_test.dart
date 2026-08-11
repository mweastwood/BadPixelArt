import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bad_pixel_art/widgets/canvas_grid.dart';
import 'package:bad_pixel_art/widgets/wizard_controls.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import '../test_helper.dart';

/// Helper to calculate an absolute screen offset relative to the [CanvasGrid] widget bounds.
Offset _getCanvasOffset(
  WidgetTester tester, {
  required double relativeX,
  required double relativeY,
}) {
  final gridRect = tester.getRect(find.byType(CanvasGrid));
  final availableHeight = gridRect.height.isFinite
      ? gridRect.height - 56.0
      : gridRect.width;
  final canvasSide = math.max(0.0, math.min(gridRect.width, availableHeight));
  return gridRect.topLeft +
      Offset(relativeX * canvasSide, relativeY * canvasSide);
}

/// Helper to calculate an absolute screen offset for the center of a specific grid cell (x, y) relative to [CanvasGrid].
Offset _getGridCellOffset(
  WidgetTester tester, {
  required int gridX,
  required int gridY,
  required int gridSize,
}) {
  final gridRect = tester.getRect(find.byType(CanvasGrid));
  final availableHeight = gridRect.height.isFinite
      ? gridRect.height - 56.0
      : gridRect.width;
  final canvasSide = math.max(0.0, math.min(gridRect.width, availableHeight));
  final cellSize = canvasSide / gridSize;
  return gridRect.topLeft +
      Offset((gridX + 0.5) * cellSize, (gridY + 0.5) * cellSize);
}

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

        final wizardNotifier = WizardNotifier(WizardStep.sketchingPlan);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(width: 300, height: 356, child: CanvasGrid()),
              ),
            ),
          ),
        );

        expect(find.byType(CanvasGrid), findsOneWidget);

        // Perform a drag from the bottom-right corner to resize the bounding box.
        // Target offsets are calculated dynamically relative to the CanvasGrid finder.
        final comp = mockNotifier.state.decomposedComponents[0];
        final dragStartPos = _getCanvasOffset(
          tester,
          relativeX: comp.relativeBoundingBox.right,
          relativeY: comp.relativeBoundingBox.bottom,
        );
        final dragTargetPos = _getCanvasOffset(
          tester,
          relativeX: 0.7,
          relativeY: 0.8,
        );

        final gesture = await tester.startGesture(dragStartPos);
        await gesture.moveTo(dragTargetPos);
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

        final wizardNotifier = WizardNotifier(WizardStep.sketchingPlan);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(width: 300, height: 356, child: CanvasGrid()),
              ),
            ),
          ),
        );

        // Try to drag the bottom-right corner of the inactive 'hilt' component.
        // Offsets calculated dynamically relative to the CanvasGrid finder.
        final hiltCompInitial = mockNotifier.state.decomposedComponents[1];
        final dragStartPos = _getCanvasOffset(
          tester,
          relativeX: hiltCompInitial.relativeBoundingBox.right,
          relativeY: hiltCompInitial.relativeBoundingBox.bottom,
        );
        final dragTargetPos = _getCanvasOffset(
          tester,
          relativeX: 0.65,
          relativeY: 290 / 300,
        );

        final gesture = await tester.startGesture(dragStartPos);
        await gesture.moveTo(dragTargetPos);
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

        final wizardNotifier = WizardNotifier(WizardStep.componentSculpting);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canvasStateProvider.overrideWith((ref) => mockNotifier),
              wizardStateProvider.overrideWith((ref) => wizardNotifier),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(width: 300, height: 356, child: CanvasGrid()),
              ),
            ),
          ),
        );

        // Pixel (8, 7) is adjacent (outer border/add candidate).
        // Calculate cell position dynamically relative to CanvasGrid finder.
        final cell87Pos = _getGridCellOffset(
          tester,
          gridX: 8,
          gridY: 7,
          gridSize: mockNotifier.state.gridSize,
        );
        await tester.tapAt(cell87Pos);
        await tester.pumpAndSettle();

        // Verify that (8, 7) is now 1 (filled)
        expect(
          mockNotifier.state.decomposedComponents[0].grid![7][8],
          equals(1),
        );

        // Now set isGenerating = true to simulate AI running
        mockNotifier.state = mockNotifier.state.copyWith(isGenerating: true);
        await tester.pumpAndSettle();

        // Tap on (8, 8) (which is a remove candidate since it has background neighbors).
        final cell88Pos = _getGridCellOffset(
          tester,
          gridX: 8,
          gridY: 8,
          gridSize: mockNotifier.state.gridSize,
        );
        await tester.tapAt(cell88Pos);
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

      final wizardNotifier = WizardNotifier(WizardStep.sketchingPlan);

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 1)
        ..addScenario(
          'Canvas Grid with Drag Handles',
          const SizedBox(width: 300, height: 360, child: CanvasGrid()),
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

    testWidgets('toggles scale modes between Full, 1x Scale, and 4x Upscaled', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const Scaffold(
            body: SizedBox(width: 300, height: 360, child: CanvasGrid()),
          ),
        ),
      );

      // Default is Full mode
      expect(find.byKey(const ValueKey('canvas_scale_toggle')), findsOneWidget);
      expect(find.byKey(const ValueKey('scaled_canvas_preview')), findsNothing);

      // Switch to 1x Scale mode
      await tester.tap(find.text('1x'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('scaled_canvas_preview')),
        findsOneWidget,
      );
      expect(find.textContaining('1x True Scale'), findsOneWidget);

      // Switch to 4x Upscaled mode
      await tester.tap(find.text('4x'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('scaled_canvas_preview')),
        findsOneWidget,
      );
      expect(find.textContaining('4x Upscaled (64×64px)'), findsOneWidget);

      // Switch back to Full mode
      await tester.tap(find.text('Full'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('scaled_canvas_preview')), findsNothing);
    });

    testGoldens('CanvasGrid renders 1x True Scale golden view', (tester) async {
      final mockNotifier = CanvasNotifier(TestMockAiService());
      mockNotifier.state = mockNotifier.state.copyWith(
        grid: List.generate(16, (r) => List.generate(16, (c) => (r + c) % 4)),
      );

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 1)
        ..addScenario(
          '1x Scale Mode',
          const SizedBox(width: 300, height: 360, child: CanvasGrid()),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(
          overrides: [
            canvasStateProvider.overrideWith((ref) => mockNotifier),
            canvasScaleModeProvider.overrideWith(
              (ref) => CanvasScaleMode.scaled1x,
            ),
          ],
        ),
      );
      await screenMatchesGolden(tester, 'canvas_grid_scaled_1x');
    });

    testGoldens('CanvasGrid renders 4x Upscaled golden view', (tester) async {
      final mockNotifier = CanvasNotifier(TestMockAiService());
      mockNotifier.state = mockNotifier.state.copyWith(
        grid: List.generate(16, (r) => List.generate(16, (c) => (r + c) % 4)),
      );

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 1)
        ..addScenario(
          '4x Upscaled Mode',
          const SizedBox(width: 300, height: 360, child: CanvasGrid()),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(
          overrides: [
            canvasStateProvider.overrideWith((ref) => mockNotifier),
            canvasScaleModeProvider.overrideWith(
              (ref) => CanvasScaleMode.scaled4x,
            ),
          ],
        ),
      );
      await screenMatchesGolden(tester, 'canvas_grid_scaled_4x');
    });
  });
}
