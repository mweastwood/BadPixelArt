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
    Uint8List? canvasBmpBytes,
    Uint8List? previousBmpBytes,
  }) async {
    try {
      final ai = chromeAi;
      if (ai == null) return null;

      final systemInstruction = formatSystemInstruction();
      final userTextPrompt = formatUserPrompt(
        referenceImage: referenceImage,
        canvasImage: canvasImage,
        prompt: prompt,
        paletteColors: paletteColors,
        isMultimodal: canvasBmpBytes != null,
        hasPreviousImage: previousBmpBytes != null,
      );

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
