import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'base_agent.dart';
import '../utils/bmp_utils.dart';
import '../utils/json_utils.dart';
import '../models/bounded_canvas.dart';
import '../drawing_commands.dart';

Map<String, List<Map<String, int>>> calculateSculptingCandidates(
  List<List<int>> grid,
  int gridSize,
  Rect relativeBoundingBox,
) {
  final List<Map<String, int>> removeCandidates = [];
  final List<Map<String, int>> addCandidates = [];

  final leftCol = (relativeBoundingBox.left * gridSize).round().clamp(
    0,
    gridSize - 1,
  );
  final topRow = (relativeBoundingBox.top * gridSize).round().clamp(
    0,
    gridSize - 1,
  );
  final rightCol =
      ((relativeBoundingBox.left + relativeBoundingBox.width) * gridSize)
          .round()
          .clamp(0, gridSize);
  final bottomRow =
      ((relativeBoundingBox.top + relativeBoundingBox.height) * gridSize)
          .round()
          .clamp(0, gridSize);

  final dx = [0, 0, -1, 1];
  final dy = [-1, 1, 0, 0];

  for (int y = 0; y < gridSize; y++) {
    for (int x = 0; x < gridSize; x++) {
      final isInsideBox =
          (x >= leftCol && x < rightCol && y >= topRow && y < bottomRow);
      final val = grid[y][x];

      if (val > 0) {
        // Check if it has a background neighbor -> remove candidate
        bool hasBgNeighbor = false;
        for (int i = 0; i < 4; i++) {
          final nx = x + dx[i];
          final ny = y + dy[i];
          if (nx < 0 || nx >= gridSize || ny < 0 || ny >= gridSize) {
            hasBgNeighbor = true;
          } else if (grid[ny][nx] == 0) {
            hasBgNeighbor = true;
          }
        }
        if (hasBgNeighbor) {
          removeCandidates.add({'x': x, 'y': y});
        }
      } else {
        // val == 0. Check if inside box and has a foreground neighbor -> add candidate
        if (isInsideBox) {
          bool hasFgNeighbor = false;
          for (int i = 0; i < 4; i++) {
            final nx = x + dx[i];
            final ny = y + dy[i];
            if (nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize) {
              if (grid[ny][nx] > 0) {
                hasFgNeighbor = true;
                break;
              }
            }
          }
          if (hasFgNeighbor) {
            addCandidates.add({'x': x, 'y': y});
          }
        }
      }
    }
  }

  return {'remove': removeCandidates, 'add': addCandidates};
}

Uint8List generateSculptingBmp(List<List<int>> grid) {
  final int size = grid.length;
  final List<List<Color>> colorGrid = List.generate(
    size,
    (y) => List.generate(
      size,
      (x) => grid[y][x] > 0 ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    ),
  );
  return bmpFromColorGrid(colorGrid);
}

class ShapeSculpterAgent implements PixelArtAgent {
  @override
  String get name => 'ShapeSculpter';

  @override
  List<String> get availableTools => [
    'circle_filled',
    'rectangle_filled',
    'ellipse_filled',
    'triangle',
  ];

  @override
  String getSystemInstruction(AgentContext context) {
    final comp = context.targetComponent;
    final description = comp?.description ?? '';

    return 'You are an AI pixel art sculpting agent. Your job is to refine the binary pixel grid of a component to match its description: "$description".\n'
        'You can draw shape primitives, add border pixels, and remove border pixels all in a single turn.\n\n'
        'Available tools and parameters:\n'
        '- Shape tools (optional, set "tool": "" and "params": [] if not drawing a shape primitive):\n'
        '  - {"tool": "circle_filled", "params": [centerX, centerY, radius]}\n'
        '  - {"tool": "rectangle_filled", "params": [x1, y1, x2, y2]}\n'
        '  - {"tool": "ellipse_filled", "params": [centerX, centerY, rx, ry]}\n'
        '  - {"tool": "triangle", "params": [x1, y1, x2, y2, x3, y3]}\n'
        '- Pixel Additions (optional):\n'
        '  - "add": [{"x": 4, "y": 2}, ...] or [[4, 2], ...]\n'
        '- Pixel Removals (optional):\n'
        '  - "remove": [{"x": 4, "y": 2}, ...] or [[4, 2], ...]\n\n'
        'Output rules:\n'
        '- Output EXACTLY a valid JSON object. Do not wrap in markdown code blocks.\n'
        '- Format: { "thought": "reasoning", "tool": "", "params": [], "add": [...], "remove": [...] }\n'
        '- IMPORTANT: If you are ALREADY satisfied with the shape, return empty lists: "tool": "", "params": [], "add": [], "remove": []. Returning no instructions indicates sculpting is done.';
  }

