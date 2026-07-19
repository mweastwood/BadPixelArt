import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:local_agent/local_agent.dart';
import 'base_agent.dart';
import '../utils/bmp_utils.dart';
import '../utils/json_utils.dart';

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
  List<String> get availableTools => [];

  @override
  String getSystemInstruction(AgentContext context) {
    return 'You are an AI pixel art sculpting agent. Your job is to refine the binary pixel grid of a component to better fit its description.\n'
        'You are given an image of the current component pixels (black pixels on a white background) and a list of border pixels that you can add or remove.\n'
        'Your goal is to choose which pixels to remove from the outer border/corners, and which pixels to add, to sculpt a shape that matches the description: "${context.targetComponent?.description}".\n\n'
        '- IMPORTANT: Select a MAXIMUM of 5 pixels to add and a MAXIMUM of 5 pixels to remove from the candidate lists in a single turn. Do not exceed this limit.\n'
        '- Candidate coordinates are provided in the format: (x,y).\n\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON object. Do not wrap in markdown tags (e.g. ```json).\n'
        '- The JSON object must contain two arrays:\n'
        '  1. "remove": A list of coordinate objects from the remove candidates list that should be removed (set to 0).\n'
        '  2. "add": A list of coordinate objects from the add candidates list that should be added (set to 1).\n'
        'Example output:\n'
        '{\n'
        '  "remove": [{"x": 4, "y": 2}, {"x": 4, "y": 3}],\n'
        '  "add": [{"x": 5, "y": 4}]\n'
        '}';
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
        'Remove Candidates (pixels on the border you can remove):\n$removeStr\n\n'
        'Add Candidates (pixels adjacent to the border inside the bounding box you can add):\n$addStr\n\n'
        'Analyze the image of the component shape, compare it to the description, and choose which candidates to remove and add.';
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
        final removeList = parsed['remove'] as List? ?? [];
        final addList = parsed['add'] as List? ?? [];

        final newGrid = List<List<int>>.from(
          grid.map((row) => List<int>.from(row)),
        );

        for (final item in removeList) {
          if (item is Map<String, dynamic>) {
            final x = (item['x'] as num).toInt();
            final y = (item['y'] as num).toInt();
            if (x >= 0 &&
                x < context.gridSize &&
                y >= 0 &&
                y < context.gridSize) {
              newGrid[y][x] = 0;
            }
          }
        }

        for (final item in addList) {
          if (item is Map<String, dynamic>) {
            final x = (item['x'] as num).toInt();
            final y = (item['y'] as num).toInt();
            if (x >= 0 &&
                x < context.gridSize &&
                y >= 0 &&
                y < context.gridSize) {
              newGrid[y][x] = 1;
            }
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
