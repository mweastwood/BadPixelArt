import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'ai_service.dart';

AiService getWebAiService() {
  return WebAiService();
}

class WebAiService implements AiService {
  @override
  Future<AiCoreStatus> checkStatus() async {
    try {
      final chromeAi = js_util.getProperty(html.window, 'chromeAi');
      if (chromeAi == null) return AiCoreStatus.unavailable;

      final promise = js_util.callMethod(chromeAi, 'checkStatus', []);
      final String result = await js_util.promiseToFuture(promise);

      switch (result) {
        case 'readily':
          return AiCoreStatus.available;
        case 'after-download':
          return AiCoreStatus.downloadable;
        default:
          return AiCoreStatus.unavailable;
      }
    } catch (e) {
      debugPrint('Error checking Web AI status: $e');
      return AiCoreStatus.unavailable;
    }
  }

  @override
  Future<void> triggerDownload() async {
    try {
      final chromeAi = js_util.getProperty(html.window, 'chromeAi');
      if (chromeAi == null) return;

      final promise = js_util.callMethod(chromeAi, 'triggerDownload', []);
      await js_util.promiseToFuture(promise);
    } catch (e) {
      debugPrint('Error triggering download: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getNextStroke({
    required Uint8List? referenceImage,
    required Uint8List canvasImage,
    required String prompt,
    required List<String> paletteColors,
  }) async {
    try {
      final chromeAi = js_util.getProperty(html.window, 'chromeAi');
      if (chromeAi == null) return null;

      // 1. Parse current canvas layout
      String canvasGridString = utf8.decode(canvasImage);
      if (!canvasGridString.contains(RegExp(r'[1-9]'))) {
        canvasGridString = 'The grid is completely empty (all 0s).';
      }

      // 2. Decode reference image preset instructions
      String refShapeInstruction = '';
      if (referenceImage != null) {
        final refString = utf8.decode(referenceImage);
        if (refString.startsWith('Sword')) {
          refShapeInstruction = 'The user wants to draw a Sword.';
        } else if (refString.startsWith('Heart')) {
          refShapeInstruction = 'The user wants to draw a Heart.';
        }
      }

      // 3. Formulate the system instruction and user prompt for Gemini Nano.
      const systemInstruction =
          'You are an AI pixel art assistant co-creating an image with a user on a 64x64 grid (coordinates 0 to 63).\n'
          'Available tools:\n'
          '- "line": params [startX, startY, endX, endY]\n'
          '- "circle": params [centerX, centerY, radius]\n'
          '- "fill": params [startX, startY]\n'
          '- "hatch": params [startX, startY] (alternating checkerboard pattern fill)\n\n'
          'You must output EXACTLY a valid JSON block and nothing else. No explanation, no markdown tags. Example:\n'
          '{"tool": "line", "params": [10, 15, 20, 25], "color": 2}';

      final userTextPrompt =
          'User Instruction: "$prompt"\n'
          '$refShapeInstruction\n'
          'Color Palette Size: ${paletteColors.length} (Color indices are 0 to ${paletteColors.length - 1}).\n'
          'Current grid layout serialized: $canvasGridString\n\n'
          'Output the single next stroke JSON now:';

      final promise = js_util.callMethod(chromeAi, 'getNextStroke', [userTextPrompt, systemInstruction]);
      final String? response = await js_util.promiseToFuture(promise);

      if (response == null) return null;

      // Parse JSON from response
      String sanitized = response.trim();
      if (sanitized.startsWith('```')) {
        final lines = sanitized.split('\n');
        final filtered = lines.where((line) => !line.trim().startsWith('```')).join('\n');
        sanitized = filtered.trim();
      }

      final parsed = jsonDecode(sanitized);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (e) {
      debugPrint('Error getting next stroke from Web AI: $e');
    }
    return null;
  }
}
