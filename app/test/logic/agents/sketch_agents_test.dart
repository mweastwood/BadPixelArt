import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import 'package:bad_pixel_art/logic/agents/sketch_painter_agent.dart';
import 'package:bad_pixel_art/logic/agents/sketch_eraser_agent.dart';
import 'package:bad_pixel_art/logic/agents/sketch_evaluator_agent.dart';
import 'package:bad_pixel_art/logic/orchestrators/sketch_orchestrator.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';

class SequentialMockAiService extends AiService {
  final List<String> responses;
  int _callCount = 0;

  SequentialMockAiService(this.responses);

  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double? temperature,
    int? maxOutputTokens,
  }) async {
    if (_callCount < responses.length) {
      final res = responses[_callCount];
      _callCount++;
      return res;
    }
    return null;
  }

  @override
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    return 100;
  }
}

void main() {
  group('Sketch Agents Unit Tests', () {
    final comp = PixelArtComponent(
      name: 'blade',
      description: 'vertical steel blade',
      relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
    );

    final context = AgentContext(
      gridSize: 16,
      activePalette: const [Colors.black, Colors.white],
      userPrompt: 'sword',
      targetComponent: comp,
      currentGrid: List.generate(16, (_) => List.filled(16, 0)),
    );

    test('SketchPainterAgent builds correct instructions and bounds', () {
      final agent = SketchPainterAgent();
      final instruction = agent.getSystemInstruction(context);

      expect(instruction, contains('ADD pixels'));
      expect(instruction, contains('blade'));
      expect(instruction, contains('restricted to ONLY using filled shapes'));
      expect(instruction, contains('allocated bounding box space'));
      // Bounding box mapping: minX=6, maxX=9, minY=2, maxY=10
      expect(instruction, contains('X: 6 to 9'));
      expect(instruction, contains('Y: 2 to 10'));
    });

    test('SketchEraserAgent builds correct instructions and bounds', () {
      final agent = SketchEraserAgent();
      final instruction = agent.getSystemInstruction(context);

      expect(instruction, contains('REMOVE pixels'));
      expect(instruction, contains('blade'));
      expect(instruction, contains('active pixels on the outline/border'));
      expect(instruction, contains('X in [6, 9]'));
      expect(instruction, contains('Y in [2, 10]'));
    });

    test('SketchEvaluatorAgent instructions contain completion rules', () {
      final agent = SketchEvaluatorAgent();
      final instruction = agent.getSystemInstruction(context);

      expect(instruction, contains('isComplete'));
      expect(instruction, contains('feedback'));
      expect(instruction, contains('suggestions'));
      expect(instruction, contains('allocated bounding box space'));
    });
  });

  group('SketchOrchestrator Unit Tests', () {
    test(
      'isComponentDone checks evaluator approval and boundary utilization correctly',
      () {
        final mockAi = SequentialMockAiService([]);
        final orchestrator = SketchOrchestrator(mockAi);

        final comp = PixelArtComponent(
          name: 'blade',
          description: 'vertical steel blade',
          relativeBoundingBox: const Rect.fromLTWH(
            0.4,
            0.1,
            0.2,
            0.6,
          ), // X: 6 to 9, Y: 2 to 10
        );

        final emptyGrid = List.generate(16, (_) => List.filled(16, 0));

        // Case 1: Evaluator does not approve -> false
        expect(
          orchestrator.isComponentDone(emptyGrid, comp, 16, false),
          isFalse,
        );

        // Case 2: Evaluator approves but grid is empty -> false
        expect(
          orchestrator.isComponentDone(emptyGrid, comp, 16, true),
          isFalse,
        );

        // Case 3: Evaluator approves, but grid does not touch all boundaries (only touches Y: 2 and 10) -> false
        final partialGrid = List.generate(16, (_) => List.filled(16, 0));
        partialGrid[2][8] = 1;
        partialGrid[10][8] = 1;
        expect(
          orchestrator.isComponentDone(partialGrid, comp, 16, true),
          isFalse,
        );

        // Case 4: Evaluator approves, and grid touches all boundaries (X: 6 and 9, Y: 2 and 10) -> true
        final completeGrid = List.generate(16, (_) => List.filled(16, 0));
        completeGrid[2][8] = 1;
        completeGrid[10][8] = 1;
        completeGrid[5][6] = 1;
        completeGrid[5][9] = 1;
        expect(
          orchestrator.isComponentDone(completeGrid, comp, 16, true),
          isTrue,
        );
      },
    );
  });

  group('Orchestrated Sketching and Merging Tests', () {
    test(
      'sketchComponents loops, executes drawing command, and mergeComponentsToCanvas merges',
      () async {
        // Step 1: Painter returns a rectangle_filled command covering full bounds [6, 2, 9, 10].
        // Step 2: Eraser returns no action.
        // Step 3: Evaluator returns complete.
        final mockResponses = [
          '{"thought": "drawing rectangle using full bounds", "tool": "rectangle_filled", "params": [6, 2, 9, 10]}',
          '{"thought": "no erase needed", "erase": []}',
          '{"isComplete": true, "feedback": "good outline", "suggestions": ""}',
        ];

        final mockAi = SequentialMockAiService(mockResponses);
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAi)],
        );

        final notifier = container.read(canvasStateProvider.notifier);

        // Auto-approve component sketch when requested
        container.listen<CanvasModel>(canvasStateProvider, (previous, next) {
          if (next.confirmingComponentIndex != null) {
            notifier.respondToConfirmation(true);
          }
        });

        // Set initial components list
        notifier.state = notifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'vertical steel blade',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
            ),
          ],
          userPrompt: 'sword',
        );

        // Run sketch
        await notifier.sketchComponents();

        // Verify the component now has its own grid filled
        final finalComp = container
            .read(canvasStateProvider)
            .decomposedComponents
            .first;
        expect(finalComp.grid, isNotNull);

        // Verify outline grid calculation
        final outline = finalComp.getOutlineGrid()!;
        expect(outline[2][8], equals(1));
        expect(outline[10][8], equals(1));
        expect(outline[0][8], equals(0)); // out of bounds of the line

        // Now call mergeComponentsToCanvas
        notifier.mergeComponentsToCanvas();

        // Main grid should contain the merged outline pixels (color index 1)
        final mainGrid = container.read(canvasStateProvider).grid;
        expect(mainGrid[2][8], equals(1));
        expect(mainGrid[10][8], equals(1));
        expect(mainGrid[0][8], equals(0));
      },
    );

    test(
      'sketchComponents strictly ignores drawing commands outside the component bounding box',
      () async {
        // Step 1: Painter returns a giant rectangle covering the entire canvas (0,0 to 15,15).
        // Step 2: Eraser returns no action.
        // Step 3: Evaluator returns complete.
        final mockResponses = [
          '{"thought": "draw full screen", "tool": "rectangle_filled", "params": [0, 0, 15, 15]}',
          '{"thought": "no erase", "erase": []}',
          '{"isComplete": true, "feedback": "complete", "suggestions": ""}',
        ];

        final mockAi = SequentialMockAiService(mockResponses);
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAi)],
        );

        final notifier = container.read(canvasStateProvider.notifier);

        container.listen<CanvasModel>(canvasStateProvider, (previous, next) {
          if (next.confirmingComponentIndex != null) {
            notifier.respondToConfirmation(true);
          }
        });

        // Bounding box: X: 6 to 9, Y: 2 to 10
        notifier.state = notifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'vertical steel blade',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
            ),
          ],
          userPrompt: 'sword',
        );

        await notifier.sketchComponents();

        final finalComp = container
            .read(canvasStateProvider)
            .decomposedComponents
            .first;
        expect(finalComp.grid, isNotNull);

        // (8, 2) is inside the bounding box and should be painted (1)
        expect(finalComp.grid![2][8], equals(1));

        // (0, 0) is outside the bounding box and must be completely ignored (0)
        expect(finalComp.grid![0][0], equals(0));
        expect(finalComp.grid![15][15], equals(0));
      },
    );

    test(
      'sketchComponents supports pixel-by-pixel erasing via JSON list',
      () async {
        // Step 1: Painter draws full bounding box rectangle.
        // Step 2: Eraser erases pixel at [8, 2] and [8, 3].
        // Step 3: Evaluator returns complete.
        final mockResponses = [
          '{"thought": "draw full bounds", "tool": "rectangle_filled", "params": [6, 2, 9, 10]}',
          '{"thought": "erase corners", "erase": [[8, 2], [8, 3], [0, 0]]}', // [0,0] is outside bounding box
          '{"isComplete": true, "feedback": "complete", "suggestions": ""}',
        ];

        final mockAi = SequentialMockAiService(mockResponses);
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAi)],
        );

        final notifier = container.read(canvasStateProvider.notifier);

        container.listen<CanvasModel>(canvasStateProvider, (previous, next) {
          if (next.confirmingComponentIndex != null) {
            notifier.respondToConfirmation(true);
          }
        });

        notifier.state = notifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'vertical steel blade',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
            ),
          ],
          userPrompt: 'sword',
        );

        await notifier.sketchComponents();

        final finalComp = container
            .read(canvasStateProvider)
            .decomposedComponents
            .first;
        expect(finalComp.grid, isNotNull);

        // The erased pixels [8, 2] and [8, 3] should be 0
        expect(finalComp.grid![2][8], equals(0));
        expect(finalComp.grid![3][8], equals(0));

        // Other non-erased pixels in the bounding box should be 1
        expect(finalComp.grid![4][8], equals(1));
      },
    );

    test(
      'sketchComponents keeps iterating if the user rejects the evaluation confirmation',
      () async {
        // Step 1: Painter returns shape.
        // Step 2: Eraser returns empty.
        // Step 3: Evaluator returns complete.
        // -> User rejects!
        // Step 4: Painter returns shape again.
        // Step 5: Eraser returns empty.
        // Step 6: Evaluator returns complete.
        // -> User approves!
        final mockResponses = [
          '{"thought": "draw", "tool": "rectangle_filled", "params": [6, 2, 9, 10]}', // Painter (Loop 1)
          '{"thought": "no erase", "erase": []}', // Eraser (Loop 1)
          '{"isComplete": true, "feedback": "looks good", "suggestions": ""}', // Evaluator (Loop 1)

          '{"thought": "draw more", "tool": "rectangle_filled", "params": [6, 2, 9, 10]}', // Painter (Loop 2)
          '{"thought": "no erase", "erase": []}', // Eraser (Loop 2)
          '{"isComplete": true, "feedback": "perfect", "suggestions": ""}', // Evaluator (Loop 2)
        ];

        final mockAi = SequentialMockAiService(mockResponses);
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAi)],
        );

        final notifier = container.read(canvasStateProvider.notifier);

        notifier.state = notifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'blade',
              description: 'vertical steel blade',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
            ),
          ],
          userPrompt: 'sword',
        );

        bool rejectedOnce = false;

        container.listen<CanvasModel>(canvasStateProvider, (previous, next) {
          if (next.confirmingComponentIndex != null) {
            if (!rejectedOnce) {
              rejectedOnce = true;
              notifier.respondToConfirmation(
                false,
              ); // User clicks "No, keep iterating"
            } else {
              notifier.respondToConfirmation(
                true,
              ); // User clicks "Yes, looks good"
            }
          }
        });

        await notifier.sketchComponents();

        expect(rejectedOnce, isTrue);
        // Calls to AI service should cover two complete loops (2 * 3 = 6 calls)
        expect(mockAi._callCount, equals(6));
      },
    );
  });
}
