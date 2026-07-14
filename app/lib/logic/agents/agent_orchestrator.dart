import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:local_agent/local_agent.dart';
import '../commands/drawing_command_factory.dart';
import '../bmp_helper.dart';
import 'base_agent.dart';
import 'decomposer_agent.dart';
import 'painter_agent.dart';
import 'eraser_agent.dart';
import 'evaluator_agent.dart';
import 'polisher_agent.dart';

class SketchResult {
  final List<List<int>> grid;
  final int lastColorIndex;
  final String rawPrompt;
  final String rawResponse;

  SketchResult({
    required this.grid,
    required this.lastColorIndex,
    required this.rawPrompt,
    required this.rawResponse,
  });
}

class AgentOrchestrator {
  final AiService aiService;

  final DecomposerAgent decomposer = DecomposerAgent();
  final PainterAgent painter = PainterAgent();
  final EraserAgent eraser = EraserAgent();
  final EvaluatorAgent evaluator = EvaluatorAgent();
  final PolisherAgent polisher = PolisherAgent();

  AgentOrchestrator({required this.aiService});

  /// Helper to generate the visual representation (current grid BMP).
  Uint8List generateAgentVisualInput(AgentContext context) {
    return generateBmp(context.currentGrid, context.activePalette);
  }

  /// Step 3: Decomposes a user prompt into visual components and bounding boxes.
  Future<List<PixelArtComponent>> decomposePrompt(
    int gridSize,
    List<Color> palette,
    String userPrompt, {
    Uint8List? referenceImage,
  }) async {
    final context = AgentContext(
      gridSize: gridSize,
      activePalette: palette,
      userPrompt: userPrompt,
      currentGrid: List.generate(gridSize, (_) => List.filled(gridSize, 0)),
      referenceImage: referenceImage,
    );

    final system = decomposer.getSystemInstruction(context);
    final user = decomposer.getFormattedUserPrompt(context, []);

    try {
      final jsonList = await aiService.generateJson(
        prompt: '$system\n\n$user',
        temperature: 0.1,
      );

      if (jsonList is List) {
        return jsonList
            .map(
              (item) =>
                  PixelArtComponent.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Error decomposing prompt: $e');
    }

    // Fallback: Return a single component if decomposition fails
    return [
      PixelArtComponent(
        name: 'main',
        description: userPrompt,
        relativeBoundingBox: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
        proposedBaseColor: palette.length > 1 ? palette[1] : palette[0],
      ),
    ];
  }

  /// Step 3: Runs Painter/Eraser/Evaluator loop for outline sketching and merges results.
  Future<SketchResult> runMultiAgentSketch(
    int gridSize,
    List<Color> palette,
    String userPrompt,
    List<PixelArtComponent> components,
    Uint8List? referenceImage,
    Function(String progressMessage) onProgress,
  ) async {
    final List<List<int>> finalGrid = List.generate(
      gridSize,
      (_) => List.filled(gridSize, 0),
    );
    int lastColorIndex = 1;
    String lastPainterPrompt = '';
    String lastPainterResponse = '';

    for (final comp in components) {
      onProgress('Sketching outlines for component "${comp.name}"...');

      final List<List<int>> compGrid = List.generate(
        gridSize,
        (_) => List.filled(gridSize, 0),
      );

      final List<Map<String, dynamic>> stepHistory = [];
      final List<List<List<int>>> localUndoStack = [];
      int currentScore = 0;
      bool satisfied = false;

      for (int step = 1; step <= 3; step++) {
        onProgress('Painter Agent drawing step $step for "${comp.name}"...');

        final context = AgentContext(
          gridSize: gridSize,
          activePalette: palette,
          userPrompt: userPrompt,
          targetComponent: comp,
          currentGrid: compGrid,
          referenceImage: referenceImage,
        );

        final imageBytes = generateAgentVisualInput(context);

        // Save state for undo
        localUndoStack.add(compGrid.map((row) => List<int>.from(row)).toList());

        // 1. Run Painter Agent to place pixels
        final painterSystem = painter.getSystemInstruction(context);
        final painterUser = painter.getFormattedUserPrompt(
          context,
          stepHistory,
        );
        final promptStr = '$painterSystem\n\n$painterUser';

        final painterResult = await aiService.generateJson(
          prompt: promptStr,
          imageBytes: imageBytes,
          temperature: 0.5,
        );

        lastPainterPrompt = promptStr;
        lastPainterResponse = painterResult is String
            ? painterResult
            : jsonEncode(painterResult);

        if (painterResult is Map<String, dynamic>) {
          final tool = painterResult['tool'] as String? ?? 'pixel';
          final params = (painterResult['params'] as List?)?.cast<int>() ?? [];

          if (tool == 'undo') {
            if (localUndoStack.isNotEmpty) {
              final prev = localUndoStack.removeLast();
              for (int y = 0; y < gridSize; y++) {
                compGrid[y] = List<int>.from(prev[y]);
              }
              stepHistory.add({
                'tool': 'undo',
                'params': <int>[],
                'color': 0,
                'feedback': 'Undid the last stroke.',
              });
            }
            continue;
          }

          final colorIndex = painterResult['color'] as int? ?? 1;
          lastColorIndex = colorIndex;

          final command = DrawingCommandFactory.create(tool, params);
          if (command != null) {
            command.execute(compGrid, colorIndex, gridSize);
            stepHistory.add({
              'tool': tool,
              'params': params,
              'color': colorIndex,
              'feedback': 'Applied $tool stroke.',
            });
          }
        }

        // Update visual input for Evaluator
        final evalContext = AgentContext(
          gridSize: gridSize,
          activePalette: palette,
          userPrompt: userPrompt,
          targetComponent: comp,
          currentGrid: compGrid,
          referenceImage: referenceImage,
        );
        final evalImageBytes = generateAgentVisualInput(evalContext);

        // 2. Run Evaluator Agent to review quality
        onProgress(
          'Evaluator Agent reviewing step $step for "${comp.name}"...',
        );
        final evalSystem = evaluator.getSystemInstruction(evalContext);
        final evalUser = evaluator.getFormattedUserPrompt(evalContext, []);

        final evalResult = await aiService.generateJson(
          prompt: '$evalSystem\n\n$evalUser',
          imageBytes: evalImageBytes,
          temperature: 0.1,
        );

        if (evalResult is Map<String, dynamic>) {
          currentScore = evalResult['score'] as int? ?? 0;
          satisfied = evalResult['isSatisfied'] as bool? ?? false;
          final critique = evalResult['critique'] as String? ?? '';
          onProgress(
            'Evaluator Score: $currentScore/10. Critique: "$critique"',
          );

          if (satisfied) {
            break;
          }

          // If outline has issues, run Eraser Agent to sculpt/thin
          if (currentScore < 7) {
            onProgress('Eraser Agent sculpting outlines for "${comp.name}"...');
            final eraserContext = AgentContext(
              gridSize: gridSize,
              activePalette: palette,
              userPrompt: userPrompt,
              targetComponent: comp,
              currentGrid: compGrid,
              referenceImage: referenceImage,
            );
            final eraserImageBytes = generateAgentVisualInput(eraserContext);
            final eraserSystem = eraser.getSystemInstruction(eraserContext);
            final eraserUser = eraser.getFormattedUserPrompt(
              eraserContext,
              stepHistory,
            );

            final eraserResult = await aiService.generateJson(
              prompt: '$eraserSystem\n\n$eraserUser',
              imageBytes: eraserImageBytes,
              temperature: 0.3,
            );

            if (eraserResult is Map<String, dynamic>) {
              final tool = eraserResult['tool'] as String? ?? 'pixel';
              final params =
                  (eraserResult['params'] as List?)?.cast<int>() ?? [];

              final command = DrawingCommandFactory.create(tool, params);
              if (command != null) {
                command.execute(compGrid, 0, gridSize); // Erase = color index 0
                stepHistory.add({
                  'tool': tool,
                  'params': params,
                  'color': 0,
                  'feedback': 'Erased outlines using $tool.',
                });
              }
            }
          }
        }
      }

      // Merge non-zero outline pixels into final grid
      for (int y = 0; y < gridSize; y++) {
        for (int x = 0; x < gridSize; x++) {
          if (compGrid[y][x] != 0) {
            finalGrid[y][x] = compGrid[y][x];
          }
        }
      }
    }

    return SketchResult(
      grid: finalGrid,
      lastColorIndex: lastColorIndex,
      rawPrompt: lastPainterPrompt,
      rawResponse: lastPainterResponse,
    );
  }

  /// Step 7: Runs the Polisher Agent for a triggerable cleanup (anti-aliasing, selective outlines).
  Future<void> runPolishing(
    List<List<int>> grid,
    int gridSize,
    List<Color> palette,
    String actionName,
    Uint8List? referenceImage,
    Function(String progressMessage) onProgress,
  ) async {
    onProgress('Polishing art: "$actionName"...');
    final context = AgentContext(
      gridSize: gridSize,
      activePalette: palette,
      userPrompt: actionName,
      currentGrid: grid,
      referenceImage: referenceImage,
    );

    final system = polisher.getSystemInstruction(context);
    final user = polisher.getFormattedUserPrompt(context, []);
    final imageBytes = generateAgentVisualInput(context);

    try {
      final result = await aiService.generateJson(
        prompt: '$system\n\n$user',
        imageBytes: imageBytes,
        temperature: 0.2,
      );

      if (result is Map<String, dynamic>) {
        final modifications = result['modifications'] as List?;
        if (modifications != null) {
          int count = 0;
          for (final mod in modifications) {
            if (mod is List && mod.length >= 3) {
              final x = mod[0] as int;
              final y = mod[1] as int;
              final colorIndex = mod[2] as int;

              if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
                grid[y][x] = colorIndex;
                count++;
              }
            }
          }
          onProgress('Polisher applied $count pixel modifications.');
        }
      }
    } catch (e) {
      debugPrint('Error during polish: $e');
    }
  }
}
