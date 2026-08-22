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
import '../../test_helper.dart';

void main() {
  group('PixelArtStepResult Unit Tests', () {
    test('toJson() correctly serializes all fields', () {
      final step = PixelArtStepResult(
        thought: 'Draw circle in center',
        tool: 'circle_filled',
        params: [8, 8, 3],
        colorIndex: 2,
        feedback: 'Shape added successfully',
      );

      final json = step.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['thought'], equals('Draw circle in center'));
      expect(json['tool'], equals('circle_filled'));
      expect(json['params'], equals([8, 8, 3]));
      expect(json['colorIndex'], equals(2));
      expect(json['feedback'], equals('Shape added successfully'));
    });

    test('fromJson() deserializes fully populated JSON map and roundtrips', () {
      final json = {
        'thought': 'Erase top edge',
        'tool': 'rectangle_filled',
        'params': [4, 2, 7, 5],
        'colorIndex': 1,
        'feedback': 'Edge smoothed',
      };

      final step = PixelArtStepResult.fromJson(json);
      expect(step.thought, equals('Erase top edge'));
      expect(step.tool, equals('rectangle_filled'));
      expect(step.params, equals([4, 2, 7, 5]));
      expect(step.colorIndex, equals(1));
      expect(step.feedback, equals('Edge smoothed'));

      // Verify toJson roundtrip
      expect(step.toJson(), equals(json));
    });

    test(
      'fromJson() handles empty map and partial map with null/missing fields with default fallbacks',
      () {
        // Empty map
        final stepEmpty = PixelArtStepResult.fromJson({});
        expect(stepEmpty.thought, equals(''));
        expect(stepEmpty.tool, equals(''));
        expect(stepEmpty.params, isEmpty);
        expect(stepEmpty.colorIndex, equals(0));
        expect(stepEmpty.feedback, equals(''));

        // Map with explicit null values
        final stepNulls = PixelArtStepResult.fromJson({
          'thought': null,
          'tool': null,
          'params': null,
          'colorIndex': null,
          'feedback': null,
        });
        expect(stepNulls.thought, equals(''));
        expect(stepNulls.tool, equals(''));
        expect(stepNulls.params, isEmpty);
        expect(stepNulls.colorIndex, equals(0));
        expect(stepNulls.feedback, equals(''));

        // Partial map
        final stepPartial = PixelArtStepResult.fromJson({
          'thought': 'partial thought',
          'params': [1, 2],
        });
        expect(stepPartial.thought, equals('partial thought'));
        expect(stepPartial.tool, equals(''));
        expect(stepPartial.params, equals([1, 2]));
        expect(stepPartial.colorIndex, equals(0));
        expect(stepPartial.feedback, equals(''));
      },
    );
  });

  group('Sketch Agents Metadata and System Instruction Unit Tests', () {
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

    test('SketchPainterAgent properties and system instruction', () {
      final agent = SketchPainterAgent();
      expect(agent.name, equals('sketch_painter'));
      expect(
        agent.availableTools,
        equals([
          'circle_filled',
          'rectangle_filled',
          'ellipse_filled',
          'triangle',
        ]),
      );

      final instruction = agent.getSystemInstruction(context);
      expect(instruction, contains('ADD pixels'));
      expect(instruction, contains('blade'));
      expect(instruction, contains('restricted to ONLY using filled shapes'));
      expect(instruction, contains('allocated bounding box space'));
      // Bounding box mapping: minX=6, maxX=9, minY=2, maxY=10
      expect(instruction, contains('X: 6 to 9'));
      expect(instruction, contains('Y: 2 to 10'));
    });

    test('SketchEraserAgent properties and system instruction', () {
      final agent = SketchEraserAgent();
      expect(agent.name, equals('sketch_eraser'));
      expect(agent.availableTools, isEmpty);

      final instruction = agent.getSystemInstruction(context);
      expect(instruction, contains('REMOVE pixels'));
      expect(instruction, contains('blade'));
      expect(instruction, contains('active pixels on the outline/border'));
      expect(instruction, contains('X in [6, 9]'));
      expect(instruction, contains('Y in [2, 10]'));
    });

    test('SketchEvaluatorAgent properties and system instruction', () {
      final agent = SketchEvaluatorAgent();
      expect(agent.name, equals('sketch_evaluator'));
      expect(agent.availableTools, isEmpty);

      final instruction = agent.getSystemInstruction(context);
      expect(instruction, contains('isComplete'));
      expect(instruction, contains('feedback'));
      expect(instruction, contains('suggestions'));
      expect(instruction, contains('allocated bounding box space'));
    });

    test('Agents return fallback string when targetComponent is null', () {
      final nullTargetContext = AgentContext(
        gridSize: 16,
        activePalette: const [Colors.black, Colors.white],
        userPrompt: 'sword',
        targetComponent: null,
        currentGrid: List.generate(16, (_) => List.filled(16, 0)),
      );

      expect(
        SketchPainterAgent().getSystemInstruction(nullTargetContext),
        equals('No target component provided.'),
      );
      expect(
        SketchEraserAgent().getSystemInstruction(nullTargetContext),
        equals('No target component provided.'),
      );
      expect(
        SketchEvaluatorAgent().getSystemInstruction(nullTargetContext),
        equals('No target component provided.'),
      );
    });

    test(
      'SketchPainterAgent includes decomposed sub-shapes when comp.shapes is populated',
      () {
        final compWithShapes = PixelArtComponent(
          name: 'blade',
          description: 'vertical steel blade',
          relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.6),
          shapes: [
            FundamentalShape(
              type: 'rectangle',
              relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 0.8),
              description: 'lower shaft',
            ),
            FundamentalShape(
              type: 'triangle',
              relativeBoundingBox: const Rect.fromLTWH(0.0, 0.8, 1.0, 0.2),
              description: 'pointed blade tip',
            ),
          ],
        );

        final shapesContext = AgentContext(
          gridSize: 16,
          activePalette: const [Colors.black, Colors.white],
          userPrompt: 'sword',
          targetComponent: compWithShapes,
          currentGrid: List.generate(16, (_) => List.filled(16, 0)),
        );

        final agent = SketchPainterAgent();
        final instruction = agent.getSystemInstruction(shapesContext);

        expect(
          instruction,
          contains(
            'This component is decomposed into the following fundamental geometric shapes that you should draw:',
          ),
        );
        expect(
          instruction,
          contains(
            '- A "rectangle" representing: "lower shaft" inside local/absolute bounds: X in [6, 9], Y in [2, 8]',
          ),
        );
        expect(
          instruction,
          contains(
            '- A "triangle" representing: "pointed blade tip" inside local/absolute bounds: X in [6, 9], Y in [9, 10]',
          ),
        );
        expect(
          instruction,
          contains(
            'Draw these shape primitives to construct the overall "blade" component.',
          ),
        );
      },
    );
  });

  group('Agent Prompt Formatting (getFormattedUserPrompt) Unit Tests', () {
    final comp = PixelArtComponent(
      name: 'blade',
      description: 'vertical steel blade',
      relativeBoundingBox: const Rect.fromLTWH(
        0.25,
        0.25,
        0.5,
        0.5,
      ), // X: 4..11, Y: 4..11
    );

    // Create an 8x8 test grid with filled pixels: row 2 col 2, row 3 col 2,3,4
    final testGrid = List.generate(
      8,
      (y) => List.generate(
        8,
        (x) => ((y == 2 && x == 2) || (y == 3 && (x >= 2 && x <= 4))) ? 1 : 0,
      ),
    );

    final historySteps = [
      PixelArtStepResult(
        thought: 'Draw initial blade shaft',
        tool: 'rectangle_filled',
        params: [4, 4, 7, 8],
        colorIndex: 1,
        feedback: 'Shaft placed successfully',
      ),
      PixelArtStepResult(
        thought: 'Add blade tip',
        tool: 'triangle',
        params: [4, 4, 7, 4, 5, 2],
        colorIndex: 1,
        feedback: 'Tip placed successfully',
      ),
    ];

    test(
      'SketchPainterAgent.getFormattedUserPrompt renders ASCII grid, metadata, and history',
      () {
        final context = AgentContext(
          gridSize: 8,
          activePalette: const [Colors.black, Colors.white],
          userPrompt: 'sword',
          targetComponent: comp,
          currentGrid: testGrid,
        );

        final agent = SketchPainterAgent();

        // Prompt with history
        final promptWithHistory = agent.getFormattedUserPrompt(
          context,
          historySteps,
        );
        expect(promptWithHistory, contains('Drawing component: "blade"'));
        expect(
          promptWithHistory,
          contains('Description: "vertical steel blade"'),
        );
        expect(
          promptWithHistory,
          contains('Current grid state (0=empty, 1=filled):'),
        );
        // Verify ASCII grid rows
        expect(promptWithHistory, contains('..#.....')); // y=2
        expect(promptWithHistory, contains('..###...')); // y=3
        expect(promptWithHistory, contains('........')); // empty row
        // Verify action history
        expect(
          promptWithHistory,
          contains('History of actions in this phase:'),
        );
        expect(
          promptWithHistory,
          contains('- Thought: Draw initial blade shaft'),
        );
        expect(
          promptWithHistory,
          contains('  Action: rectangle_filled with params [4, 4, 7, 8]'),
        );
        expect(
          promptWithHistory,
          contains('  Feedback: Shaft placed successfully'),
        );
        expect(promptWithHistory, contains('- Thought: Add blade tip'));
        expect(
          promptWithHistory,
          contains('  Action: triangle with params [4, 4, 7, 4, 5, 2]'),
        );
        expect(
          promptWithHistory,
          contains('  Feedback: Tip placed successfully'),
        );
        // Verify ending
        expect(
          promptWithHistory,
          contains(
            'Propose the next drawing action to fill the volume of "blade":',
          ),
        );

        // Prompt without history
        final promptEmptyHistory = agent.getFormattedUserPrompt(context, []);
        expect(
          promptEmptyHistory,
          isNot(contains('History of actions in this phase:')),
        );
        expect(
          promptEmptyHistory,
          contains(
            'Propose the next drawing action to fill the volume of "blade":',
          ),
        );
      },
    );

    test(
      'SketchEraserAgent.getFormattedUserPrompt renders ASCII grid, active border pixels, and history',
      () {
        // Create context with grid inside blade bounding box (X: 2..5, Y: 2..5 on an 8x8 grid)
        final eraserComp = PixelArtComponent(
          name: 'blade',
          description: 'vertical steel blade',
          relativeBoundingBox: const Rect.fromLTWH(
            0.25,
            0.25,
            0.5,
            0.5,
          ), // X: 2..5, Y: 2..5
        );
        final eraserGrid = List.generate(
          8,
          (y) => List.generate(
            8,
            (x) => (x >= 2 && x <= 4 && y >= 2 && y <= 4) ? 1 : 0,
          ),
        );
        final context = AgentContext(
          gridSize: 8,
          activePalette: const [Colors.black, Colors.white],
          userPrompt: 'sword',
          targetComponent: eraserComp,
          currentGrid: eraserGrid,
        );

        final agent = SketchEraserAgent();
        final prompt = agent.getFormattedUserPrompt(context, historySteps);

        expect(prompt, contains('Erasing / Sculpting component: "blade"'));
        expect(prompt, contains('Description: "vertical steel blade"'));
        expect(prompt, contains('Current grid state (0=empty, 1=filled):'));
        expect(prompt, contains('..###...'));
        expect(
          prompt,
          contains('Active border pixels currently on the shape outline:'),
        );
        // All pixels in a 3x3 block on the bounding box edge are border pixels
        expect(prompt, contains('[2, 2]'));
        expect(prompt, contains('[4, 4]'));
        // History
        expect(prompt, contains('History of actions in this phase:'));
        expect(prompt, contains('- Thought: Draw initial blade shaft'));
        expect(
          prompt,
          contains('  Action: rectangle_filled with params [4, 4, 7, 8]'),
        );
        expect(prompt, contains('  Feedback: Shaft placed successfully'));
        // Ending
        expect(
          prompt,
          contains(
            'Propose the list of coordinates to erase from the outline to sculpt and smooth it:',
          ),
        );

        // Without history
        final promptNoHistory = agent.getFormattedUserPrompt(context, []);
        expect(
          promptNoHistory,
          isNot(contains('History of actions in this phase:')),
        );
      },
    );

    test(
      'SketchEvaluatorAgent.getFormattedUserPrompt renders evaluation prompt and history',
      () {
        final context = AgentContext(
          gridSize: 8,
          activePalette: const [Colors.black, Colors.white],
          userPrompt: 'sword',
          targetComponent: comp,
          currentGrid: testGrid,
        );

        final agent = SketchEvaluatorAgent();
        final prompt = agent.getFormattedUserPrompt(context, historySteps);

        expect(prompt, contains('Evaluating sketch for component: "blade"'));
        expect(prompt, contains('Description: "vertical steel blade"'));
        expect(prompt, contains('Current grid state (0=empty, 1=filled):'));
        expect(prompt, contains('..###...'));
        // History
        expect(prompt, contains('History of actions in this phase:'));
        expect(
          prompt,
          contains('- Action: rectangle_filled with params [4, 4, 7, 8]'),
        );
        expect(
          prompt,
          contains('  Feedback/Result: Shaft placed successfully'),
        );
        expect(
          prompt,
          contains('- Action: triangle with params [4, 4, 7, 4, 5, 2]'),
        );
        expect(prompt, contains('  Feedback/Result: Tip placed successfully'));
        // Ending
        expect(
          prompt,
          contains(
            'Evaluate the drawing and return JSON (isComplete, feedback, suggestions):',
          ),
        );

        // Without history
        final promptNoHistory = agent.getFormattedUserPrompt(context, []);
        expect(
          promptNoHistory,
          isNot(contains('History of actions in this phase:')),
        );
      },
    );
  });

  group('SketchOrchestrator Unit Tests', () {
    test(
      'isComponentDone checks evaluator approval and boundary utilization correctly',
      () {
        final mockAi = TestMockAiService(responses: []);
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

        // Case 5: Component with empty bounds returns false even if evaluator approves
        final emptyBoundsComp = PixelArtComponent(
          name: 'empty',
          description: 'empty component',
          relativeBoundingBox: const Rect.fromLTWH(0.5, 0.5, 0.0, 0.0),
        );
        expect(
          orchestrator.isComponentDone(completeGrid, emptyBoundsComp, 16, true),
          isFalse,
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

        final mockAi = TestMockAiService(responses: mockResponses);
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAi)],
        );
        addTearDown(container.dispose);

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

        final mockAi = TestMockAiService(responses: mockResponses);
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAi)],
        );
        addTearDown(container.dispose);

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

        final mockAi = TestMockAiService(responses: mockResponses);
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAi)],
        );
        addTearDown(container.dispose);

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

        final mockAi = TestMockAiService(responses: mockResponses);
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAi)],
        );
        addTearDown(container.dispose);

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

        final mockAi = TestMockAiService(responses: mockResponses);
        final container = ProviderContainer(
          overrides: [aiServiceProvider.overrideWithValue(mockAi)],
        );
        addTearDown(container.dispose);

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
        expect(finalComp.isSculpted, isTrue);
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

        final mockAi = TestMockAiService(responses: mockResponses);
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
