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
    required Uint8List canvasImage,
    required String prompt,
  });
  Future<List<Color>?> suggestPalette(Uint8List referenceImage);
}

String formatSystemInstruction() {
  return 'You are an AI pixel art assistant co-creating an image with a user on a 64x64 grid (coordinates 0 to 63).\n'
      'Note: Each 64x64 canvas panel in your visual input is padded with a black border on the top and left to a size of 80x80 pixels. This border displays a coordinate ruler (tick marks and numbers: 0, 16, 32, 48, 63) to guide your drawing placement.\n'
      'Available tools:\n'
      '- "line": params [startX, startY, endX, endY]\n'
      '- "circle": params [centerX, centerY, radius] (outlined circle)\n'
      '- "circle_filled": params [centerX, centerY, radius]\n'
      '- "circle_hatched": params [centerX, centerY, radius] (alternating checkerboard pattern filled circle)\n'
      '- "rectangle": params [startX, startY, endX, endY] (outlined rectangle)\n'
      '- "rectangle_filled": params [startX, startY, endX, endY]\n'
      '- "rectangle_hatched": params [startX, startY, endX, endY] (alternating checkerboard pattern filled rectangle)\n'
      '- "fill": params [startX, startY]\n'
      '- "hatch": params [startX, startY] (alternating checkerboard pattern flood fill)\n'
      '- "undo": params [] (reverts the last AI or user action if the AI thinks the last stroke was a mistake)\n\n'
      'You must output EXACTLY a valid JSON block containing your understanding of the image, your reasoning for the next stroke, and the next stroke itself. No explanation, no markdown tags. Example:\n'
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
    required Uint8List canvasImage,
    required String prompt,
  }) async {
    try {
      String? resultString;
      dynamic lastError;
      StackTrace? lastStackTrace;
      final List<String> attemptErrors = [];

      for (int attempt = 1; attempt <= 4; attempt++) {
        try {
          resultString = await _channel.invokeMethod<String>('getNextStroke', {
            'prompt': prompt,
            'canvasImage': canvasImage,
          });
          break; // Success! Exit the retry loop.
        } catch (e, stack) {
          lastError = e;
          lastStackTrace = stack;
          attemptErrors.add('Attempt $attempt: $e');
          debugPrint(
            'Error getting next stroke (attempt $attempt/4) via MethodChannel: $e',
          );
          if (attempt < 4) {
            final backoffMs = attempt * 500; // 500ms, 1000ms, 1500ms
            await Future.delayed(Duration(milliseconds: backoffMs));
          }
        }
      }

      if (resultString == null) {
        if (lastError != null) {
          debugPrint(lastStackTrace.toString());
          return {
            'error': lastError.toString(),
            'rawResponse':
                'MethodChannel invocation error:\n${attemptErrors.join('\n')}',
          };
        }
        return null;
      }

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
        'rawResponse': 'MethodChannel invocation error: $e',
      };
    }
    return null;
  }

  @override
  Future<List<Color>?> suggestPalette(Uint8List referenceImage) async {
    try {
      final String? resultString = await _channel.invokeMethod<String>(
        'suggestPalette',
        {'referenceImage': referenceImage, 'prompt': formatPalettePrompt()},
      );
      if (resultString == null) return null;
      return parsePaletteColors(resultString);
    } catch (e, stack) {
      debugPrint('Error invoking suggestPalette via MethodChannel: $e');
      debugPrint(stack.toString());
      return null;
    }
  }
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

class MockAiService implements AiService {
  AiCoreStatus _status = AiCoreStatus.available;
  int _strokeCount = 0;

  @override
  Future<List<Color>?> suggestPalette(Uint8List referenceImage) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.generate(16, (i) => Color(0xFF000000 | (i * 0x111111)));
  }

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
    required Uint8List canvasImage,
    required String prompt,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    _strokeCount++;

    // Generate simulated strokes in a circle/line sequence for demo purposes.
    final step = _strokeCount % 4;
    final colorIdx = 1; // Pick index 1 as a default color index

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
