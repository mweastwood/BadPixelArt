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

  return 'You are an AI pixel art painter agent co-creating an image with a user on a 16x16 grid (coordinates 0 to 15).\n'
      'Your visual input is a single 16x16 image of the current canvas. You do not see the reference image directly; instead, you receive a textual description of the target reference image in your user prompt.\n'
      'Use the target description and the current canvas to design a single strategic stroke that moves the drawing closer to completion.\n\n'
      'Available tools:\n'
      '$tools\n\n'
      'Color selection and refinement:\n'
      '- Set the "color" field to one of the indices in the Available Color Palette to paint with that color.\n'
      '- IMPORTANT: Use color index 0 as an eraser to clear/subtract pixels, allowing you to carve, sculpt, shape, and refine outlines.\n\n'
      'Output rules:\n'
      '- You must output EXACTLY a valid JSON block containing: "understanding", "reasoning", "tool", "params", and "color".\n'
      '- Do not write markdown blocks (e.g. ```json) or explanations outside the JSON.\n'
      '- Keep the "understanding" and "reasoning" values extremely concise (max 1 sentence/15 words each) to prevent JSON truncation.\n'
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
  return 'Analyze this reference image and suggest a palette of exactly 8 colors. '
      'Output a JSON array containing exactly 8 hex color strings (e.g. ["#ff0000", "#00ff00", ...]). '
      'Output nothing else.';
}

String formatUserPrompt({
  required Uint8List canvasImage,
  required String prompt,
  required List<String> paletteColors,
  bool isMultimodal = false,
  bool hasPreviousImage = false,
  String? referenceDescription,
  String? currentCanvasTextGrid,
  String? loopHistory,
  String? nextFocus,
}) {
  String canvasGridString;
  if (isMultimodal) {
    canvasGridString = 'The current canvas is provided as an image attachment.';
  } else {
    String decodedGrid = '';
    if (currentCanvasTextGrid != null) {
      decodedGrid = currentCanvasTextGrid;
    } else {
      try {
        decodedGrid = utf8.decode(canvasImage);
      } catch (_) {
        decodedGrid = 'The grid state could not be decoded.';
      }
    }
    if (!decodedGrid.contains(RegExp(r'[1-9]'))) {
      decodedGrid = 'The grid is completely empty (all 0s).';
    }
    canvasGridString = 'Current grid layout serialized: $decodedGrid';
  }

  String refShapeInstruction = '';
  if (referenceDescription != null && referenceDescription.isNotEmpty) {
    refShapeInstruction =
        'DESCRIPTION OF THE TARGET REFERENCE IMAGE:\n$referenceDescription\n'
        'Use this description to guide your drawings.';
  }

  String nextFocusInstruction = '';
  if (nextFocus != null && nextFocus.isNotEmpty) {
    nextFocusInstruction =
        'CRITIC\'S FOCUS/FEEDBACK FROM THE PREVIOUS ROUND:\n"$nextFocus"\n'
        'Pay close attention to this feedback and prioritize implementing or correcting it in your next strokes.';
  }

  final List<String> colorsMap = [
    '- Index 0: Eraser / Transparent Background (clears pixels)',
  ];
  for (int i = 0; i < paletteColors.length; i++) {
    colorsMap.add('- Index ${i + 1}: ${paletteColors[i]}');
  }
  final colorList = colorsMap.join('\n');

  final textGridSection = StringBuffer();
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
      '${nextFocusInstruction.isNotEmpty ? "$nextFocusInstruction\n" : ""}'
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

  final firstCurly = cleaned.indexOf('{');
  final firstBracket = cleaned.indexOf('[');
  int startIdx = -1;
  int endIdx = -1;

  if (firstCurly != -1 && (firstBracket == -1 || firstCurly < firstBracket)) {
    startIdx = firstCurly;
    endIdx = cleaned.lastIndexOf('}');
  } else if (firstBracket != -1) {
    startIdx = firstBracket;
    endIdx = cleaned.lastIndexOf(']');
  }

  if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
    cleaned = cleaned.substring(startIdx, endIdx + 1);
  }

  return cleaned.trim();
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

  if (colors.length > 8) {
    return colors.take(8).toList();
  }
  while (colors.length < 8) {
    final idx = colors.length;
    colors.add(_fallbackColors[idx % _fallbackColors.length]);
  }
  return colors;
}

