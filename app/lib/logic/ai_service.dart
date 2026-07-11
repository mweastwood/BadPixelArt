import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_service_stub.dart' if (dart.library.html) 'ai_service_web.dart';

enum AiCoreStatus { unavailable, downloadable, downloading, available }

enum AiDrawingPhase { broadShapes, outlining, detailing, complete }

abstract class AiService {
  Future<AiCoreStatus> checkStatus();
  Future<void> triggerDownload();
  Future<Map<String, dynamic>?> getNextStroke({
    required Uint8List? referenceImage,
    required Uint8List canvasImage,
    required String prompt,
    required List<String> paletteColors,
    Uint8List? canvasBmpBytes,
  });
}

String formatPhaseEvaluationPrompt({
  required AiDrawingPhase currentPhase,
  required String userPrompt,
}) {
  String transitionQuestion;
  switch (currentPhase) {
    case AiDrawingPhase.broadShapes:
      transitionQuestion =
          'We started in the BROAD_SHAPES phase (drawing large shapes/block structures). Are we ready to move to the OUTLINING phase (refining boundaries and connecting outlines)?';
      break;
    case AiDrawingPhase.outlining:
      transitionQuestion =
          'We are in the OUTLINING phase (refining outlines and layout). Are we ready to move to the DETAILING phase (fine details, shading, pixel highlights, textures)?';
      break;
    case AiDrawingPhase.detailing:
      transitionQuestion =
          'We are in the DETAILING phase (fine details, highlights). Is the artwork COMPLETE according to the user instruction?';
      break;
    case AiDrawingPhase.complete:
      transitionQuestion = 'Is the artwork complete?';
      break;
  }

  return 'User Instruction: "$userPrompt"\n\n'
      'Evaluation Question: $transitionQuestion\n\n'
      'You must output EXACTLY a valid JSON block containing your evaluation. No markdown tags, no extra text. Example:\n'
      '{\n'
      '  "ready": true,\n'
      '  "reason": "Brief explanation of why we are ready or not"\n'
      '}';
}

String formatSystemInstruction() {
  return 'You are an AI pixel art assistant co-creating an image with a user on a 64x64 grid (coordinates 0 to 63).\n'
      'Drawing Phases:\n'
      '- "BROAD_SHAPES": Canvas is mostly empty/incomplete. Focus on block colors, primary shapes, and basic layout structures using "circle" or "line". No fine details.\n'
      '- "OUTLINING": Base shapes are established. Focus on outlines, connecting lines, and refinement of structural boundaries.\n'
      '- "DETAILING": Shapes and outlines are complete. Focus on adding fine details, highlights, shading, and texture (e.g., checkerboard hatch patterns or fill in small regions).\n\n'
      'Available tools:\n'
      '- "line": params [startX, startY, endX, endY]\n'
      '- "circle": params [centerX, centerY, radius]\n'
      '- "fill": params [startX, startY]\n'
      '- "hatch": params [startX, startY] (alternating checkerboard pattern fill)\n\n'
      'You must output EXACTLY a valid JSON block containing your selected phase (based on current image/progress), your understanding of the image, your reasoning for the next stroke, and the next stroke itself. No explanation, no markdown tags. Example:\n'
      '{\n'
      '  "phase": "OUTLINING",\n'
      '  "understanding": "Brief description of what you see on the canvas right now",\n'
      '  "reasoning": "Explanation of why you are suggesting this stroke",\n'
      '  "tool": "line",\n'
      '  "params": [10, 15, 20, 25],\n'
      '  "color": 2\n'
      '}';
}

