import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_service_stub.dart' if (dart.library.html) 'ai_service_web.dart';

enum AiCoreStatus { unavailable, downloadable, downloading, available }

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

String formatSystemInstruction() {
  return 'You are an AI pixel art assistant co-creating an image with a user on a 64x64 grid (coordinates 0 to 63).\n'
      'Available tools:\n'
      '- "line": params [startX, startY, endX, endY]\n'
      '- "circle": params [centerX, centerY, radius]\n'
      '- "fill": params [startX, startY]\n'
      '- "hatch": params [startX, startY] (alternating checkerboard pattern fill)\n\n'
      'You must output EXACTLY a valid JSON block containing your current understanding of the image, your reasoning for the next stroke, and the next stroke itself. No explanation, no markdown tags. Example:\n'
      '{\n'
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

  return 'User Instruction: "$prompt"\n'
      '$refShapeInstruction\n'
      'Color Palette Size: ${paletteColors.length} (Color indices are 0 to ${paletteColors.length - 1}).\n'
      '$canvasGridString\n\n'
      'Output the single next stroke JSON now:';
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
      final parsed = jsonDecode(resultString);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (e, stack) {
      debugPrint('Error getting next stroke via MethodChannel: $e');
      debugPrint(stack.toString());
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
    _strokeCount++;

    // Generate simulated strokes in a circle/line sequence for demo purposes.
    final step = _strokeCount % 4;
    final colorIdx = paletteColors.length > 2 ? 2 : 1; // Pick red or non-black

    if (step == 0) {
      return {
        'understanding': 'The canvas is currently empty.',
        'reasoning': 'Creating a central circular shape to start the drawing.',
        'tool': 'circle',
        'params': [32, 32, 10],
        'color': colorIdx,
      };
    } else if (step == 1) {
      return {
        'understanding': 'I see a circle in the center of the grid.',
        'reasoning':
            'Drawing a diagonal line crossing the canvas for structure.',
        'tool': 'line',
        'params': [10, 10, 54, 54],
        'color': colorIdx,
      };
    } else if (step == 2) {
      return {
        'understanding': 'I see a circle and a diagonal line.',
        'reasoning':
            'Performing a flood fill at the center to add solid color.',
        'tool': 'fill',
        'params': [32, 32],
        'color': colorIdx == 2 ? 3 : 0,
      };
    } else {
      return {
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
