import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'ai_service.dart';

AiService getWebAiService() {
  return WebAiService();
}

@JS('chromeAi')
external ChromeAi? get chromeAi;

@JS()
@staticInterop
class ChromeAi {}

extension ChromeAiExtension on ChromeAi {
  external JSPromise checkStatus();
  external JSPromise triggerDownload();
  external JSPromise getNextStroke(JSString prompt, JSString systemInstruction);
}

class WebAiService implements AiService {
  @override
  Future<AiCoreStatus> checkStatus() async {
    try {
      final ai = chromeAi;
      if (ai == null) {
        debugPrint(
          'Web AI checkStatus: window.chromeAi is null (check if script in index.html ran successfully)',
        );
        return AiCoreStatus.unavailable;
      }

      final jsStatus = await ai.checkStatus().toDart;
      final String result = (jsStatus as JSString).toDart;

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
      final ai = chromeAi;
      if (ai == null) return;

      await ai.triggerDownload().toDart;
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
      final ai = chromeAi;
      if (ai == null) return null;

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

      final jsResponse = await ai
          .getNextStroke(userTextPrompt.toJS, systemInstruction.toJS)
          .toDart;
      final String? response = (jsResponse as JSString?)?.toDart;

      if (response == null) return null;

      // Parse JSON from response
      String sanitized = response.trim();
      if (sanitized.startsWith('```')) {
        final lines = sanitized.split('\n');
        final filtered = lines
            .where((line) => !line.trim().startsWith('```'))
            .join('\n');
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
