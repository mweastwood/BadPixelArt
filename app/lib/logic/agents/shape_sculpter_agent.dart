import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'base_agent.dart';
import '../utils/bmp_utils.dart';
import '../utils/coordinate_converter.dart';
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

  final bounds = relativeBoundingBox.toGridBounds(gridSize);

  final dx = [0, 0, -1, 1];
  final dy = [-1, 1, 0, 0];

  for (int y = 0; y < gridSize; y++) {
    for (int x = 0; x < gridSize; x++) {
      final isInsideBox = bounds.containsPixel(x, y);
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

Uint8List generateCanvasWithSculptingBmp(
  List<List<int>>? currentGrid,
  List<Color>? palette,
  List<List<int>> targetGrid,
) {
  final int size = targetGrid.length;
  final List<List<Color>> colorGrid = List.generate(
    size,
    (y) => List.generate(size, (x) {
      final targetVal = targetGrid[y][x];
      if (targetVal > 0) {
        // Highlight current sculpting component in solid black
        return const Color(0xFF000000);
      }

      // Render previously drawn canvas components in their actual palette colors
      if (currentGrid != null &&
          currentGrid.length == size &&
          currentGrid[y].length == size) {
        final canvasVal = currentGrid[y][x];
        if (canvasVal > 0 &&
            palette != null &&
            canvasVal - 1 < palette.length) {
          return palette[canvasVal - 1];
        }
      }

      // Default background
      return const Color(0xFFFFFFFF);
    }),
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
    final gridSize = context.gridSize;

    int minX = 0, maxX = gridSize - 1, minY = 0, maxY = gridSize - 1;
    if (comp != null) {
      final bounds = comp.gridBounds(gridSize);
      minX = bounds.minX;
      maxX = bounds.maxX;
      minY = bounds.minY;
      maxY = bounds.maxY;
    }

    return 'You are an AI pixel art sculpting agent. Your job is to refine the binary pixel grid of a component to match its description: "$description".\n'
        'You can draw shape primitives, add border pixels, and remove border pixels all in a single turn.\n\n'
        'ALLOWED DRAWING AREA & BOUNDS (Canvas size: ${gridSize}x$gridSize):\n'
        '- Component Bounding Box Bounds: X range: $minX to $maxX, Y range: $minY to $maxY\n'
        '- CRITICAL: All shape primitives and pixel additions MUST be placed within X: [$minX..$maxX] and Y: [$minY..$maxY]. Any pixels outside this range will be cropped out.\n\n'
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
    final gridSize = context.gridSize;
    final grid =
        comp.grid ?? List.generate(gridSize, (_) => List.filled(gridSize, 0));
    final candidates = calculateSculptingCandidates(
      grid,
      gridSize,
      comp.relativeBoundingBox,
    );
    final removeList = candidates['remove'];
    final addList = candidates['add'];

    final bounds = comp.gridBounds(gridSize);
    final minX = bounds.minX;
    final maxX = bounds.maxX;
    final minY = bounds.minY;
    final maxY = bounds.maxY;

    String formatCompactCoords(List<Map<String, int>>? list) {
      if (list == null || list.isEmpty) return 'None';
      return list.map((c) => '(${c['x']},${c['y']})').join(' ');
    }

    final removeStr = formatCompactCoords(removeList);
    final addStr = formatCompactCoords(addList);

    final StringBuffer otherCompsBuffer = StringBuffer();
    if (context.allComponents != null && context.allComponents!.isNotEmpty) {
      otherCompsBuffer.writeln(
        'DRAWING PLAN COMPONENTS (For spatial context & alignment):',
      );
      for (final other in context.allComponents!) {
        final isCurrent = other.name == comp.name;
        final oBounds = other.gridBounds(gridSize);
        final oMinX = oBounds.minX;
        final oMaxX = oBounds.maxX;
        final oMinY = oBounds.minY;
        final oMaxY = oBounds.maxY;
        final statusStr = isCurrent
            ? '[TARGET COMPONENT]'
            : (other.isSculpted ? '[Already Sculpted]' : '[Planned]');
        otherCompsBuffer.writeln(
          '- "${other.name}" ($statusStr): X: $oMinX..$oMaxX, Y: $oMinY..$oMaxY | "${other.description}"',
        );
      }
      otherCompsBuffer.writeln(
        'NOTE: The attached image canvas displays all previously sculpted components in color, with your target component overlayed in black. Sculpt your shape so it aligns seamlessly with surrounding components.',
      );
    }

    return 'Sculpt the component "${comp.name}" (Description: "${comp.description}").\n\n'
        'TARGET COMPONENT BOUNDING BOX (Allowed drawing bounds on ${gridSize}x$gridSize grid):\n'
        'X range: $minX to $maxX | Y range: $minY to $maxY\n'
        '(MUST place shape tool parameters and pixel additions strictly within this X and Y range!)\n\n'
        '${otherCompsBuffer.isNotEmpty ? '$otherCompsBuffer\n' : ''}'
        'CANDIDATES EXPLANATION:\n'
        '- Remove Candidates: Outer edge pixels of your current shape that can be erased to trim or reshape your component.\n'
        '- Add Candidates: Empty pixels directly touching your current shape that can be added to expand or curve your component.\n'
        '- NOTE: If both candidate lists below are "None", NO base shape has been drawn yet! You MUST first use a Shape Tool (e.g. "triangle", "circle_filled", "rectangle_filled") with parameters inside X: [$minX..$maxX] and Y: [$minY..$maxY] to establish the base shape.\n\n'
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

    final imageBytes = generateCanvasWithSculptingBmp(
      context.currentGrid,
      context.activePalette,
      grid,
    );

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
        if (parsed.containsKey('error')) {
          throw FormatException('AI sculpting error: ${parsed['error']}');
        }

        final tool = parsed['tool'] as String? ?? '';
        final params = (parsed['params'] as List? ?? [])
            .map(parseCoordinateValue)
            .whereType<int>()
            .toList();
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
          if (item is Map) {
            x = parseCoordinateValue(item['x']);
            y = parseCoordinateValue(item['y']);
          } else if (item is List && item.length >= 2) {
            x = parseCoordinateValue(item[0]);
            y = parseCoordinateValue(item[1]);
          }
          if (x != null && y != null && boundedCanvas.isWithinBounds(x, y)) {
            boundedCanvas.setPixel(x, y, 1);
          }
        }

        // 3. Execute removals
        for (final item in removeList) {
          int? x, y;
          if (item is Map) {
            x = parseCoordinateValue(item['x']);
            y = parseCoordinateValue(item['y']);
          } else if (item is List && item.length >= 2) {
            x = parseCoordinateValue(item[0]);
            y = parseCoordinateValue(item[1]);
          }
          if (x != null && y != null && boundedCanvas.isWithinBounds(x, y)) {
            boundedCanvas.setPixel(x, y, 0);
          }
        }

        return newGrid;
      }
      throw const FormatException('Invalid JSON map from ShapeSculpterAgent');
    } catch (e) {
      debugPrint('Error in shape sculpter: $e');
      rethrow;
    }
  }
}
