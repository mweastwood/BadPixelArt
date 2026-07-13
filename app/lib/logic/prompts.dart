import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:local_agent/local_agent.dart';
import 'drawing_commands.dart';

String formatSystemInstruction() {
  final tools = DrawingCommandFactory.toolInstructions.entries
      .where((e) => e.key != 'undo')
      .map((e) => '- "${e.key}": ${e.value}')
      .join('\n');

  return 'You are an AI pixel art assistant co-creating an image with a user on a 64x64 grid (coordinates 0 to 63).\n'
      'Note: Each 64x64 canvas panel in your visual input is padded with a black border on the top and left to a size of 80x80 pixels. This border displays a coordinate ruler (tick marks and numbers: 0, 16, 32, 48, 63) to guide your drawing placement.\n'
      'Depending on the session, your visual input consists of the following panels side-by-side (from left to right):\n'
      '1. Reference (Original): The target image you want to match.\n'
      '2. Reference (Edges): A high-contrast black-and-white outline map of the reference boundaries.\n'
      '3. Reference (Quantized): A smoothed, color-quantized version of the reference containing only dominant blocks in your exact drawing palette.\n'
      '4. Previous Canvas (optional): The state of the canvas prior to the last action.\n'
      '5. Current Canvas: The current state of the canvas.\n'
      'Use the Edges panel to align outline shapes, the Quantized panel to align block regions and choose palette color indices, and the Current/Previous panels to track changes.\n'
      'Available tools:\n'
      '$tools\n\n'
      'Color selection:\n'
      '- Set the "color" field in your JSON output to one of the indices in the Available Color Palette.\n'
      '- IMPORTANT: Use index 0 to erase/clear pixels back to the transparent background.\n\n'
      'You must output EXACTLY a valid JSON block containing your understanding of the image, your reasoning for the next stroke, and the next stroke itself. No explanation, no markdown tags.\n'
      'IMPORTANT: Keep the "understanding" and "reasoning" values extremely concise (max 1 sentence/15 words each) to prevent truncating the JSON output.\n'
      'Example:\n'
      '{\n'
      '  "understanding": "Brief description of what you see on the canvas right now",\n'
      '  "reasoning": "Explanation of why you are suggesting this stroke",\n'
      '  "tool": "line",\n'
      '  "params": [10, 15, 20, 25],\n'
      '  "color": 2\n'
      '}';
}

String formatPalettePrompt() {
  return 'Analyze this reference image and suggest a palette of exactly 16 colors. '
      'Output a JSON array containing exactly 16 hex color strings (e.g. ["#ff0000", "#00ff00", ...]). '
      'Output nothing else.';
}

String formatUserPrompt({
  required Uint8List canvasImage,
  required String prompt,
  required List<String> paletteColors,
  bool isMultimodal = false,
  bool hasPreviousImage = false,
  bool hasReferenceImage = false,
  String? currentCanvasTextGrid,
  String? quantizedReferenceTextGrid,
  String? loopHistory,
}) {
  String canvasGridString;
  if (isMultimodal) {
    if (hasReferenceImage && hasPreviousImage) {
      canvasGridString =
          'The attached image contains the reference image (left panel), previous canvas state (middle panel), and current canvas state (right panel).';
    } else if (hasReferenceImage) {
      canvasGridString =
          'The attached image contains the reference image (left panel) and current canvas state (right panel).';
    } else if (hasPreviousImage) {
      canvasGridString =
          'The attached image contains the previous canvas state (left panel) and current canvas state (right panel).';
    } else {
      canvasGridString =
          'The current canvas is provided as an image attachment.';
    }
  } else {
    String decodedGrid = utf8.decode(canvasImage);
    if (!decodedGrid.contains(RegExp(r'[1-9]'))) {
      decodedGrid = 'The grid is completely empty (all 0s).';
    }
    canvasGridString = 'Current grid layout serialized: $decodedGrid';
  }

  String refShapeInstruction = '';
  if (hasReferenceImage) {
    refShapeInstruction =
        'Use the provided reference image (sent as an image attachment) to guide your drawings.';
  }

  final List<String> colorsMap = [
    '- Index 0: Eraser / Transparent Background (clears pixels)',
  ];
  for (int i = 0; i < paletteColors.length; i++) {
    colorsMap.add('- Index ${i + 1}: ${paletteColors[i]}');
  }
  final colorList = colorsMap.join('\n');

  final textGridSection = StringBuffer();
  if (quantizedReferenceTextGrid != null) {
    textGridSection.write(
      '\nTARGET REFERENCE LAYOUT (quantized to available palette colors):\n',
    );
    textGridSection.write(quantizedReferenceTextGrid);
  }
  if (currentCanvasTextGrid != null) {
    textGridSection.write(
      '\nCURRENT CANVAS STATE (each character represents a palette color index, . = empty):\n',
    );
    textGridSection.write(currentCanvasTextGrid);
  }
  if (loopHistory != null && loopHistory.isNotEmpty) {
    textGridSection.write('\nAGENT LOOP CONVERSATION HISTORY:\n');
    textGridSection.write(loopHistory);
  }

  return 'User Instruction: "$prompt"\n'
      '$refShapeInstruction\n'
      'Available Color Palette (select the correct index for the "color" field):\n'
      '$colorList\n'
      '$canvasGridString\n'
      '$textGridSection\n\n'
      'Output the single next stroke JSON now:';
}

