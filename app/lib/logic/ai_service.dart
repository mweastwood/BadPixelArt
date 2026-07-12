import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_service_stub.dart' if (dart.library.html) 'ai_service_web.dart';

enum AiCoreStatus { unavailable, downloadable, downloading, available }

abstract class AiService {
  Future<AiCoreStatus> checkStatus();
  Future<void> triggerDownload();
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    bool lowTemperature = false,
  });
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
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    bool lowTemperature = false,
  }) async {
    try {
      String? resultString;
      dynamic lastError;
      StackTrace? lastStackTrace;
      final List<String> attemptErrors = [];

      final String method = lowTemperature ? 'suggestPalette' : 'getNextStroke';
      final String imageKey = lowTemperature ? 'referenceImage' : 'canvasImage';

      for (int attempt = 1; attempt <= 4; attempt++) {
        try {
          resultString = await _channel.invokeMethod<String>(method, {
            'prompt': prompt,
            imageKey: imageBytes,
          });
          break; // Success! Exit the retry loop.
        } catch (e, stack) {
          lastError = e;
          lastStackTrace = stack;
          attemptErrors.add('Attempt $attempt: $e');
          debugPrint(
            'Error generating content (attempt $attempt/4) via MethodChannel ($method): $e',
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
          return '{"error": "${lastError.toString().replaceAll('"', '\\"')}"}';
        }
        return null;
      }

      return resultString;
    } catch (e, stack) {
      debugPrint('Error generating content via MethodChannel: $e');
      debugPrint(stack.toString());
      return '{"error": "${e.toString().replaceAll('"', '\\"')}"}';
    }
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
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    bool lowTemperature = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (lowTemperature) {
      // Mock suggesting exactly 16 hex color strings
      final List<String> mockPalette = List.generate(16, (i) {
        final val = (i * 0x11).toRadixString(16).padLeft(2, '0');
        return '#$val$val$val';
      });
      return '["${mockPalette.join('", "')}"]';
    }

    _strokeCount++;

    // Generate simulated strokes in a circle/line sequence for demo purposes.
    final step = _strokeCount % 4;
    final colorIdx = 1; // Pick index 1 as a default color index

    if (step == 0) {
      return '{\n'
          '  "understanding": "The canvas is currently empty.",\n'
          '  "reasoning": "Creating a central circular shape to start the drawing.",\n'
          '  "tool": "circle",\n'
          '  "params": [32, 32, 10],\n'
          '  "color": $colorIdx\n'
          '}';
    } else if (step == 1) {
      return '{\n'
          '  "understanding": "I see a circle in the center of the grid.",\n'
          '  "reasoning": "Drawing a diagonal line crossing the canvas for structure.",\n'
          '  "tool": "line",\n'
          '  "params": [10, 10, 54, 54],\n'
          '  "color": $colorIdx\n'
          '}';
    } else if (step == 2) {
      return '{\n'
          '  "understanding": "I see a circle and a diagonal line.",\n'
          '  "reasoning": "Performing a flood fill at the center to add solid color.",\n'
          '  "tool": "fill",\n'
          '  "params": [32, 32],\n'
          '  "color": ${colorIdx == 2 ? 3 : 0}\n'
          '}';
    } else {
      return '{\n'
          '  "understanding": "I see a filled circle and a line.",\n'
          '  "reasoning": "Applying a checkerboard hatch pattern to create texture.",\n'
          '  "tool": "hatch",\n'
          '  "params": [16, 16],\n'
          '  "color": $colorIdx\n'
          '}';
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
