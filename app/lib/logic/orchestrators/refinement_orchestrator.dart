import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../agents/base_agent.dart';
import '../agents/refinement_agent.dart';
import '../drawing_commands.dart';
import '../utils/json_utils.dart';

class RefinementOrchestrator {
  final AiService _aiService;

  RefinementOrchestrator(this._aiService);

  Future<Map<String, dynamic>?> _runAgent(
    PixelArtAgent agent,
    AgentContext context,
    List<PixelArtStepResult> history,
    void Function(AgentHistoryEntry) onLogHistory,
  ) async {
    final systemPrompt = agent.getSystemInstruction(context);
    final userPrompt = agent.getFormattedUserPrompt(context, history);
    final fullPrompt = '$systemPrompt\n\n$userPrompt';

    try {
      final response = await _aiService.generateContentWithContinuation(
        prompt: fullPrompt,
        temperature: 0.2,
        autoContinueLimit: 1,
      );
      if (response == null) return null;

      final cleaned = cleanJsonString(response);
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error running agent ${agent.name}: $e');
      return null;
    }
  }

  Future<List<List<int>>> refine({
    required List<List<int>> initialGrid,
    required int gridSize,
    required List<Color> palette,
    required String userPrompt,
    required double autoRunSpeed,
    required void Function(List<List<int>> updatedGrid) onStep,
    required void Function(AgentHistoryEntry log) onLogHistory,
  }) async {
    final List<List<int>> workingGrid = List.generate(
      gridSize,
      (y) => List<int>.from(initialGrid[y]),
    );

    final List<PixelArtStepResult> history = [];
    int step = 0;
    const maxSteps = 5;

    while (step < maxSteps) {
      step++;

      final context = AgentContext(
        gridSize: gridSize,
        activePalette: palette,
        userPrompt: userPrompt,
        currentGrid: workingGrid,
      );

      final refinementAgent = RefinementAgent();
      final agentJson = await _runAgent(
        refinementAgent,
        context,
        history,
        onLogHistory,
      );

      if (agentJson != null) {
        final String thought = agentJson['thought'] as String? ?? '';
        final String tool = agentJson['tool'] as String? ?? '';
        final List<int> params = List<int>.from(
          (agentJson['params'] as List? ?? []).map((v) => (v as num).toInt()),
        );
        final int colorIndex = agentJson['colorIndex'] as int? ?? 1;

        final command = DrawingCommandFactory.create(tool, params);
        if (command != null) {
          // Execute drawing directly onto workingGrid (restricted to grid size bounds)
          command.execute(workingGrid, colorIndex, gridSize);
        }

        final entry = AgentHistoryEntry(
          timestamp: DateTime.now(),
          prompt: 'Refine canvas with prompt: $userPrompt',
          response:
              'Thought: $thought\nAction: $tool with params $params using colorIndex $colorIndex\nRaw: ${jsonEncode(agentJson)}',
          isError: false,
        );
        onLogHistory(entry);

        history.add(
          PixelArtStepResult(
            thought: thought,
            tool: tool,
            params: params,
            colorIndex: colorIndex,
            feedback:
                'Refinement agent executed $tool with colorIndex $colorIndex.',
          ),
        );
      } else {
        break; // Stop if AI returns nothing or fails
      }

      onStep(workingGrid);
      await Future.delayed(
        Duration(milliseconds: (autoRunSpeed * 1000).round()),
      );
    }

    return workingGrid;
  }
}
