import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_agent/local_agent.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import 'package:bad_pixel_art/logic/agents/decomposer_agent.dart';

class TestMockAiService extends AiService {
  final String? responseToReturn;

  TestMockAiService({this.responseToReturn});

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
    return responseToReturn;
  }

  @override
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    return 100;
  }
}

void main() {
  group('DecomposerAgent Unit Tests', () {
    final activePalette = [
      const Color(0xFF000000),
      const Color(0xFFFF0000),
      const Color(0xFF00FF00),
      const Color(0xFF0000FF),
    ];

    final context = AgentContext(
      gridSize: 16,
      activePalette: activePalette,
      userPrompt: 'sword with red guard',
      currentGrid: List.generate(16, (_) => List.filled(16, 0)),
    );

    test('decomposes prompt correctly on valid flat JSON response', () async {
      final mockJson = '''
      [
        {
          "name": "blade",
          "description": "sharp blue blade",
          "relativeBoundingBox": { "left": 0.45, "top": 0.1, "width": 0.1, "height": 0.6 }
        },
        {
          "name": "hilt",
          "description": "wooden hilt",
          "relativeBoundingBox": { "left": 0.4375, "top": 0.7, "width": 0.125, "height": 0.2 }
        }
      ]
      ''';

      final agent = DecomposerAgent();
      final mockAi = TestMockAiService(responseToReturn: mockJson);
      final result = await agent.decompose(mockAi, context);

      expect(result.components, hasLength(2));
      expect(result.rawResponse, equals(mockJson));
      expect(result.rawPrompt, contains('sword with red guard'));

      expect(result.components[0].name, equals('blade'));
      // Pixel alignment verification:
      // Left = 0.45 -> (0.45 * 16).round() = 7 -> 7/16 = 0.4375
      // Top = 0.1 -> (0.1 * 16).round() = 2 -> 2/16 = 0.125
      // Width = 0.1 -> Left+Width = 0.55 -> (0.55 * 16).round() = 9 -> Width = (9-7)/16 = 0.125
      // Height = 0.6 -> Top+Height = 0.7 -> (0.7 * 16).round() = 11 -> Height = (11-2)/16 = 0.5625
      // Scaled and centered:
      // Left = 0.4375, Top = 0.0625, Width = 0.125, Height = 0.625
      expect(
        result.components[0].relativeBoundingBox,
        equals(const Rect.fromLTWH(0.4375, 0.0625, 0.125, 0.625)),
      );

      expect(result.components[1].name, equals('hilt'));
    });

    test('decomposes prompt correctly with shapes JSON response', () async {
      final mockJson = '''
      [
        {
          "name": "blade",
          "description": "sharp blue blade",
          "relativeBoundingBox": { "left": 0.45, "top": 0.1, "width": 0.1, "height": 0.6 },
          "shapes": [
            {
              "type": "rectangle",
              "description": "blue blade body",
              "relativeBoundingBox": { "left": 0.0, "top": 0.0, "width": 1.0, "height": 0.8 }
            },
            {
              "type": "triangle",
              "description": "sharp tip",
              "relativeBoundingBox": { "left": 0.0, "top": 0.8, "width": 1.0, "height": 0.2 }
            }
          ]
        }
      ]
      ''';

      final agent = DecomposerAgent();
      final mockAi = TestMockAiService(responseToReturn: mockJson);
      final result = await agent.decompose(mockAi, context);

      expect(result.components, hasLength(1));
      final comp = result.components[0];
      expect(comp.name, equals('blade'));
      expect(comp.shapes, hasLength(2));
      expect(comp.shapes[0].type, equals('rectangle'));
      expect(comp.shapes[0].description, equals('blue blade body'));
      expect(
        comp.shapes[0].relativeBoundingBox,
        equals(const Rect.fromLTWH(0.0, 0.0, 1.0, 0.8)),
      );

      expect(comp.shapes[1].type, equals('triangle'));
      expect(comp.shapes[1].description, equals('sharp tip'));
      expect(
        comp.shapes[1].relativeBoundingBox,
        equals(const Rect.fromLTWH(0.0, 0.8, 1.0, 0.2)),
      );
    });

    test(
      'automatically scales and centers off-center bounding boxes',
      () async {
        final mockJson = '''
      [
        {
          "name": "offCenterBox",
          "description": "off-center box",
          "relativeBoundingBox": { "left": 0.1, "top": 0.1, "width": 0.1, "height": 0.1 }
        }
      ]
      ''';

        final agent = DecomposerAgent();
        final mockAi = TestMockAiService(responseToReturn: mockJson);
        final result = await agent.decompose(mockAi, context);

        expect(result.components, hasLength(1));

        // Expected math:
        // Single box: centroid = (0.15, 0.15), width = 0.1, height = 0.1
        // CoM = (0.15, 0.15)
        // sMax = 10.0 -> scale = 9.0 -> newWidth = 0.9
        // newLeft = 0.5 + 9.0 * (0.1 - 0.15) = 0.05
        // Snapped (gridSize = 16):
        // Left = (0.05 * 16).round()/16 = 1/16 = 0.0625
        // Width = ((0.95 * 16).round() - 1)/16 = 14/16 = 0.875
        expect(
          result.components[0].relativeBoundingBox,
          equals(const Rect.fromLTWH(0.0625, 0.0625, 0.875, 0.875)),
        );
      },
    );

    test(
      'scales and centers multiple boxes based on area-weighted center of mass',
      () async {
        final mockJson = '''
      [
        {
          "name": "large",
          "description": "large box",
          "relativeBoundingBox": { "left": 0.1, "top": 0.1, "width": 0.2, "height": 0.2 }
        },
        {
          "name": "small",
          "description": "small box",
          "relativeBoundingBox": { "left": 0.5, "top": 0.5, "width": 0.1, "height": 0.1 }
        }
      ]
      ''';

        final agent = DecomposerAgent();
        final mockAi = TestMockAiService(responseToReturn: mockJson);
        final result = await agent.decompose(mockAi, context);

        expect(result.components, hasLength(2));

        // Math verification:
        // totalArea = 0.04 + 0.01 = 0.05
        // CoM = (0.27, 0.27)
        // Limits on S: Box 2 Right limit: S <= 0.5 / (0.6 - 0.27) = 1.51515
        // scale = 1.363636
        // Box 1 new Left: 0.5 + 1.363636 * (0.1 - 0.27) = 0.26818
        // Box 1 new Width: 0.2 * 1.363636 = 0.272727
        // Snap Box 1 to gridSize = 16:
        // X1 = (0.26818 * 16).round() = 4 -> 0.25
        // X2 = (0.5409 * 16).round() = 9 -> 0.5625
        // Width = 0.3125
        expect(
          result.components[0].relativeBoundingBox,
          equals(const Rect.fromLTWH(0.25, 0.25, 0.3125, 0.3125)),
        );
      },
    );

    test(
      'falls back to default main component when response is null',
      () async {
        final agent = DecomposerAgent();
        final mockAi = TestMockAiService(responseToReturn: null);
        final result = await agent.decompose(mockAi, context);

        expect(result.components, hasLength(1));
        expect(result.components[0].name, equals('main'));
        expect(result.components[0].description, equals(context.userPrompt));
        expect(
          result.components[0].relativeBoundingBox,
          equals(const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0)),
        );
      },
    );

    test(
      'falls back to default main component on malformed JSON response',
      () async {
        final agent = DecomposerAgent();
        final mockAi = TestMockAiService(
          responseToReturn: 'not a json array { ]',
        );
        final result = await agent.decompose(mockAi, context);

        expect(result.components, hasLength(1));
        expect(result.components[0].name, equals('main'));
        expect(result.components[0].description, equals(context.userPrompt));
        expect(
          result.components[0].relativeBoundingBox,
          equals(const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0)),
        );
      },
    );
  });
}
