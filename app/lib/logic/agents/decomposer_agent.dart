import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import 'base_agent.dart';
import '../utils/coordinate_converter.dart';
import '../utils/json_utils.dart';

class DecomposerResult {
  final List<PixelArtComponent> components;
  final String rawPrompt;
  final String rawResponse;

  DecomposerResult({
    required this.components,
    required this.rawPrompt,
    required this.rawResponse,
  });
}

class _RawParsedComponent {
  final String name;
  final String description;
  final Rect rect;
  final List<FundamentalShape> shapes;

  _RawParsedComponent({
    required this.name,
    required this.description,
    required this.rect,
    this.shapes = const [],
  });
}

class DecomposerAgent implements PixelArtAgent {
  @override
  String get name => 'Decomposer';

  @override
  List<String> get availableTools => [];

  @override
  String getSystemInstruction(AgentContext context) {
    final bool hasTemplate = context.currentGrid.any(
      (row) => row.any((cell) => cell > 0),
    );

    final templateInstructions = hasTemplate
        ? '\nEXISTING BASE TEMPLATE PRESENT:\n'
              'The canvas already contains an existing base template (e.g. base character body/silhouette).\n'
              '- DO NOT replicate, re-decompose, or re-draw the base body/silhouette or any features already established by the template.\n'
              '- Focus EXCLUSIVELY on decomposing ADD-ON components requested in the user prompt (such as armor, clothing, cape, wings, weapons, shield, helmet/hat, hair, accessories, magical effects).\n'
              '- Ensure the relative bounding boxes for these new add-on components align properly with the base template body (on a 0.0 to 1.0 scale).\n'
        : '';

    return 'You are an AI pixel art decomposer agent. Your job is to analyze a drawing prompt and break it down into its constituent semantic components.\n'
        'For each component, you must identify:\n'
        '1. "name": The name of the component (e.g. "blade", "hilt", "guard").\n'
        '2. "description": A descriptive instruction of what to draw (e.g. "straight blade with a sharp tip").\n'
        '3. "relativeBoundingBox": A bounding box where this component should be drawn, using normalized coordinates from 0.0 to 1.0. Bounding boxes can overlap. Format as: { "left": double, "top": double, "width": double, "height": double }\n\n'
        '$templateInstructions\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON array of objects. Do not wrap in markdown tags (e.g. ```json).\n'
        '- Bounding boxes must cover the area of the components on a 0.0 to 1.0 scale.\n'
        '- Keep descriptions short (max 15 words).\n'
        'Example output:\n'
        '[\n'
        '  {\n'
        '    "name": "blade",\n'
        '    "description": "vertical gray steel blade",\n'
        '    "relativeBoundingBox": { "left": 0.4, "top": 0.1, "width": 0.2, "height": 0.6 }\n'
        '  },\n'
        '  {\n'
        '    "name": "hilt",\n'
        '    "description": "brown handle at bottom",\n'
        '    "relativeBoundingBox": { "left": 0.45, "top": 0.7, "width": 0.1, "height": 0.25 }\n'
        '  }\n'
        ']';
  }

  @override
  String getFormattedUserPrompt(
    AgentContext context,
    List<PixelArtStepResult> history,
  ) {
    final bool hasTemplate = context.currentGrid.any(
      (row) => row.any((cell) => cell > 0),
    );

    if (hasTemplate) {
      final textGrid = StringBuffer();
      final size = context.gridSize;
      for (int y = 0; y < size; y++) {
        final row = context.currentGrid[y]
            .map((v) => v > 0 ? '#' : '.')
            .join('');
        textGrid.writeln(row);
      }

      return 'A base template is already loaded on the canvas ($size x $size):\n'
          '$textGrid\n'
          'Decompose ONLY the additional items, equipment, armor, accessories, weapons, wings, cape, or garments required for: "${context.userPrompt}" without re-creating the base template.';
    }

    return 'Decompose the drawing instruction: "${context.userPrompt}" into its sub-components with bounding boxes.';
  }

