import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/orchestrators/refinement_orchestrator.dart';

class RefinementMockAiService extends AiService {
  int callCount = 0;

  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double? temperature,
    int? maxOutputTokens,
  }) async {
    callCount++;
    if (callCount == 1) {
      return '{"thought": "add gold highlight", "tool": "pixel", "params": [1, 1], "colorIndex": 2}';
    }
    return null;
  }

  @override
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    return 10;
  }
}

void main() {
  group('RefinementOrchestrator Unit Tests', () {
    test('refine executes drawing commands and logs history', () async {
      final aiService = RefinementMockAiService();
      final orchestrator = RefinementOrchestrator(aiService);

      final grid = List.generate(8, (_) => List.filled(8, 0));
      final palette = [Colors.red, Colors.green, Colors.blue];
      final history = <AgentHistoryEntry>[];

      final result = await orchestrator.refine(
        initialGrid: grid,
        gridSize: 8,
        palette: palette,
        userPrompt: 'add highlights',
        autoRunSpeed: 0.01, // fast delay
        onStep: (updated) {},
        onLogHistory: (entry) => history.add(entry),
      );

      // Verify command drawn: pixel at (1, 1) with colorIndex 2
      expect(result[1][1], equals(2));
      expect(history, hasLength(1));
      expect(history.first.response, contains('add gold highlight'));
    });
  });
}
