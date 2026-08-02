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
        // Single turn: Painter draws rectangle and signals completion with empty next turn
        final mockResponses = [
          '{"thought": "drawing rectangle using full bounds", "tool": "rectangle_filled", "params": [6, 2, 9, 10], "add": [], "erase": []}',
          '{"thought": "done", "tool": "", "params": [], "add": [], "erase": []}',
        ];

        final mockAi = SequentialMockAiService(mockResponses);
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAi)],
        );

        final notifier = container.read(canvasStateProvider.notifier);

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

        // Verify the component now has its own grid filled and isSculpted is true
        final finalComp = container
            .read(canvasStateProvider)
            .decomposedComponents
            .first;
        expect(finalComp.grid, isNotNull);
        expect(finalComp.isSculpted, isTrue);

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
        final mockResponses = [
          '{"thought": "draw full screen", "tool": "rectangle_filled", "params": [0, 0, 15, 15], "add": [], "erase": []}',
          '{"thought": "done", "tool": "", "params": [], "add": [], "erase": []}',
        ];

        final mockAi = SequentialMockAiService(mockResponses);
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAi)],
        );

        final notifier = container.read(canvasStateProvider.notifier);

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
      'sketchComponents supports pixel-by-pixel erasing via JSON list in single turn',
      () async {
        final mockResponses = [
          '{"thought": "draw full bounds and erase corners in one turn", "tool": "rectangle_filled", "params": [6, 2, 9, 10], "erase": [[8, 2], [8, 3], [0, 0]]}',
          '{"thought": "done", "tool": "", "params": [], "add": [], "erase": []}',
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
      'sketchComponents sculpts all components sequentially in single turn each',
      () async {
        final mockResponses = [
          '{"thought": "drawing blade", "tool": "rectangle_filled", "params": [6, 2, 9, 10]}',
          '{"thought": "blade done", "tool": "", "params": [], "add": [], "erase": []}',
          '{"thought": "drawing handle", "tool": "rectangle_filled", "params": [6, 12, 9, 14]}',
          '{"thought": "handle done", "tool": "", "params": [], "add": [], "erase": []}',
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
            PixelArtComponent(
              name: 'handle',
              description: 'bottom leather handle',
              relativeBoundingBox: const Rect.fromLTWH(0.4, 0.7, 0.2, 0.2),
            ),
          ],
          userPrompt: 'sword',
        );

        await notifier.sketchComponents();

        final finalComps = container
            .read(canvasStateProvider)
            .decomposedComponents;
        expect(finalComps[0].grid, isNotNull);
        expect(finalComps[1].grid, isNotNull);
      },
    );

    test(
      'sketchComponents terminates early when agent returns no instructions (empty tool/add/erase)',
      () async {
        // Turn 1 returns no instructions -> immediate exit on turn 1
        final mockResponses = [
          '{"thought": "shape is already perfect", "tool": "", "params": [], "add": [], "erase": []}',
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

        await notifier.sketchComponents();

        final history = container.read(canvasStateProvider).aiHistory;
        expect(
          history.any((log) => log.response.contains('Satisfied with shape')),
          isTrue,
        );
      },
    );

    test(
      'SketchOrchestrator passes BMP imageBytes and background spatial context, and sets isSculpted: true',
      () async {
        final mockResponses = [
          '{"thought": "drawing blade", "tool": "rectangle_filled", "params": [6, 2, 9, 10]}',
          '{"thought": "blade complete", "tool": "", "params": [], "add": [], "erase": []}',
          '{"thought": "drawing handle", "tool": "rectangle_filled", "params": [6, 12, 9, 14]}',
          '{"thought": "handle complete", "tool": "", "params": [], "add": [], "erase": []}',
        ];

        final mockAi = ImageCaptureMockAiService(mockResponses);
        final orchestrator = SketchOrchestrator(mockAi);

        final components = [
          PixelArtComponent(
            name: 'blade',
            description: 'steel blade',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
          ),
          PixelArtComponent(
            name: 'handle',
            description: 'leather handle',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.7, 0.2, 0.2),
          ),
        ];

        final resultComps = await orchestrator.sketch(
          components: components,
          gridSize: 16,
          palette: const [Colors.black, Colors.white, Colors.red],
          userPrompt: 'sword',
          autoRunSpeed: 0.0,
          onStep: (activeIndex, updated, status) {},
          onLogHistory: (log) {},
        );

        // 1. Verify imageBytes were passed to every AI call
        expect(mockAi.capturedImageBytes.length, greaterThanOrEqualTo(2));
        for (final img in mockAi.capturedImageBytes) {
          expect(img, isNotNull);
          expect(img!.length, greaterThan(0));
        }

        // 2. Verify both components are marked as isSculpted: true
        expect(resultComps[0].isSculpted, isTrue);
        expect(resultComps[1].isSculpted, isTrue);

        // 3. Verify spatial context was included in prompts
        expect(
          mockAi.capturedPrompts.any(
            (p) => p.contains(
              'DRAWING PLAN COMPONENTS (For spatial context & alignment)',
            ),
          ),
          isTrue,
        );
      },
    );
  });
}

class ImageCaptureMockAiService extends SequentialMockAiService {
  final List<Uint8List?> capturedImageBytes = [];
  final List<String> capturedPrompts = [];

  ImageCaptureMockAiService(super.responses);

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double? temperature,
    int? maxOutputTokens,
  }) async {
    capturedPrompts.add(prompt);
    capturedImageBytes.add(imageBytes);
    return super.generateContent(
      prompt: prompt,
      imageBytes: imageBytes,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
    );
  }
}
