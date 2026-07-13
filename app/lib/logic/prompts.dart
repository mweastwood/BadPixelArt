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

  return 'You are an AI pixel art assistant co-creating an image with a user on a 16x16 grid (coordinates 0 to 15).\n'
      'Depending on the session, your visual input consists of the following panels side-by-side (from left to right):\n'
      '1. Reference (Quantized): A smoothed, color-quantized version of the reference containing only dominant blocks in your exact drawing palette.\n'
      '2. Current Canvas: The current state of the canvas.\n'
      'Use the Quantized panel to align block regions and choose palette color indices, and the Current panel to track your progress.\n'
      'Available tools:\n'
      '$tools\n\n'
      'Color selection and refinement:\n'
      '- Set the "color" field to one of the indices in the Available Color Palette to add color to the shape.\n'
      '- IMPORTANT: Use color index 0 as an eraser to clear/subtract pixels, allowing you to carve, sculpt, and refine the artwork\'s shape.\n\n'
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
    if (hasReferenceImage) {
      canvasGridString =
          'The attached image contains the quantized reference image (left panel) and current canvas state (right panel).';
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
  Future<String?> _generateContentWithRetry({
    required String prompt,
    required Uint8List imageBytes,
    bool lowTemperature = false,
    int maxRetries = 3,
  }) async {
    int delayMs = 1000;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await generateContent(
          prompt: prompt,
          imageBytes: imageBytes,
          lowTemperature: lowTemperature,
        );
        if (response != null) {
          return response;
        }
      } catch (_) {
        if (attempt == maxRetries) {
          rethrow;
        }
      }
      await Future.delayed(Duration(milliseconds: delayMs));
      delayMs *= 2;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getNextStroke({
    required Uint8List canvasImage,
    required String prompt,
  }) async {
    final String? response = await _generateContentWithRetry(
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
    final String? response = await _generateContentWithRetry(
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
    final String? response = await _generateContentWithRetry(
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

  Future<Map<String, dynamic>?> evaluateCandidates({
    required Uint8List canvasImage,
  }) async {
    final String criticPrompt = formatCriticComparisonPrompt();
    final String? response = await _generateContentWithRetry(
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
  return 'You are an AI pixel art critic evaluating the accuracy of a co-created image on a 16x16 grid.\n'
      'Your visual input consists of the following panels side-by-side (from left to right):\n'
      '1. Reference (Quantized): Smoothed, color-quantized reference.\n'
      '2. Current Canvas: The current state of the canvas with the latest stroke applied.\n\n'
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

String formatCriticComparisonPrompt() {
  return 'You are an AI pixel art critic evaluating candidate drawings produced by three different Painter agents.\n'
      'Your goal is to select the single best candidate drawing that most successfully progresses the artwork.\n\n'
      'The attached visual input contains a 2x2 grid of panels:\n'
      '- Top-Left: Reference Image (or the Starting Canvas before the 5-turn block started)\n'
      '- Top-Right: Candidate 1 (Painter Agent - Run 1)\n'
      '- Bottom-Left: Candidate 2 (Painter Agent - Run 2)\n'
      '- Bottom-Right: Candidate 3 (Painter Agent - Run 3)\n\n'
      'Analyze all three candidates and output a JSON block containing your choice (1, 2, or 3) and your detailed reasoning:\n'
      '{\n'
      '  "choice": 1,\n'
      '  "reasoning": "Brief explanation of why you selected this candidate"\n'
      '}\n'
      'IMPORTANT: Keep the "reasoning" value extremely concise (max 1 sentence/15 words) to prevent JSON truncation on device.\n'
      'Output only the JSON block. Do not write any markdown tags or explanations.';
}
