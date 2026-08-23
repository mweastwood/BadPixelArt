import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../agents/base_agent.dart';
import '../models/bounded_canvas.dart';
import '../utils/json_utils.dart';
import '../agents/shape_sculpter_agent.dart';
import '../drawing_commands.dart';
import 'sculpting_orchestrator.dart';

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
        throw FormatException('AI sketch error: ${parsed['error']}');
      }
      return parsed;
    }
    throw FormatException('Invalid JSON map response from agent ${agent.name}');
  }

  bool isComponentDone(
    List<List<int>> compGrid,
    PixelArtComponent comp,
    int gridSize,
    bool evaluatorApproves,
  ) {
    if (!evaluatorApproves) return false;

    final bounds = comp.gridBounds(gridSize);
    if (bounds.isEmpty) return false;

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

  Future<PixelArtComponent> _sketchComponentLoop({
    required int componentIndex,
    required List<PixelArtComponent> allComponents,
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
    int maxSteps = 3,
  }) async {
    var comp = allComponents[componentIndex];
    var compGrid =
        comp.grid ?? List.generate(gridSize, (_) => List.filled(gridSize, 0));

    // Build background grid of existing components for visual reference
    final existingGrid = SculptingOrchestrator.buildBackgroundGrid(
      components: allComponents,
      excludeIndex: componentIndex,
      gridSize: gridSize,
      paletteLength: palette.length,
    );

    final List<PixelArtStepResult> history = [];
    int step = 0;

    while (step < maxSteps) {
      if (isShouldStop?.call() == true) break;
      step++;

      onStep(componentIndex, allComponents, 'Sculpting shape...');

      final context = AgentContext(
        gridSize: gridSize,
        activePalette: palette,
        userPrompt: userPrompt,
        targetComponent: comp,
        currentGrid: existingGrid,
        allComponents: allComponents,
      );

      final agent = ShapeSculpterAgent();
      final imageBytes = generateCanvasWithSculptingBmp(
        existingGrid,
        palette,
        compGrid,
      );

      Map<String, dynamic>? json;
      try {
        json = await _runAgent(
          agent,
          context,
          history,
          onLogHistory,
          imageBytes: imageBytes,
        );
      } catch (e) {
        final systemPrompt = agent.getSystemInstruction(context);
        final userPrompt = agent.getFormattedUserPrompt(context, history);
        final fullPrompt = '$systemPrompt\n\n$userPrompt';
        final entry = AgentHistoryEntry(
          timestamp: DateTime.now(),
          prompt: fullPrompt,
          response: 'Error running agent ${agent.name}: $e',
          isError: true,
        );
        onLogHistory(entry);
        rethrow;
      }

      if (json == null) break;

      final String thought = json['thought'] as String? ?? '';
      final String tool = json['tool'] as String? ?? '';
      final List<int> params = (json['params'] as List? ?? [])
          .map(parseCoordinateValue)
          .whereType<int>()
          .toList();
      final List<dynamic> rawAdd = json['add'] as List? ?? [];
      final List<dynamic> rawErase =
          (json['erase'] ?? json['remove']) as List? ?? [];
      final bool isExplicitlyComplete = json['isComplete'] as bool? ?? false;

      final boundedCanvas = BoundedCanvas(
        grid: compGrid,
        boundingBox: comp.relativeBoundingBox,
        gridSize: gridSize,
      );

      final bounds = comp.gridBounds(gridSize);
      int addedCount = 0;
      int erasedCount = 0;
      final outOfBoundsAdd = <String>[];
      final outOfBoundsErase = <String>[];

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
          x = parseCoordinateValue(coord[0]);
          y = parseCoordinateValue(coord[1]);
        } else if (coord is Map) {
          x = parseCoordinateValue(coord['x']);
          y = parseCoordinateValue(coord['y']);
        }
        if (x != null && y != null) {
          if (boundedCanvas.isWithinBounds(x, y)) {
            boundedCanvas.setPixel(x, y, 1);
            addedCount++;
          } else {
            outOfBoundsAdd.add('($x,$y)');
          }
        }
      }

      // 3. Execute erasures
      for (final coord in rawErase) {
        int? x, y;
        if (coord is List && coord.length >= 2) {
          x = parseCoordinateValue(coord[0]);
          y = parseCoordinateValue(coord[1]);
        } else if (coord is Map) {
          x = parseCoordinateValue(coord['x']);
          y = parseCoordinateValue(coord['y']);
        }
        if (x != null && y != null) {
          if (boundedCanvas.isWithinBounds(x, y)) {
            boundedCanvas.setPixel(x, y, 0);
            erasedCount++;
          } else {
            outOfBoundsErase.add('($x,$y)');
          }
        }
      }

      final feedbackParts = <String>[];
      if (tool.isNotEmpty) feedbackParts.add('Drew $tool.');
      if (addedCount > 0) feedbackParts.add('Added $addedCount pixel(s).');
      if (erasedCount > 0) feedbackParts.add('Erased $erasedCount pixel(s).');
      if (outOfBoundsAdd.isNotEmpty) {
        feedbackParts.add(
          'WARNING: ${outOfBoundsAdd.length} addition coordinate(s) [${outOfBoundsAdd.join(", ")}] were OUT OF BOUNDS and ignored! Valid component bounds are X: [${bounds.minX}..${bounds.maxX}], Y: [${bounds.minY}..${bounds.maxY}].',
        );
      }
      if (outOfBoundsErase.isNotEmpty) {
        feedbackParts.add(
          'WARNING: ${outOfBoundsErase.length} removal coordinate(s) [${outOfBoundsErase.join(", ")}] were OUT OF BOUNDS and ignored! Valid component bounds are X: [${bounds.minX}..${bounds.maxX}], Y: [${bounds.minY}..${bounds.maxY}].',
        );
      }
      final feedback = feedbackParts.isNotEmpty
          ? feedbackParts.join(' ')
          : 'Sculpt executed with no pixel modifications.';

      history.add(
        PixelArtStepResult(
          thought: thought,
          tool: tool.isNotEmpty ? tool : 'sculpt',
          params: params,
          colorIndex: 1,
          feedback: feedback,
        ),
      );

      comp = comp.copyWith(grid: compGrid, isSculpted: true);
      allComponents[componentIndex] = comp;
      onStep(componentIndex, allComponents, 'Sculpting shape...');

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

    return comp;
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
      await _sketchComponentLoop(
        componentIndex: i,
        allComponents: updatedComponents,
        gridSize: gridSize,
        palette: palette,
        userPrompt: userPrompt,
        autoRunSpeed: autoRunSpeed,
        onStep: onStep,
        onLogHistory: onLogHistory,
        isShouldStop: isShouldStop,
      );
    }

    return updatedComponents;
  }

  Future<List<PixelArtComponent>> sketchSingleComponent({
    required List<PixelArtComponent> components,
    required int targetIndex,
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
    if (targetIndex >= 0 && targetIndex < updatedComponents.length) {
      await _sketchComponentLoop(
        componentIndex: targetIndex,
        allComponents: updatedComponents,
        gridSize: gridSize,
        palette: palette,
        userPrompt: userPrompt,
        autoRunSpeed: autoRunSpeed,
        onStep: onStep,
        onLogHistory: onLogHistory,
        isShouldStop: isShouldStop,
      );
    }
    return updatedComponents;
  }
}
