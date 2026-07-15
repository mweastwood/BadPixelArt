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
        temperature: 0.7, // High temperature to generate creative variations!
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
        final List<PixelArtComponent> components = [];
        for (final item in parsed) {
          if (item is Map<String, dynamic>) {
            final name = item['name'] as String? ?? 'component';
            final description = item['description'] as String? ?? '';
            final bbox =
                item['relativeBoundingBox'] as Map<String, dynamic>? ?? {};

            final left = (bbox['left'] as num? ?? 0.0).toDouble();
            final top = (bbox['top'] as num? ?? 0.0).toDouble();
            final width = (bbox['width'] as num? ?? 1.0).toDouble();
            final height = (bbox['height'] as num? ?? 1.0).toDouble();

            final alignedRect = _alignRectToPixels(
              Rect.fromLTWH(left, top, width, height),
              context.gridSize,
            );

            components.add(
              PixelArtComponent(
                name: name,
                description: description,
                relativeBoundingBox: alignedRect,
              ),
            );
          }
        }
        if (components.isNotEmpty) {
          return DecomposerResult(
            components: components,
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
