import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../agents/base_agent.dart';
import '../agents/refinement_agent.dart';
import '../drawing_commands.dart';
import '../utils/bmp_utils.dart';
import '../utils/json_utils.dart';

class RefinementOrchestrator {
  final AiService _aiService;

  RefinementOrchestrator(this._aiService);

  Future<Map<String, dynamic>?> _runAgent(
    PixelArtAgent agent,
    AgentContext context,
    List<PixelArtStepResult> history,
    void Function(AgentHistoryEntry) onLogHistory, {
    Uint8List? imageBytes,
  }) async {
    final systemPrompt = agent.getSystemInstruction(context);
    final userPrompt = agent.getFormattedUserPrompt(context, history);
    final fullPrompt = '$systemPrompt\n\n$userPrompt';

    final response = await _aiService.generateContentWithContinuation(
      prompt: fullPrompt,
      imageBytes: imageBytes,
      temperature: 0.2,
      autoContinueLimit: 1,
    );
    if (response == null) return null;

    final cleaned = cleanJsonString(response);
    final parsed = jsonDecode(cleaned);
    if (parsed is Map<String, dynamic>) {
      if (parsed.containsKey('error')) {
        throw FormatException('AI refinement error: ${parsed['error']}');
      }
      return parsed;
    }
    throw FormatException('Invalid JSON map response from agent ${agent.name}');
  }

  Future<List<List<int>>> refine({
    required List<List<int>> initialGrid,
    required int gridSize,
    required List<Color> palette,
    required String userPrompt,
    required double autoRunSpeed,
    required void Function(List<List<int>> updatedGrid) onStep,
    required void Function(AgentHistoryEntry log) onLogHistory,
    int maxSteps = 5,
    bool Function()? isShouldStop,
    Uint8List? referenceImage,
  }) async {
    final List<List<int>> workingGrid = List.generate(
      gridSize,
      (y) => List<int>.from(initialGrid[y]),
    );

    final List<PixelArtStepResult> history = [];
    int step = 0;

    while (step < maxSteps) {
      if (isShouldStop?.call() == true) break;
      step++;

      final context = AgentContext(
        gridSize: gridSize,
        activePalette: palette,
        userPrompt: userPrompt,
        currentGrid: workingGrid,
        referenceImage: referenceImage,
      );

      final visualBytes = referenceImage != null
          ? combineBmps([
              () {
                var refGrid = bmpToDownscaledColorGrid(referenceImage, gridSize);
                if (refGrid.isEmpty) {
                  refGrid = bmpToColorGrid(referenceImage);
                  if (refGrid.isNotEmpty && refGrid.length != gridSize) {
                    refGrid = downscaleColorGrid(refGrid, gridSize);
                  }
                }
                if (refGrid.isNotEmpty) {
                  final blurredGrid = applyGaussianBlur(refGrid);
                  final quantizedGrid = applyColorQuantization(
                    blurredGrid,
                    palette,
                  );
                  return bmpFromColorGrid(quantizedGrid);
                }
                return referenceImage;
              }(),
              generateBmp(workingGrid, palette),
            ])
          : generateBmp(workingGrid, palette);

      final refinementAgent = RefinementAgent();
      Map<String, dynamic>? agentJson;
      try {
        agentJson = await _runAgent(
          refinementAgent,
          context,
          history,
          onLogHistory,
          imageBytes: visualBytes,
        );
      } catch (e) {
        final entry = AgentHistoryEntry(
          timestamp: DateTime.now(),
          prompt: 'Refine canvas with prompt: $userPrompt',
          response: 'Error during refinement: $e',
          isError: true,
        );
        onLogHistory(entry);
        rethrow;
      }

      if (agentJson != null) {
        final String thought = agentJson['thought'] as String? ?? '';
        final String tool = (agentJson['tool'] as String? ?? '')
            .trim()
            .toLowerCase();

        // Check for termination / completion signal
        if (tool == 'done' || tool == 'none' || tool.isEmpty) {
          final entry = AgentHistoryEntry(
            timestamp: DateTime.now(),
            prompt: 'Refine canvas with prompt: $userPrompt',
            response:
                'Thought: $thought\nRefinement completed: artwork is finalized.',
            isError: false,
          );
          onLogHistory(entry);
          break;
        }

        final List<int> params = (agentJson['params'] as List? ?? [])
            .map(parseCoordinateValue)
            .whereType<int>()
            .toList();
        final int colorIndex =
            parseCoordinateValue(agentJson['colorIndex']) ?? 1;

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
