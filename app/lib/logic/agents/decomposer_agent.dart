import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:local_agent/local_agent.dart';
import 'base_agent.dart';

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
    return 'You are an AI pixel art decomposer agent. Your job is to analyze a drawing prompt and break it down into its constituent semantic components.\n'
        'For each component, you must identify:\n'
        '1. "name": The name of the component (e.g. "blade", "hilt", "guard").\n'
        '2. "description": A descriptive instruction of what to draw (e.g. "straight blade with a sharp tip").\n'
        '3. "relativeBoundingBox": A bounding box where this component should be drawn, using normalized coordinates from 0.0 to 1.0. Bounding boxes can overlap. Format as: { "left": double, "top": double, "width": double, "height": double }\n\n'
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
    return 'Decompose the drawing instruction: "${context.userPrompt}" into its sub-components with bounding boxes.';
  }

  Future<DecomposerResult> decompose(
    AiService aiService,
    AgentContext context,
  ) async {
    final systemPrompt = getSystemInstruction(context);
    final userPrompt = getFormattedUserPrompt(context, []);
    final fullPrompt = '$systemPrompt\n\n$userPrompt';
    String? response;

    try {
      response = await aiService.generateContent(
        prompt: fullPrompt,
        imageBytes: context.referenceImage,
        temperature: 0.7,
      );

      if (response == null) {
        return DecomposerResult(
          components: _getDefaultComponents(context),
          rawPrompt: fullPrompt,
          rawResponse: 'Null response from AI Service',
        );
      }

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
                final sHeight = (sBbox['height'] as num? ?? 1.0)
                    .toDouble()
                    .clamp(0.0, 1.0);
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
          final scaledComponents = _scaleAndCenter(
            parsedItems,
            context.gridSize,
          );
          return DecomposerResult(
            components: scaledComponents,
            rawPrompt: fullPrompt,
            rawResponse: response,
          );
        }
      }
    } catch (e) {
      debugPrint('Error decomposing prompt: $e');
    }

    return DecomposerResult(
      components: _getDefaultComponents(context),
      rawPrompt: fullPrompt,
      rawResponse: response ?? 'Error occurred during decomposition',
    );
  }

  List<PixelArtComponent> _scaleAndCenter(
    List<_RawParsedComponent> items,
    int gridSize,
  ) {
    // 1. Calculate Center of Mass (area-weighted)
    double totalArea = 0.0;
    double sumX = 0.0;
    double sumY = 0.0;

    for (final item in items) {
      final rect = item.rect;
      final area = rect.width * rect.height;
      totalArea += area;
      sumX += (rect.left + rect.width / 2) * area;
      sumY += (rect.top + rect.height / 2) * area;
    }

    double xCom, yCom;
    if (totalArea > 0.0001) {
      xCom = sumX / totalArea;
      yCom = sumY / totalArea;
    } else {
      // Fallback: geometric center of combined bounds
      double minL = 1.0, minT = 1.0, maxR = 0.0, maxB = 0.0;
      for (final item in items) {
        final rect = item.rect;
        if (rect.left < minL) minL = rect.left;
        if (rect.top < minT) minT = rect.top;
        if (rect.left + rect.width > maxR) maxR = rect.left + rect.width;
        if (rect.top + rect.height > maxB) maxB = rect.top + rect.height;
      }
      xCom = minL + (maxR - minL) / 2;
      yCom = minT + (maxB - minT) / 2;
    }

    // 2. Calculate Maximum Scale Factor sMax to keep all components in [0, 1]
    double sMax = 999.0;
    for (final item in items) {
      final rect = item.rect;

      final diffLeft = xCom - rect.left;
      if (diffLeft > 0.0001) {
        final sVal = 0.5 / diffLeft;
        if (sVal < sMax) sMax = sVal;
      }

      final diffRight = rect.left + rect.width - xCom;
      if (diffRight > 0.0001) {
        final sVal = 0.5 / diffRight;
        if (sVal < sMax) sMax = sVal;
      }

      final diffTop = yCom - rect.top;
      if (diffTop > 0.0001) {
        final sVal = 0.5 / diffTop;
        if (sVal < sMax) sMax = sVal;
      }

      final diffBottom = rect.top + rect.height - yCom;
      if (diffBottom > 0.0001) {
        final sVal = 0.5 / diffBottom;
        if (sVal < sMax) sMax = sVal;
      }
    }

    // Target fill: 90% of maximum possible scale for breathing room
    final double scale = sMax < 999.0 ? sMax * 0.9 : 1.0;

    // 3. Apply Scale & Shift, and Align to Pixels
    final List<PixelArtComponent> result = [];
    for (final item in items) {
      final rect = item.rect;

      final newWidth = rect.width * scale;
      final newHeight = rect.height * scale;
      final newLeft = 0.5 + scale * (rect.left - xCom);
      final newTop = 0.5 + scale * (rect.top - yCom);

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
    final x1 = (rect.left * gridSize).round().clamp(0, gridSize);
    final y1 = (rect.top * gridSize).round().clamp(0, gridSize);
    var x2 = ((rect.left + rect.width) * gridSize).round().clamp(0, gridSize);
    var y2 = ((rect.top + rect.height) * gridSize).round().clamp(0, gridSize);

    if (x2 <= x1) x2 = (x1 + 1).clamp(0, gridSize);
    if (y2 <= y1) y2 = (y1 + 1).clamp(0, gridSize);

    return Rect.fromLTWH(
      x1 / gridSize,
      y1 / gridSize,
      (x2 - x1) / gridSize,
      (y2 - y1) / gridSize,
    );
  }

  List<PixelArtComponent> _getDefaultComponents(AgentContext context) {
    return [
      PixelArtComponent(
        name: 'main',
        description: context.userPrompt,
        relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
      ),
    ];
  }
}
