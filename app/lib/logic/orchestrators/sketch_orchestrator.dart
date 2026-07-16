import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:local_agent/local_agent.dart';
import '../agents/base_agent.dart';
import '../models/bounded_canvas.dart';
import '../agents/sketch_painter_agent.dart';
import '../agents/sketch_eraser_agent.dart';
import '../agents/sketch_evaluator_agent.dart';
import '../drawing_commands.dart';

class SketchOrchestrator {
  final AiService _aiService;

  SketchOrchestrator(this._aiService);

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
      final response = await _aiService.generateContent(
        prompt: fullPrompt,
        temperature: 0.2,
      );
      if (response == null) return null;

      var cleaned = response.trim();
      if (cleaned.startsWith('```')) {
        final lines = cleaned.split('\n');
        if (lines.first.startsWith('```')) {
          lines.removeAt(0);
        }
        if (lines.isNotEmpty && lines.last.startsWith('```')) {
          lines.removeLast();
        }
        cleaned = lines.join('\n').trim();
      }

      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error running agent ${agent.name}: $e');
      return null;
    }
  }

  bool isComponentDone(
    List<List<int>> compGrid,
    PixelArtComponent comp,
    int gridSize,
    bool evaluatorApproves,
  ) {
    if (!evaluatorApproves) return false;

    final bbox = comp.relativeBoundingBox;
    final minX = (bbox.left * gridSize).round();
    final maxX = ((bbox.left + bbox.width) * gridSize).round() - 1;
    final minY = (bbox.top * gridSize).round();
    final maxY = ((bbox.top + bbox.height) * gridSize).round() - 1;

    bool touchMinX = false;
    bool touchMaxX = false;
    bool touchMinY = false;
    bool touchMaxY = false;

    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (compGrid[y][x] > 0) {
          if (x == minX) touchMinX = true;
          if (x == maxX) touchMaxX = true;
          if (y == minY) touchMinY = true;
          if (y == maxY) touchMaxY = true;
        }
      }
    }

    return touchMinX && touchMaxX && touchMinY && touchMaxY;
  }

  Future<List<PixelArtComponent>> sketch({
    required List<PixelArtComponent> components,
    required int gridSize,
    required List<Color> palette,
    required String userPrompt,
    required double autoRunSpeed,
    required void Function(int activeIndex, List<PixelArtComponent> updated)
    onStep,
    required void Function(AgentHistoryEntry log) onLogHistory,
    required Future<bool> Function(int componentIndex) onConfirmComponent,
  }) async {
    final List<PixelArtComponent> updatedComponents = List.from(components);

    for (int i = 0; i < updatedComponents.length; i++) {
      var comp = updatedComponents[i];
      var compGrid =
          comp.grid ?? List.generate(gridSize, (_) => List.filled(gridSize, 0));

      final List<PixelArtStepResult> history = [];
      bool evaluatorApproves = false;
      int step = 0;

      while (step < 5) {
        // Evaluate completion status first (or at loop check)
        final isDone = isComponentDone(
          compGrid,
          comp,
          gridSize,
          evaluatorApproves,
        );
        if (isDone) {
          final userApproved = await onConfirmComponent(i);
          if (userApproved) {
            break;
          } else {
            evaluatorApproves = false;
          }
        }

        step++;

        final context = AgentContext(
          gridSize: gridSize,
          activePalette: palette,
          userPrompt: userPrompt,
          targetComponent: comp,
          currentGrid: compGrid,
        );

        // 1. Run Painter
        final painterAgent = SketchPainterAgent();
        final painterJson = await _runAgent(
          painterAgent,
          context,
          history,
          onLogHistory,
        );
        if (painterJson != null) {
          final String thought = painterJson['thought'] as String? ?? '';
          final String tool = painterJson['tool'] as String? ?? '';
          final List<int> params = List<int>.from(
            (painterJson['params'] as List? ?? []).map(
              (v) => (v as num).toInt(),
            ),
          );

          final command = DrawingCommandFactory.create(tool, params);
          if (command != null) {
            final boundedCanvas = BoundedCanvas(
              grid: compGrid,
              boundingBox: comp.relativeBoundingBox,
              gridSize: gridSize,
            );
            boundedCanvas.executeClamped((tempGrid) {
              command.execute(tempGrid, 1, gridSize);
            });
          }

          history.add(
            PixelArtStepResult(
              thought: thought,
              tool: tool,
              params: params,
              colorIndex: 1,
              feedback: 'Painter executed $tool with params $params.',
            ),
          );
        }

        // Notify caller and yield
        comp = comp.copyWith(grid: compGrid);
        updatedComponents[i] = comp;
        onStep(i, updatedComponents);
        await Future.delayed(
          Duration(milliseconds: (autoRunSpeed * 1000).round()),
        );

        // Re-create context for Eraser
        final contextForEraser = AgentContext(
          gridSize: gridSize,
          activePalette: palette,
          userPrompt: userPrompt,
          targetComponent: comp,
          currentGrid: compGrid,
        );

        // 2. Run Eraser
        final eraserAgent = SketchEraserAgent();
        final eraserJson = await _runAgent(
          eraserAgent,
          contextForEraser,
          history,
          onLogHistory,
        );
        if (eraserJson != null) {
          final String thought = eraserJson['thought'] as String? ?? '';
          final List<dynamic> eraseCoords = eraserJson['erase'] as List? ?? [];
          final List<Point<int>> erasedPoints = [];

          final boundedCanvas = BoundedCanvas(
            grid: compGrid,
            boundingBox: comp.relativeBoundingBox,
            gridSize: gridSize,
          );

          for (final coord in eraseCoords) {
            if (coord is List && coord.length >= 2) {
              final x = (coord[0] as num).toInt();
              final y = (coord[1] as num).toInt();
              if (boundedCanvas.isWithinBounds(x, y)) {
                boundedCanvas.setPixel(x, y, 0); // Erase
                erasedPoints.add(Point(x, y));
              }
            }
          }

          history.add(
            PixelArtStepResult(
              thought: thought,
              tool: 'erase_pixels',
              params: erasedPoints.expand((p) => [p.x, p.y]).toList(),
              colorIndex: 0,
              feedback: 'Eraser removed pixels at coordinates: $eraseCoords.',
            ),
          );
        }

        // Notify caller and yield
        comp = comp.copyWith(grid: compGrid);
        updatedComponents[i] = comp;
        onStep(i, updatedComponents);
        await Future.delayed(
          Duration(milliseconds: (autoRunSpeed * 1000).round()),
        );

        // Re-create context for Evaluator
        final contextForEvaluator = AgentContext(
          gridSize: gridSize,
          activePalette: palette,
          userPrompt: userPrompt,
          targetComponent: comp,
          currentGrid: compGrid,
        );

        // 3. Run Evaluator
        final evaluatorAgent = SketchEvaluatorAgent();
        final evalJson = await _runAgent(
          evaluatorAgent,
          contextForEvaluator,
          history,
          onLogHistory,
        );
        if (evalJson != null) {
          evaluatorApproves = evalJson['isComplete'] as bool? ?? false;
          final String suggestions = evalJson['suggestions'] as String? ?? '';

          history.add(
            PixelArtStepResult(
              thought: 'Evaluation step',
              tool: 'evaluator',
              params: [],
              colorIndex: 0,
              feedback:
                  'Evaluator complete status: $evaluatorApproves. Suggestions: $suggestions',
            ),
          );
        } else {
          evaluatorApproves = false;
        }
      }
    }

    return updatedComponents;
  }
}