  @override
  String getFormattedUserPrompt(
    AgentContext context,
    List<PixelArtStepResult> history,
  ) {
    final comp = context.targetComponent!;
    final grid =
        comp.grid ??
        List.generate(
          context.gridSize,
          (_) => List.filled(context.gridSize, 0),
        );
    final candidates = calculateSculptingCandidates(
      grid,
      context.gridSize,
      comp.relativeBoundingBox,
    );
    final removeList = candidates['remove'];
    final addList = candidates['add'];

    String formatCompactCoords(List<Map<String, int>>? list) {
      if (list == null || list.isEmpty) return 'None';
      return list.map((c) => '(${c['x']},${c['y']})').join(' ');
    }

    final removeStr = formatCompactCoords(removeList);
    final addStr = formatCompactCoords(addList);

    return 'Sculpt the component "${comp.name}" (Description: "${comp.description}").\n\n'
        'Remove Candidates:\n$removeStr\n\n'
        'Add Candidates:\n$addStr\n\n'
        'Provide sculpting instructions (tool, add, remove) or return empty instructions if satisfied:';
  }

  Future<List<List<int>>> sculptComponent(
    AiService aiService,
    AgentContext context,
  ) async {
    final comp = context.targetComponent!;
    final grid =
        comp.grid ??
        List.generate(
          context.gridSize,
          (_) => List.filled(context.gridSize, 0),
        );
    final systemPrompt = getSystemInstruction(context);
    final userPrompt = getFormattedUserPrompt(context, []);
    final fullPrompt = '$systemPrompt\n\n$userPrompt';

    final imageBytes = generateSculptingBmp(grid);

    try {
      final response = await aiService.generateContentWithContinuation(
        prompt: fullPrompt,
        imageBytes: imageBytes,
        temperature: 0.2,
        autoContinueLimit: 1,
      );

      if (response == null) return grid;

      final cleaned = cleanJsonString(response);
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) {
        final tool = parsed['tool'] as String? ?? '';
        final params = List<int>.from(
          (parsed['params'] as List? ?? []).map((v) => (v as num).toInt()),
        );
        final removeList = (parsed['remove'] ?? parsed['erase']) as List? ?? [];
        final addList = parsed['add'] as List? ?? [];

        // Check if agent returned no instructions -> return current grid unchanged
        if (tool.isEmpty && removeList.isEmpty && addList.isEmpty) {
          return grid;
        }

        final newGrid = List<List<int>>.from(
          grid.map((row) => List<int>.from(row)),
        );

        final boundedCanvas = BoundedCanvas(
          grid: newGrid,
          boundingBox: comp.relativeBoundingBox,
          gridSize: context.gridSize,
        );

        // 1. Execute shape tool if provided
        if (tool.isNotEmpty) {
          final command = DrawingCommandFactory.create(tool, params);
          if (command != null) {
            boundedCanvas.executeClamped((tempGrid) {
              command.execute(tempGrid, 1, context.gridSize);
            });
          }
        }

        // 2. Execute additions
        for (final item in addList) {
          int? x, y;
          if (item is Map<String, dynamic>) {
            x = (item['x'] as num?)?.toInt();
            y = (item['y'] as num?)?.toInt();
          } else if (item is List && item.length >= 2) {
            x = (item[0] as num?)?.toInt();
            y = (item[1] as num?)?.toInt();
          }
          if (x != null && y != null && boundedCanvas.isWithinBounds(x, y)) {
            boundedCanvas.setPixel(x, y, 1);
          }
        }

        // 3. Execute removals
        for (final item in removeList) {
          int? x, y;
          if (item is Map<String, dynamic>) {
            x = (item['x'] as num?)?.toInt();
            y = (item['y'] as num?)?.toInt();
          } else if (item is List && item.length >= 2) {
            x = (item[0] as num?)?.toInt();
            y = (item[1] as num?)?.toInt();
          }
          if (x != null && y != null && boundedCanvas.isWithinBounds(x, y)) {
            boundedCanvas.setPixel(x, y, 0);
          }
        }

        return newGrid;
      }
    } catch (e) {
      debugPrint('Error in shape sculpter: $e');
    }
    return grid;
  }
}
