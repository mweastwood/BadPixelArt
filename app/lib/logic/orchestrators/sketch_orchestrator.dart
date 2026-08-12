import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../agents/base_agent.dart';
import '../models/bounded_canvas.dart';
import '../utils/json_utils.dart';
import '../agents/shape_sculpter_agent.dart';
import '../drawing_commands.dart';

class SketchOrchestrator {
  final AiService _aiService;

  SketchOrchestrator(this._aiService);

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

    try {
      final response = await _aiService.generateContentWithContinuation(
        prompt: fullPrompt,
        imageBytes: imageBytes,
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

  bool isComponentDone(
    List<List<int>> compGrid,
    PixelArtComponent comp,
    int gridSize,
    bool evaluatorApproves,
  ) {
    if (!evaluatorApproves) return false;

    final bounds = comp.gridBounds(gridSize);
    final minX = bounds.minX;
    final maxX = bounds.maxX;
    final minY = bounds.minY;
    final maxY = bounds.maxY;

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
    required void Function(
      int activeIndex,
      List<PixelArtComponent> updated,
      String status,
    )
    onStep,
    required void Function(AgentHistoryEntry log) onLogHistory,
    bool Function()? isShouldStop,
  }) async {
    final List<PixelArtComponent> updatedComponents = List.from(components);

    for (int i = 0; i < updatedComponents.length; i++) {
      if (isShouldStop?.call() == true) break;
      var comp = updatedComponents[i];
      var compGrid =
          comp.grid ?? List.generate(gridSize, (_) => List.filled(gridSize, 0));

      // Build background grid of existing components for visual reference
      final existingGrid = List.generate(
        gridSize,
        (_) => List.filled(gridSize, 0),
      );
      for (int j = 0; j < updatedComponents.length; j++) {
        if (j == i) continue;
        final other = updatedComponents[j];
        if (other.grid != null) {
          final colorIdx = (j % (palette.length - 1)) + 1;
          for (int y = 0; y < gridSize; y++) {
            for (int x = 0; x < gridSize; x++) {
              if (other.grid![y][x] > 0) {
                existingGrid[y][x] = colorIdx;
              }
            }
          }
        }
      }

      final List<PixelArtStepResult> history = [];
      int step = 0;

      while (step < 3) {
        if (isShouldStop?.call() == true) break;
        step++;

        onStep(i, updatedComponents, 'Sculpting shape...');

        final context = AgentContext(
          gridSize: gridSize,
          activePalette: palette,
          userPrompt: userPrompt,
          targetComponent: comp,
          currentGrid: existingGrid,
          allComponents: updatedComponents,
        );

        final agent = ShapeSculpterAgent();
        final imageBytes = generateCanvasWithSculptingBmp(
          existingGrid,
          palette,
          compGrid,
        );

        final json = await _runAgent(
          agent,
          context,
          history,
          onLogHistory,
          imageBytes: imageBytes,
        );

        if (json == null) break;

        final String thought = json['thought'] as String? ?? '';
        final String tool = json['tool'] as String? ?? '';
        final List<int> params = List<int>.from(
          (json['params'] as List? ?? []).map((v) => (v as num).toInt()),
        );
        final List<dynamic> rawAdd = json['add'] as List? ?? [];
        final List<dynamic> rawErase =
            (json['erase'] ?? json['remove']) as List? ?? [];
        final bool isExplicitlyComplete = json['isComplete'] as bool? ?? false;

        final boundedCanvas = BoundedCanvas(
          grid: compGrid,
          boundingBox: comp.relativeBoundingBox,
          gridSize: gridSize,
        );

        // 1. Execute shape tool if provided
        if (tool.isNotEmpty) {
          final command = DrawingCommandFactory.create(tool, params);
          if (command != null) {
            boundedCanvas.executeClamped((tempGrid) {
              command.execute(tempGrid, 1, gridSize);
            });
          }
        }

        // 2. Execute additions
        for (final coord in rawAdd) {
          int? x, y;
          if (coord is List && coord.length >= 2) {
            x = (coord[0] as num).toInt();
            y = (coord[1] as num).toInt();
          } else if (coord is Map) {
            x = (coord['x'] as num?)?.toInt();
            y = (coord['y'] as num?)?.toInt();
          }
          if (x != null && y != null && boundedCanvas.isWithinBounds(x, y)) {
            boundedCanvas.setPixel(x, y, 1);
          }
        }

        // 3. Execute erasures
        for (final coord in rawErase) {
          int? x, y;
          if (coord is List && coord.length >= 2) {
            x = (coord[0] as num).toInt();
            y = (coord[1] as num).toInt();
          } else if (coord is Map) {
            x = (coord['x'] as num?)?.toInt();
            y = (coord['y'] as num?)?.toInt();
          }
          if (x != null && y != null && boundedCanvas.isWithinBounds(x, y)) {
            boundedCanvas.setPixel(x, y, 0);
          }
        }

        history.add(
          PixelArtStepResult(
            thought: thought,
            tool: tool.isNotEmpty ? tool : 'sculpt',
            params: params,
            colorIndex: 1,
            feedback: 'Single-turn sculpt executed for ${comp.name}.',
          ),
        );

        comp = comp.copyWith(grid: compGrid, isSculpted: true);
        updatedComponents[i] = comp;
        onStep(i, updatedComponents, 'Sculpting shape...');

        // Check if agent returned no instructions or explicitly marked complete
        final bool hasNoInstructions =
            tool.isEmpty && rawAdd.isEmpty && rawErase.isEmpty;
        if (hasNoInstructions || isExplicitlyComplete) {
          break;
        }

        await Future.delayed(
          Duration(milliseconds: (autoRunSpeed * 1000).round()),
        );
      }
    }

    return updatedComponents;
  }
}
