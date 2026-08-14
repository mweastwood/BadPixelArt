import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/orchestrators/decomposition_orchestrator.dart';
import 'package:bad_pixel_art/logic/models/color_palette.dart';

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
      {
        "name": "Head",
        "description": "Robot head",
        "boundingBox": [2, 2, 10, 10],
        "shapes": []
      }
    ]''';
  }
}

void main() {
  group('DecompositionOrchestrator Unit Tests', () {
    late DecompositionOrchestrator orchestrator;
    late MockTestAiService mockAiService;

    setUp(() {
      mockAiService = MockTestAiService();
      orchestrator = DecompositionOrchestrator(mockAiService);
    });

    test('decompose returns parsed DecomposerResult components', () async {
      final result = await orchestrator.decompose(
        gridSize: 16,
        activePalette: PaletteRegistry.primaryPalette,
        userPrompt: 'A simple robot',
        currentGrid: List.generate(16, (_) => List.filled(16, 0)),
        referenceImage: null,
      );

      expect(result.components, isNotEmpty);
      expect(result.components.first.name, equals('Head'));
    });
  });
}
