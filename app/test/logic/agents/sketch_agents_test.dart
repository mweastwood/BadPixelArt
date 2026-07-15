import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_agent/local_agent.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import 'package:bad_pixel_art/logic/agents/sketch_painter_agent.dart';
import 'package:bad_pixel_art/logic/agents/sketch_eraser_agent.dart';
import 'package:bad_pixel_art/logic/agents/sketch_evaluator_agent.dart';
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
      // Bounding box mapping: minX=6, maxX=9, minY=2, maxY=10
      expect(instruction, contains('X: 6 to 9'));
      expect(instruction, contains('Y: 2 to 10'));
    });

    test('SketchEraserAgent builds correct instructions and bounds', () {
      final agent = SketchEraserAgent();
      final instruction = agent.getSystemInstruction(context);

      expect(instruction, contains('REMOVE pixels'));
      expect(instruction, contains('blade'));
      expect(instruction, contains('restricted to ONLY using filled shapes'));
      expect(instruction, contains('X: 6 to 9'));
      expect(instruction, contains('Y: 2 to 10'));
    });

    test('SketchEvaluatorAgent instructions contain completion rules', () {
      final agent = SketchEvaluatorAgent();
      final instruction = agent.getSystemInstruction(context);

      expect(instruction, contains('isComplete'));
      expect(instruction, contains('feedback'));
      expect(instruction, contains('suggestions'));
    });
  });

  group('Orchestrated Sketching and Merging Tests', () {
    test(
      'sketchComponents loops, executes drawing command, and mergeComponentsToCanvas merges',
      () async {
        // Step 1: Evaluator returns not complete, suggests drawing.
        // Step 2: Painter returns a rectangleFilled command.
        // Step 3: Evaluator returns complete.
        final mockResponses = [
          '{"isComplete": false, "feedback": "empty", "suggestions": "draw a rectangle from 8,2 to 8,10"}',
          '{"thought": "drawing rectangle", "tool": "rectangle_filled", "params": [8, 2, 8, 10]}',
          '{"isComplete": true, "feedback": "good outline", "suggestions": ""}',
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

        // Verify the component now has its own grid filled
        final finalComp = container
            .read(canvasStateProvider)
            .decomposedComponents
            .first;
        expect(finalComp.grid, isNotNull);

        // Verify outline grid calculation: (8,2) to (8,10) is a vertical line.
        // Since it's a 1-pixel wide line, all of its pixels are boundary/outline pixels!
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
  });
}
