import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/orchestrators/decomposition_orchestrator.dart';
import 'package:bad_pixel_art/logic/models/color_palette.dart';
import '../../test_helper.dart';

void main() {
  group('DecompositionOrchestrator Unit Tests', () {
    late DecompositionOrchestrator orchestrator;
    late TestMockAiService mockAiService;

    setUp(() {
      mockAiService = TestMockAiService(
        response: '''[
        {
          "name": "Head",
          "description": "Robot head",
          "boundingBox": [2, 2, 10, 10],
          "shapes": []
        }
      ]''',
      );
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