String cleanJsonString(String input) {
  var cleaned = input.trim();
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
  return cleaned;
}

const List<Color> _fallbackColors = [
  Color(0xFF000000), // Black
  Color(0xFFFFFFFF), // White
  Color(0xFFFF0000), // Red
  Color(0xFF00FF00), // Green
  Color(0xFF0000FF), // Blue
  Color(0xFFFFFF00), // Yellow
  Color(0xFFFF00FF), // Magenta
  Color(0xFF00FFFF), // Cyan
];

List<Color> parsePaletteColors(String responseText) {
  final List<Color> colors = [];
  try {
    final cleaned = cleanJsonString(responseText);
    final decoded = jsonDecode(cleaned);
    if (decoded is List) {
      for (final item in decoded) {
        if (item is String) {
          final hex = item.trim().replaceFirst('#', '');
          final colorVal = int.tryParse(hex, radix: 16);
          if (colorVal != null) {
            if (hex.length == 6) {
              colors.add(Color(0xFF000000 | colorVal));
            } else if (hex.length == 8) {
              colors.add(Color(colorVal));
            }
          }
        }
      }
    }
  } catch (e) {
    debugPrint('Error parsing suggested palette: $e');
  }

  if (colors.isEmpty) {
    final hexRegex = RegExp(r'#([0-9a-fA-F]{6})');
    for (final match in hexRegex.allMatches(responseText)) {
      final hex = match.group(1)!;
      final colorVal = int.tryParse(hex, radix: 16);
      if (colorVal != null) {
        colors.add(Color(0xFF000000 | colorVal));
      }
    }
  }

  if (colors.length > 16) {
    return colors.take(16).toList();
  }
  while (colors.length < 16) {
    final idx = colors.length;
    colors.add(_fallbackColors[idx % _fallbackColors.length]);
  }
  return colors;
}

extension PixelArtAiServiceExtension on AiService {
  Future<Map<String, dynamic>?> getNextStroke({
    required Uint8List canvasImage,
    required String prompt,
  }) async {
    final String? response = await generateContent(
      prompt: prompt,
      imageBytes: canvasImage,
    );
    if (response == null) return null;
    final cleaned = cleanJsonString(response);
    try {
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (e) {
      return {'error': e.toString(), 'rawResponse': response};
    }
    return null;
  }

  Future<List<Color>?> suggestPalette(Uint8List referenceImage) async {
    final String? response = await generateContent(
      prompt: formatPalettePrompt(),
      imageBytes: referenceImage,
      lowTemperature: true,
    );
    if (response == null) return null;
    return parsePaletteColors(response);
  }

  Future<Map<String, dynamic>?> evaluateStroke({
    required Uint8List canvasImage,
  }) async {
    final String criticPrompt =
        '${formatCriticSystemInstruction()}\n\n${formatCriticUserPrompt()}';
    final String? response = await generateContent(
      prompt: criticPrompt,
      imageBytes: canvasImage,
      lowTemperature: true,
    );
    if (response == null) return null;
    final cleaned = cleanJsonString(response);
    try {
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (e) {
      return {'error': e.toString(), 'rawResponse': response};
    }
    return null;
  }
}

String formatCriticSystemInstruction() {
  return 'You are an AI pixel art critic evaluating the accuracy of a co-created image on a 64x64 grid.\n'
      'Your visual input consists of the following panels side-by-side (from left to right):\n'
      '1. Reference (Original): The target image to match.\n'
      '2. Reference (Edges): Outline map of the reference.\n'
      '3. Reference (Quantized): Smoothed, color-quantized reference.\n'
      '4. Previous Canvas: The state of the canvas before the latest stroke.\n'
      '5. Current Canvas: The current state of the canvas with the latest stroke applied.\n\n'
      'Analyze the latest stroke shown in the Current Canvas. Does it improve the overall accuracy, structure, or coloring of the drawing to match the reference? Or is it a mistake, misplaced, disconnected, or of the wrong scale?\n'
      'You must output EXACTLY a valid JSON block containing your reasoning and your action decision ("keep" or "undo").\n'
      'IMPORTANT: Keep the "reasoning" value extremely concise (max 1 sentence/15 words) to prevent JSON truncation on device.\n'
      'Example:\n'
      '{\n'
      '  "reasoning": "The circle is placed in the correct location and matches the bulbous base shape.",\n'
      '  "action": "keep"\n'
      '}';
}

String formatCriticUserPrompt() {
  return 'Evaluate the latest stroke applied to the Current Canvas.\n'
      'Determine if the stroke aligns with the target reference image.\n'
      'Output a JSON block with "reasoning" and "action" ("keep" or "undo").';
}
