import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../models/pixel_art_component.dart';
import '../utils/json_utils.dart';

class AiColorSelectionResult {
  final String reasoning;
  final List<PixelArtComponent> updatedComponents;

  AiColorSelectionResult({
    required this.reasoning,
    required this.updatedComponents,
  });
}

class ColorSelectionAgent {
  final AiService _aiService;

  ColorSelectionAgent(this._aiService);

  Future<AiColorSelectionResult?> suggestColors({
    required String userPrompt,
    required List<PixelArtComponent> components,
    required List<Color> palette,
    dynamic imageBytes,
  }) async {
    if (components.isEmpty || palette.isEmpty) return null;

    final paletteHexList = palette.map((c) {
      final argb = c.toARGB32();
      final rgb = argb & 0x00FFFFFF;
      return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }).toList();

    final componentSummaries = components.map((comp) {
      return {
        'name': comp.name,
        'description': comp.description,
        'hasInterior': comp.hasInterior,
      };
    }).toList();

    final systemInstruction =
        '''
You are an expert retro pixel artist colorist.
Select colors for each component from the provided color palette: $paletteHexList.

Rules for color assignment:
1. If "hasInterior" is false, the component is a thin line/outline without interior volume. You MUST only pick ONE color (either outlineColorHex or fillColorHex, set fillColor2Hex to null).
2. If "hasInterior" is true, you can pick a primary fillColorHex and optionally a secondary fillColor2Hex to create a 2-color pixel-art hatched gradient (shading/highlighting). Set gradientAngle to 0, 45, 90, 135, 180, 225, 270, or 315 degrees.
3. Every color selected MUST match an exact hex code from the palette: $paletteHexList.
4. Include a concise, 1-2 sentence reasoning summary explaining your color choices.

Return ONLY a single valid JSON object in this format:
{
  "reasoning": "Selected deep steel blues with a 90 degree downward highlight for the blade, and warm dark brown for the hilt.",
  "componentColors": [
    {
      "name": "blade",
      "fillColorHex": "#4A90E2",
      "fillColor2Hex": "#1F3A60",
      "gradientAngle": 90.0,
      "outlineColorHex": "#000000"
    }
  ]
}
''';

    final prompt =
        '''
User Prompt: "$userPrompt"
Palette: ${jsonEncode(paletteHexList)}
Components: ${jsonEncode(componentSummaries)}

Please select color assignments for each component.
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
          'Invalid JSON map response from ColorSelectionAgent',
        );
      }
      if (decoded.containsKey('error')) {
        throw FormatException('Color selection error: ${decoded['error']}');
      }

      final reasoning =
          decoded['reasoning'] as String? ??
          'Suggested colors based on active palette.';
      final colorAssignments = decoded['componentColors'] as List? ?? [];

      final assignmentMap = <String, Map<String, dynamic>>{};
      for (final item in colorAssignments) {
        if (item is Map<String, dynamic> && item['name'] != null) {
          assignmentMap[item['name'] as String] = item;
        }
      }

      Color? parseColorHex(String? hex) {
        if (hex == null || hex.trim().isEmpty) return null;
        final cleanHex = hex.trim().replaceAll('#', '');
        if (cleanHex.length != 6) return null;
        final val = int.tryParse('FF$cleanHex', radix: 16);
        if (val == null) return null;
        final targetColor = Color(val);
        // Find closest color in palette
        return palette.firstWhere(
          (c) => c.toARGB32() == targetColor.toARGB32(),
          orElse: () => palette.first,
        );
      }

      final updatedComponents = components.map((comp) {
        final assign = assignmentMap[comp.name];
        if (assign == null) return comp;

        final fillHex = assign['fillColorHex'] as String?;
        final fill2Hex = assign['fillColor2Hex'] as String?;
        final angle = (assign['gradientAngle'] as num?)?.toDouble() ?? 90.0;
        final outlineHex = assign['outlineColorHex'] as String?;

        final fillColor = parseColorHex(fillHex);
        final fillColor2 = comp.hasInterior ? parseColorHex(fill2Hex) : null;
        final outlineColor = parseColorHex(outlineHex);

        return comp.copyWith(
          fillColor: fillColor == null ? () => null : () => fillColor,
          fillColor2: fillColor2 == null ? () => null : () => fillColor2,
          gradientAngle: angle,
          outlineColor: outlineColor == null ? () => null : () => outlineColor,
        );
      }).toList();

      return AiColorSelectionResult(
        reasoning: reasoning,
        updatedComponents: updatedComponents,
      );
    } catch (e) {
      debugPrint('Error in ColorSelectionAgent: $e');
      return null;
    }
  }
}
