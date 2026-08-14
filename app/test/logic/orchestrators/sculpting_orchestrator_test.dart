import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/orchestrators/sculpting_orchestrator.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';

class MockTestAiService extends AiService {
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
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async => 100;

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    return '''[
      {"tool": "apply_rectangle_filled", "params": [4, 4, 12, 12]}
    ]''';
  }
}

void main() {
  group('SculptingOrchestrator Unit Tests', () {
    late SculptingOrchestrator orchestrator;
    late MockTestAiService mockAiService;

    setUp(() {
      mockAiService = MockTestAiService();
      orchestrator = SculptingOrchestrator(mockAiService);
    });

    test('buildBackgroundGrid excludes specified index and places colors', () {
      final comp1Grid = List.generate(
        16,
        (y) => List.generate(16, (x) => y < 8 ? 1 : 0),
      );
      final comp2Grid = List.generate(
        16,
        (y) => List.generate(16, (x) => y >= 8 ? 1 : 0),
      );

      final comp1 = PixelArtComponent(
        name: 'Head',
        description: 'Head',
        relativeBoundingBox: const Rect.fromLTWH(0, 0, 16, 8),
        shapes: const [],
        grid: comp1Grid,
      );
      final comp2 = PixelArtComponent(
        name: 'Body',
        description: 'Body',
        relativeBoundingBox: const Rect.fromLTWH(0, 8, 16, 8),
        shapes: const [],
        grid: comp2Grid,
      );

      final bgGrid = orchestrator.buildBackgroundGrid(
        components: [comp1, comp2],
        excludeIndex: 0,
        gridSize: 16,
        paletteLength: 4,
      );

      expect(bgGrid[0][0], equals(0)); // comp1 is excluded
      expect(bgGrid[10][10], greaterThan(0)); // comp2 is included
    });
  });
}
