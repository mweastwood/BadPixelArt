import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import '../models/pixel_art_component.dart';
import '../utils/json_utils.dart';

class AiLayerOrderingResult {
  final String reasoning;
  final List<PixelArtComponent> reorderedComponents;

  AiLayerOrderingResult({
    required this.reasoning,
    required this.reorderedComponents,
  });
}

class LayerOrderingAgent {
  final AiService _aiService;

  LayerOrderingAgent(this._aiService);

  Future<AiLayerOrderingResult?> suggestLayerOrder({
    required String userPrompt,
    required List<PixelArtComponent> components,
    dynamic imageBytes,
  }) async {
    if (components.isEmpty) return null;
    if (components.length == 1) {
      return AiLayerOrderingResult(
        reasoning: 'Only one layer present.',
        reorderedComponents: List.from(components),
      );
    }

    final componentSummaries = components.map((comp) {
      String? colorToHex(Color? c) {
        if (c == null) return null;
        final rgb = c.toARGB32() & 0x00FFFFFF;
        return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
      }

      return {
        'name': comp.name,
        'description': comp.description,
        'hasInterior': comp.hasInterior,
        'fillColor': colorToHex(comp.fillColor),
        'fillColor2': colorToHex(comp.fillColor2),
        'outlineColor': colorToHex(comp.outlineColor),
      };
    }).toList();

    const systemInstruction = '''
You are an expert retro pixel artist and compositing director.
Your task is to determine the optimal layer drawing order (z-index) for the components of a pixel art piece.

Rendering Order Rules:
- In our 2D canvas, layers are drawn sequentially from index 0 to index N-1:
  - First layer (Index 0 / Bottom): Drawn first as the background or base structural container.
  - Intermediate layers: Drawn over the base container (e.g. liquids, fillings, clothing).
  - Last layer (Index N-1 / Top): Drawn last on the very top (foreground details, plugs/stoppers, floating bubbles, gems, specular highlights).

Ordering Guidelines:
1. Base & Containers: Structural frames and containers (e.g. "flask_body", "shield_base", "blade") should be placed early in the list.
2. Inner Contents: Elements filling or resting inside containers (e.g. "red_elixir", "potion_liquid") should be drawn after the base container.
3. Foreground Overlays & Details: Components that sit in front, plug into openings, float inside, or highlight other objects (e.g. "cork_stopper", "bubbles", "glint", "emblem") MUST be placed near or at the end of the list so they are not overwritten.

Output Rules:
- Return ONLY a valid JSON object. Do not wrap in markdown code blocks.
- Format:
{
  "reasoning": "Brief 1-2 sentence explanation of the depth and layering choices.",
  "orderedComponentNames": [
    "bottom_component_name",
    "middle_component_name",
    "top_component_name"
  ]
}
''';

    final prompt =
        '''
Drawing Prompt: "$userPrompt"
Current Components (in arbitrary order):
${jsonEncode(componentSummaries)}

Please determine the best bottom-to-top layer drawing order for these components.
''';

    final fullPrompt = '$systemInstruction\n\n$prompt';

    try {
      final response = await _aiService.generateContentWithContinuation(
        prompt: fullPrompt,
        imageBytes: imageBytes,
        temperature: 0.2,
        autoContinueLimit: 1,
      );

      if (response == null || response.trim().isEmpty) return null;

      final cleanedJson = cleanJsonString(response);
      final decoded = jsonDecode(cleanedJson);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
          'Invalid JSON map response from LayerOrderingAgent',
        );
      }
      if (decoded.containsKey('error')) {
        throw FormatException('Layer ordering error: ${decoded['error']}');
      }

      final reasoning =
          decoded['reasoning'] as String? ??
          'Reordered layers from bottom to top.';
      final orderedNamesRaw = decoded['orderedComponentNames'] as List? ?? [];

      final orderedNames = orderedNamesRaw
          .whereType<String>()
          .map((s) => s.trim().toLowerCase())
          .toList();

      final compMap = <String, PixelArtComponent>{};
      for (final comp in components) {
        compMap[comp.name.trim().toLowerCase()] = comp;
      }

      final reordered = <PixelArtComponent>[];
      final seenNames = <String>{};

      for (final name in orderedNames) {
        final comp = compMap[name];
        if (comp != null && !seenNames.contains(name)) {
          reordered.add(comp);
          seenNames.add(name);
        }
      }

      // Add any omitted components in their original order so nothing is lost
      for (final comp in components) {
        final lower = comp.name.trim().toLowerCase();
        if (!seenNames.contains(lower)) {
          reordered.add(comp);
          seenNames.add(lower);
        }
      }

      return AiLayerOrderingResult(
        reasoning: reasoning,
        reorderedComponents: reordered,
      );
    } catch (e) {
      debugPrint('Error in LayerOrderingAgent: $e');
      return null;
    }
  }
}
