// ignore_for_file: deprecated_member_use

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'ai_service.dart';
import 'canvas_state.dart';

abstract class AgentCanvas {
  List<List<int>> get grid;
  List<Color> get palette;
  void applyCommand(String toolName, List<int> params, int colorIndex);
  Uint8List generateCombinedVisualInput(
    Uint8List? referenceBmp,
    Uint8List? previousBmp,
  );
}

class AgentStepResult {
  final String thought;
  final String tool;
  final List<int> params;
  final int colorIndex;
  final String feedback;
  final bool isFinish;

  AgentStepResult({
    required this.thought,
    required this.tool,
    required this.params,
    required this.colorIndex,
    required this.feedback,
    this.isFinish = false,
  });
}

class AgentHarness {
  final AiService aiService;
  final AgentCanvas canvas;

  AgentHarness({required this.aiService, required this.canvas});

  /// Runs a ReAct loop for the specified max steps
  Future<List<AgentStepResult>> runDrawingLoop({
    required String userPrompt,
    required Uint8List? referenceImageBmp,
    required Uint8List? previousCanvasBmp,
    int maxSteps = 5,
    Function(AgentStepResult stepResult, int currentStep)? onStep,
  }) async {
    final List<AgentStepResult> results = [];
    final List<String> paletteHexes = canvas.palette.map((c) {
      return '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    }).toList();

    String? quantizedReferenceTextGrid;
    if (referenceImageBmp != null) {
      final quantizedGrid = getQuantizedIndexGrid(
        referenceImageBmp,
        canvas.palette,
      );
      quantizedReferenceTextGrid = canvasToTextGrid(quantizedGrid);
    }

    for (int step = 1; step <= maxSteps; step++) {
      // 1. Generate text grid representation of current canvas
      final currentCanvasTextGrid = canvasToTextGrid(canvas.grid);

      // 2. Generate combined visual image input
      final combinedBmp = canvas.generateCombinedVisualInput(
        referenceImageBmp,
        previousCanvasBmp,
      );

      // 3. Construct history string of thoughts and outcomes
      final historyBuffer = StringBuffer();
      for (int i = 0; i < results.length; i++) {
        final res = results[i];
        historyBuffer.write('\n[Step ${i + 1}] Thoughts: "${res.thought}"\n');
        historyBuffer.write(
          'Action: ${res.tool} with params ${res.params} and color index ${res.colorIndex}\n',
        );
        historyBuffer.write('Result: ${res.feedback}\n');
      }

      // 4. Format prompt
      final prompt = formatUserPrompt(
        canvasImage: combinedBmp,
        prompt: userPrompt,
        paletteColors: paletteHexes,
        isMultimodal: aiService is MethodChannelAiService,
        hasPreviousImage: previousCanvasBmp != null,
        hasReferenceImage: referenceImageBmp != null,
        currentCanvasTextGrid: currentCanvasTextGrid,
        quantizedReferenceTextGrid: quantizedReferenceTextGrid,
        loopHistory: historyBuffer.toString(),
      );

      // 5. Query AI model
      final responseMap = await aiService.getNextStroke(
        canvasImage: combinedBmp,
        prompt: prompt,
      );

      if (responseMap == null || responseMap.containsKey('error')) {
        final errorMsg =
            responseMap?['error'] ?? 'AI service returned empty response';
        final errorResult = AgentStepResult(
          thought: 'Encountered error: $errorMsg',
          tool: 'finish',
          params: [],
          colorIndex: 0,
          feedback: 'Error: $errorMsg',
          isFinish: true,
        );
        results.add(errorResult);
        if (onStep != null) {
          onStep(errorResult, step);
        }
        break;
      }

      final thought =
          responseMap['understanding'] ?? responseMap['reasoning'] ?? '';
      final tool = responseMap['tool'] as String?;
      final paramsRaw = responseMap['params'];
      final List<int> params = paramsRaw is List
          ? List<int>.from(paramsRaw.map((x) => x as int))
          : [];
      final colorIndex = responseMap['color'] as int? ?? 0;

      if (tool == null || tool == 'finish') {
        final finishResult = AgentStepResult(
          thought: thought,
          tool: 'finish',
          params: [],
          colorIndex: 0,
          feedback: 'Agent finished drawing.',
          isFinish: true,
        );
        results.add(finishResult);
        if (onStep != null) {
          onStep(finishResult, step);
        }
        break;
      }

      // Apply command to canvas
      canvas.applyCommand(tool, params, colorIndex);

      final stepFeedback =
          'Executed $tool with params $params and color index $colorIndex.';
      final stepResult = AgentStepResult(
        thought: thought,
        tool: tool,
        params: params,
        colorIndex: colorIndex,
        feedback: stepFeedback,
      );

      results.add(stepResult);
      if (onStep != null) {
        onStep(stepResult, step);
      }
    }

    return results;
  }
}