String formatUserPrompt({
  required Uint8List? referenceImage,
  required Uint8List canvasImage,
  required String prompt,
  required List<String> paletteColors,
  bool isMultimodal = false,
}) {
  String canvasGridString;
  if (isMultimodal) {
    canvasGridString = 'The current canvas is provided as an image attachment.';
  } else {
    String decodedGrid = utf8.decode(canvasImage);
    if (!decodedGrid.contains(RegExp(r'[1-9]'))) {
      decodedGrid = 'The grid is completely empty (all 0s).';
    }
    canvasGridString = 'Current grid layout serialized: $decodedGrid';
  }

  String refShapeInstruction = '';
  if (referenceImage != null) {
    final refString = utf8.decode(referenceImage);
    if (refString.startsWith('Sword')) {
      refShapeInstruction = 'The user wants to draw a Sword.';
    } else if (refString.startsWith('Heart')) {
      refShapeInstruction = 'The user wants to draw a Heart.';
    }
  }

  final colorList = paletteColors
      .asMap()
      .entries
      .map((e) {
        final index = e.key;
        final hex = e.value;
        return '- Index $index: $hex';
      })
      .join('\n');

  return 'User Instruction: "$prompt"\n'
      '$refShapeInstruction\n'
      'Available Color Palette (select the correct index for the "color" field):\n'
      '$colorList\n'
      '$canvasGridString\n\n'
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

class MethodChannelAiService implements AiService {
  static const _channel = MethodChannel('com.mweastwood.bad_pixel_art/aicore');

  @override
  Future<AiCoreStatus> checkStatus() async {
    try {
      final String? result = await _channel.invokeMethod<String>('checkStatus');
      switch (result) {
        case 'available':
          return AiCoreStatus.available;
        case 'downloading':
          return AiCoreStatus.downloading;
        case 'downloadable':
          return AiCoreStatus.downloadable;
        default:
          return AiCoreStatus.unavailable;
      }
    } catch (e, stack) {
      debugPrint('Error invoking checkStatus via MethodChannel: $e');
      debugPrint(stack.toString());
      return AiCoreStatus.unavailable;
    }
  }

  @override
  Future<void> triggerDownload() async {
    try {
      await _channel.invokeMethod<void>('triggerDownload');
    } catch (e, stack) {
      debugPrint('Error invoking triggerDownload via MethodChannel: $e');
      debugPrint(stack.toString());
    }
  }

  @override
  Future<Map<String, dynamic>?> getNextStroke({
    required Uint8List? referenceImage,
    required Uint8List canvasImage,
    required String prompt,
    required List<String> paletteColors,
    Uint8List? canvasBmpBytes,
  }) async {
    try {
      final systemInstruction = formatSystemInstruction();
      final userTextPrompt = formatUserPrompt(
        referenceImage: referenceImage,
        canvasImage: canvasImage,
        prompt: prompt,
        paletteColors: paletteColors,
        isMultimodal: canvasBmpBytes != null,
      );
      final fullPrompt = '$systemInstruction\n\n$userTextPrompt';

      final resultString = await _channel
          .invokeMethod<String>('getNextStroke', {
            'prompt': fullPrompt,
            'canvasImage': canvasBmpBytes ?? canvasImage,
            'referenceImage': referenceImage,
          });

      if (resultString == null) return null;
      final cleanedString = cleanJsonString(resultString);
      try {
        final parsed = jsonDecode(cleanedString);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
      } catch (e) {
        return {'error': e.toString(), 'rawResponse': resultString};
      }
    } catch (e, stack) {
      debugPrint('Error getting next stroke via MethodChannel: $e');
      debugPrint(stack.toString());
      return {
        'error': e.toString(),
        'rawResponse': 'MethodChannel invocation error',
      };
    }
    return null;
  }
}

class MockAiService implements AiService {
  AiCoreStatus _status = AiCoreStatus.available;
  int _strokeCount = 0;

  @override
  Future<AiCoreStatus> checkStatus() async {
    return _status;
  }

  void setMockStatus(AiCoreStatus status) {
    _status = status;
  }

  @override
  Future<void> triggerDownload() async {
    if (_status == AiCoreStatus.downloadable) {
      _status = AiCoreStatus.downloading;
      Future.delayed(const Duration(seconds: 2), () {
        _status = AiCoreStatus.available;
      });
    }
  }

  @override
  Future<Map<String, dynamic>?> getNextStroke({
    required Uint8List? referenceImage,
    required Uint8List canvasImage,
    required String prompt,
    required List<String> paletteColors,
    Uint8List? canvasBmpBytes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (prompt.contains('Evaluation Question:')) {
      return {
        'ready': true,
        'reason':
            'The current phase is complete and we are ready to move to the next phase.',
      };
    }

    _strokeCount++;

    // Generate simulated strokes in a circle/line sequence for demo purposes.
    final step = _strokeCount % 4;
    final colorIdx = paletteColors.length > 2 ? 2 : 1; // Pick red or non-black

    if (step == 0) {
      return {
        'phase': 'BROAD_SHAPES',
        'understanding': 'The canvas is currently empty.',
        'reasoning': 'Creating a central circular shape to start the drawing.',
        'tool': 'circle',
        'params': [32, 32, 10],
        'color': colorIdx,
      };
    } else if (step == 1) {
      return {
        'phase': 'OUTLINING',
        'understanding': 'I see a circle in the center of the grid.',
        'reasoning':
            'Drawing a diagonal line crossing the canvas for structure.',
        'tool': 'line',
        'params': [10, 10, 54, 54],
        'color': colorIdx,
      };
    } else if (step == 2) {
      return {
        'phase': 'OUTLINING',
        'understanding': 'I see a circle and a diagonal line.',
        'reasoning':
            'Performing a flood fill at the center to add solid color.',
        'tool': 'fill',
        'params': [32, 32],
        'color': colorIdx == 2 ? 3 : 0,
      };
    } else {
      return {
        'phase': 'DETAILING',
        'understanding': 'I see a filled circle and a line.',
        'reasoning': 'Applying a checkerboard hatch pattern to create texture.',
        'tool': 'hatch',
        'params': [16, 16],
        'color': colorIdx,
      };
    }
  }
}

final aiServiceProvider = Provider<AiService>((ref) {
  if (kIsWeb) {
    return getWebAiService();
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    return MethodChannelAiService();
  }
  return MockAiService();
});