  Future<DecomposerResult> decompose(
    AiService aiService,
    AgentContext context,
  ) async {
    final systemPrompt = getSystemInstruction(context);
    final userPrompt = getFormattedUserPrompt(context, []);
    final fullPrompt = '$systemPrompt\n\n$userPrompt';
    final response = await aiService.generateContentWithContinuation(
      prompt: fullPrompt,
      imageBytes: context.referenceImage,
      temperature: 0.7,
      autoContinueLimit: 1,
    );

    if (response == null) {
      throw const FormatException('Null response from AI Service');
    }

    final cleaned = cleanJsonString(response);
    final parsed = jsonDecode(cleaned);
    if (parsed is List) {
      final List<_RawParsedComponent> parsedItems = [];
      for (final item in parsed) {
        if (item is Map<String, dynamic>) {
          final name = item['name'] as String? ?? 'component';
          final description = item['description'] as String? ?? '';
          final bbox =
              item['relativeBoundingBox'] as Map<String, dynamic>? ?? {};

          final left = (bbox['left'] as num? ?? 0.0).toDouble();
          final top = (bbox['top'] as num? ?? 0.0).toDouble();
          final width = (bbox['width'] as num? ?? 1.0).toDouble().clamp(
            0.01,
            1.0,
          );
          final height = (bbox['height'] as num? ?? 1.0).toDouble().clamp(
            0.01,
            1.0,
          );

          // Parse shapes
          final List<FundamentalShape> parsedShapes = [];
          final shapesRaw = item['shapes'] as List? ?? [];
          for (final s in shapesRaw) {
            if (s is Map<String, dynamic>) {
              final type = s['type'] as String? ?? 'rectangle';
              final desc = s['description'] as String? ?? '';
              final sBbox =
                  s['relativeBoundingBox'] as Map<String, dynamic>? ?? {};
              final sLeft = (sBbox['left'] as num? ?? 0.0).toDouble();
              final sTop = (sBbox['top'] as num? ?? 0.0).toDouble();
              final sWidth = (sBbox['width'] as num? ?? 1.0).toDouble().clamp(
                0.0,
                1.0,
              );
              final sHeight = (sBbox['height'] as num? ?? 1.0).toDouble().clamp(
                0.0,
                1.0,
              );
              parsedShapes.add(
                FundamentalShape(
                  type: type,
                  description: desc,
                  relativeBoundingBox: Rect.fromLTWH(
                    sLeft,
                    sTop,
                    sWidth,
                    sHeight,
                  ),
                ),
              );
            }
          }

          parsedItems.add(
            _RawParsedComponent(
              name: name,
              description: description,
              rect: Rect.fromLTWH(left, top, width, height),
              shapes: parsedShapes,
            ),
          );
        }
      }

      if (parsedItems.isNotEmpty) {
        final bool hasTemplate = context.currentGrid.any(
          (row) => row.any((cell) => cell > 0),
        );

        final List<PixelArtComponent> components;
        if (hasTemplate) {
          // If a base template is present, align add-on components directly without re-scaling/centering
          components = parsedItems.map((item) {
            final alignedRect = _alignRectToPixels(item.rect, context.gridSize);
            return PixelArtComponent(
              name: item.name,
              description: item.description,
              relativeBoundingBox: alignedRect,
              shapes: item.shapes,
            );
          }).toList();

          // Retain the base template as the foundational component at index 0
          final templateGrid = List.generate(
            context.gridSize,
            (y) => List.generate(
              context.gridSize,
              (x) => context.currentGrid[y][x] > 0 ? 1 : 0,
            ),
          );
          final templateComponent = PixelArtComponent(
            name: 'base_template',
            description: 'Base template body / silhouette',
            relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
            grid: templateGrid,
            isSculpted: true,
          );
          components.insert(0, templateComponent);
        } else {
          components = _scaleAndCenter(parsedItems, context.gridSize);
        }

        return DecomposerResult(
          components: components,
          rawPrompt: fullPrompt,
          rawResponse: response,
        );
      }
    }

    throw const FormatException(
      'Failed to parse decomposition components from response',
    );
  }

  List<PixelArtComponent> _scaleAndCenter(
    List<_RawParsedComponent> items,
    int gridSize,
  ) {
    if (items.isEmpty) return [];

    // 1. Calculate overall combined bounding box of all raw components
    double minL = 1.0;
    double minT = 1.0;
    double maxR = 0.0;
    double maxB = 0.0;

    for (final item in items) {
      final rect = item.rect;
      if (rect.left < minL) minL = rect.left;
      if (rect.top < minT) minT = rect.top;
      if (rect.left + rect.width > maxR) maxR = rect.left + rect.width;
      if (rect.top + rect.height > maxB) maxB = rect.top + rect.height;
    }

    final double overallW = (maxR - minL).clamp(0.0001, 1.0);
    final double overallH = (maxB - minT).clamp(0.0001, 1.0);

    // 2. Scale factor to expand combined bounding box to 100% (1.0) while preserving aspect ratio
    final double scale = min(1.0 / overallW, 1.0 / overallH);

    final double scaledW = overallW * scale;
    final double scaledH = overallH * scale;

    // Centering offsets
    final double offsetX = (1.0 - scaledW) / 2.0;
    final double offsetY = (1.0 - scaledH) / 2.0;

    // 3. Apply scale & centering shift, and align to pixel grid
    final List<PixelArtComponent> result = [];
    for (final item in items) {
      final rect = item.rect;

      final newLeft = offsetX + (rect.left - minL) * scale;
      final newTop = offsetY + (rect.top - minT) * scale;
      final newWidth = rect.width * scale;
      final newHeight = rect.height * scale;

      final scaledRect = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
      final alignedRect = _alignRectToPixels(scaledRect, gridSize);

      result.add(
        PixelArtComponent(
          name: item.name,
          description: item.description,
          relativeBoundingBox: alignedRect,
          shapes: item.shapes,
        ),
      );
    }

    return result;
  }

  Rect _alignRectToPixels(Rect rect, int gridSize) {
    return CoordinateConverter.alignRectToGrid(rect, gridSize);
  }

  List<PixelArtComponent> getDefaultComponents(AgentContext context) {
    final bool hasTemplate = context.currentGrid.any(
      (row) => row.any((cell) => cell > 0),
    );
    if (hasTemplate) {
      final templateGrid = List.generate(
        context.gridSize,
        (y) => List.generate(
          context.gridSize,
          (x) => context.currentGrid[y][x] > 0 ? 1 : 0,
        ),
      );
      return [
        PixelArtComponent(
          name: 'base_template',
          description: 'Base template body / silhouette',
          relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
          grid: templateGrid,
          isSculpted: true,
        ),
      ];
    }
    return [
      PixelArtComponent(
        name: 'main',
        description: context.userPrompt,
        relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
      ),
    ];
  }
}
