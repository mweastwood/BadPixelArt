import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AiCoreStatus { unavailable, downloadable, downloading, available }

abstract class AiService {
  Future<AiCoreStatus> checkStatus();
  Future<void> triggerDownload();
  Future<Map<String, dynamic>?> getNextStroke({
    required Uint8List? referenceImage,
    required Uint8List canvasImage,
    required String prompt,
    required List<String> paletteColors,
  });
}

class MethodChannelAiService implements AiService {
  static const _channel = MethodChannel('com.badpixelart/aicore');

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
    } catch (_) {
      return AiCoreStatus.unavailable;
    }
  }

  @override
  Future<void> triggerDownload() async {
    try {
      await _channel.invokeMethod<void>('triggerDownload');
    } catch (_) {
      // Ignored
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
      final resultString = await _channel
          .invokeMethod<String>('getNextStroke', {
            'referenceImage': referenceImage,
            'canvasImage': canvasImage,
            'prompt': prompt,
            'paletteColors': paletteColors,
          });

      if (resultString == null) return null;
      final parsed = jsonDecode(resultString);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (e) {
      debugPrint('Error getting next stroke: $e');
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
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _strokeCount++;

    // Generate simulated strokes in a circle/line sequence for demo purposes.
    final step = _strokeCount % 4;
    final colorIdx = paletteColors.length > 2 ? 2 : 1; // Pick red or non-black

    if (step == 0) {
      return {
        'tool': 'circle',
        'params': [32, 32, 10],
        'color': colorIdx,
      };
    } else if (step == 1) {
      return {
        'tool': 'line',
        'params': [10, 10, 54, 54],
        'color': colorIdx,
      };
    } else if (step == 2) {
      return {
        'tool': 'fill',
        'params': [32, 32],
        'color': colorIdx == 2 ? 3 : 0,
      };
    } else {
      return {
        'tool': 'hatch',
        'params': [16, 16],
        'color': colorIdx,
      };
    }
  }
}

final aiServiceProvider = Provider<AiService>((ref) {
  // Use platform channel only on Android and not in debug/mock environments
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return MethodChannelAiService();
  }
  return MockAiService();
});
