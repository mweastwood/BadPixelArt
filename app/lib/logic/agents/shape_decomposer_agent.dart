import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:local_agent/local_agent.dart';
import 'base_agent.dart';

class ShapeDecomposerAgent implements PixelArtAgent {
  @override
  String get name => 'ShapeDecomposer';

  @override
  List<String> get availableTools => [];

  @override
  String getSystemInstruction(AgentContext context) {
    return 'You are an AI pixel art shape decomposer agent. Your job is to analyze a drawing component (its name and description) and break it down into a list of fundamental geometric shapes (rectangle, circle, triangle) that compose it.\n'
        'For each geometric shape, you must identify:\n'
        '1. "type": One of "rectangle", "circle", "triangle".\n'
        '2. "description": A short description/color description of this shape (e.g. "metallic gray blade body", "brown handle grip").\n'
        '3. "relativeBoundingBox": A bounding box for this shape, using normalized coordinates relative to the component\'s bounding box (i.e. from 0.0 to 1.0 inside the component). Format as: { "left": double, "top": double, "width": double, "height": double }\n\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON array of objects. Do not wrap in markdown tags (e.g. ```json).\n'
        '- Keep descriptions short (max 10 words).\n'
        '- Limit the list to 2-4 shapes that logically construct the component.\n'
        'Example output:\n'
        '[\n'
        '  { "type": "rectangle", "description": "gray steel body", "relativeBoundingBox": { "left": 0.0, "top": 0.0, "width": 1.0, "height": 0.8 } },\n'
        '  { "type": "triangle", "description": "sharp tip at top", "relativeBoundingBox": { "left": 0.0, "top": 0.8, "width": 1.0, "height": 0.2 } }\n'
        ']';
  }

  @override
  String getFormattedUserPrompt(
    AgentContext context,
    List<PixelArtStepResult> history,
  ) {
    final comp = context.targetComponent!;
    return 'Decompose the component "${comp.name}" (Description: "${comp.description}") into its fundamental geometric shapes (rectangle, circle, triangle).';
  }

  Future<List<FundamentalShape>> decomposeComponent(
    AiService aiService,
    AgentContext context,
  ) async {
    final systemPrompt = getSystemInstruction(context);
    final userPrompt = getFormattedUserPrompt(context, []);
    final fullPrompt = '$systemPrompt\n\n$userPrompt';

    try {
      final response = await aiService.generateContentWithContinuation(
        prompt: fullPrompt,
        temperature: 0.5, // Low temp for more precise/deterministic geometry
        autoContinueLimit: 1,
      );

      if (response == null) return [];

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
        final List<FundamentalShape> parsedShapes = [];
        for (final item in parsed) {
          if (item is Map<String, dynamic>) {
            final type = item['type'] as String? ?? 'rectangle';
            final description = item['description'] as String? ?? '';
            final bbox =
                item['relativeBoundingBox'] as Map<String, dynamic>? ?? {};

            final left = (bbox['left'] as num? ?? 0.0).toDouble().clamp(
              0.0,
              1.0,
            );
            final top = (bbox['top'] as num? ?? 0.0).toDouble().clamp(0.0, 1.0);
            final width = (bbox['width'] as num? ?? 1.0).toDouble().clamp(
              0.01,
              1.0,
            );
            final height = (bbox['height'] as num? ?? 1.0).toDouble().clamp(
              0.01,
              1.0,
            );

            parsedShapes.add(
              FundamentalShape(
                type: type,
                description: description,
                relativeBoundingBox: Rect.fromLTWH(left, top, width, height),
              ),
            );
          }
        }
        return parsedShapes;
      }
    } catch (e) {
      debugPrint('Error decomposing component into shapes: $e');
    }

    return [];
  }
}