extension PixelArtAiServiceExtension on AiService {
  Future<String?> _generateContentWithRetry({
    required String prompt,
    required Uint8List? imageBytes,
    required double temperature,
    int maxRetries = 3,
  }) async {
    int delayMs = 1000;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await generateContentWithContinuation(
          prompt: prompt,
          imageBytes: imageBytes,
          temperature: temperature,
          autoContinueLimit: 1,
        );
        if (response != null) {
          // If the response contains an error block from the MethodChannel/plugin,
          // throw an exception so that we retry!
          if (response.contains('"error":') &&
              response.contains('{') &&
              response.contains('}')) {
            throw Exception(response);
          }
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

  Future<Map<String, String>?> describeCanvas({
    required Uint8List canvasImage,
  }) async {
    final String describerPrompt =
        '${formatDescriberSystemInstruction()}\n\n${formatDescriberUserPrompt()}';
    try {
      final String? response = await _generateContentWithRetry(
        prompt: describerPrompt,
        imageBytes: canvasImage,
        temperature: 0.1,
      );
      if (response == null) return null;
      return {'prompt': describerPrompt, 'response': response};
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getNextStroke({
    required Uint8List canvasImage,
    required String prompt,
    required double temperature,
  }) async {
    try {
      final String? response = await _generateContentWithRetry(
        prompt: prompt,
        imageBytes: canvasImage,
        temperature: temperature,
      );
      if (response == null) return null;
      final cleaned = cleanJsonString(response);
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) {
        if (parsed.containsKey('error')) {
          return {'error': parsed['error'], 'rawResponse': response};
        }
        return parsed;
      }
    } catch (e) {
      return {'error': e.toString(), 'rawResponse': 'N/A'};
    }
    return null;
  }

  Future<List<Color>?> suggestPalette(Uint8List referenceImage) async {
    try {
      final String? response = await _generateContentWithRetry(
        prompt: formatPalettePrompt(),
        imageBytes: referenceImage,
        temperature: 0.1,
      );
      if (response == null) return null;
      return parsePaletteColors(response);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> evaluateStroke({
    required Uint8List canvasImage,
  }) async {
    final String criticPrompt =
        '${formatCriticSystemInstruction()}\n\n${formatCriticUserPrompt()}';
    try {
      final String? response = await _generateContentWithRetry(
        prompt: criticPrompt,
        imageBytes: canvasImage,
        temperature: 0.1,
      );
      if (response == null) return null;
      final cleaned = cleanJsonString(response);
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) {
        if (parsed.containsKey('error')) {
          return {'error': parsed['error'], 'rawResponse': response};
        }
        return parsed;
      }
    } catch (e) {
      return {'error': e.toString(), 'rawResponse': 'N/A'};
    }
    return null;
  }

  Future<Map<String, dynamic>?> evaluateCandidates({
    required String userPrompt,
    required String referenceDescription,
    required String startingCanvasDescription,
    required String candidate1Description,
    required String candidate2Description,
    required String candidate3Description,
  }) async {
    final String criticPrompt = formatCriticTextOnlyPrompt(
      userPrompt: userPrompt,
      referenceDescription: referenceDescription,
      startingCanvasDescription: startingCanvasDescription,
      candidate1Description: candidate1Description,
      candidate2Description: candidate2Description,
      candidate3Description: candidate3Description,
    );
    try {
      final String? response = await _generateContentWithRetry(
        prompt: criticPrompt,
        imageBytes: null,
        temperature: 0.1,
      );
      if (response == null) return null;
      final cleaned = cleanJsonString(response);
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) {
        if (parsed.containsKey('error')) {
          return {'error': parsed['error'], 'rawResponse': response};
        }
        return parsed;
      }
    } catch (e) {
      return {'error': e.toString(), 'rawResponse': 'N/A'};
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

String formatDescriberSystemInstruction() {
  return 'You are an AI pixel art describer. Your task is to analyze a 16x16 pixel art canvas and write a descriptive summary of about 100 words.\n'
      'Your description must focus on:\n'
      '- Shapes & Layout: describe the outlines, geometric structures, contours, and overall grid placement.\n'
      '- Colors & Contrast: list the exact color palette index shades used and their distribution.\n'
      '- Details & Texture: identify fine-grained patterns, symmetrical lines, or distinct highlights.\n'
      '- Subject Identity: speculate on the identity of the image (e.g., what character, object, animal, icon, or subject is this thing depicting?).\n'
      'Keep the description structured, engaging, and around 100 words in length.';
}

String formatDescriberUserPrompt() {
  return 'Analyze the provided 16x16 pixel art image and write a structured description of about 100 words, focusing on its shapes, colors, fine details, and speculating on what it is depicting.';
}

String formatCriticTextOnlyPrompt({
  required String userPrompt,
  required String referenceDescription,
  required String startingCanvasDescription,
  required String candidate1Description,
  required String candidate2Description,
  required String candidate3Description,
}) {
  return 'You are an AI pixel art critic evaluating candidate drawings produced by three different Painter agents.\n'
      'Your goal is to select the single best candidate drawing that most successfully progresses the artwork from its starting state toward the target reference image.\n\n'
      'USER INSTRUCTION:\n"$userPrompt"\n\n'
      'TARGET REFERENCE IMAGE DESCRIPTION:\n$referenceDescription\n\n'
      'STARTING CANVAS DESCRIPTION:\n$startingCanvasDescription\n\n'
      'CANDIDATE 1 DESCRIPTION (Painter Run 1):\n$candidate1Description\n\n'
      'CANDIDATE 2 DESCRIPTION (Painter Run 2):\n$candidate2Description\n\n'
      'CANDIDATE 3 DESCRIPTION (Painter Run 3):\n$candidate3Description\n\n'
      'Output a JSON block containing your choice (1, 2, or 3), your detailed reasoning, and a specific "nextFocus" suggestion explaining what the next round of painters should focus on drawing or correcting next (e.g. "Add a black curved tail to the body", "Smooth out the outline of the head"):\n'
      '{\n'
      '  "choice": 1,\n'
      '  "reasoning": "Selected Candidate 1 for best shape accuracy.",\n'
      '  "nextFocus": "Refine the border of the circle with black pixels."\n'
      '}\n'
      'IMPORTANT: Keep both the "reasoning" and "nextFocus" values extremely concise (max 1 sentence/15 words each) to prevent JSON truncation on device.\n'
      'Output only the JSON block. Do not write any markdown tags or explanations.';
}
