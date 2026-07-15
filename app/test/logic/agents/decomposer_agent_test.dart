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

    test('decomposes prompt correctly on valid 4-option JSON response', () async {
      final mockJson = '''
      {
        "option1": [
          {
            "name": "blade",
            "description": "sharp blue blade",
            "relativeBoundingBox": { "left": 0.45, "top": 0.1, "width": 0.1, "height": 0.6 }
          }
        ],
        "option2": [
          {
            "name": "hilt",
            "description": "wooden hilt",
            "relativeBoundingBox": { "left": 0.4375, "top": 0.7, "width": 0.125, "height": 0.2 }
          }
        ],
        "option3": [],
        "option4": []
      }
      ''';

      final agent = DecomposerAgent();
      final mockAi = TestMockAiService(responseToReturn: mockJson);
      final result = await agent.decompose(mockAi, context);

      expect(result, hasLength(4));

      // Option 1
      expect(result[0], hasLength(1));
      expect(result[0][0].name, equals('blade'));
      // Pixel alignment verification:
      // Left = 0.45 -> (0.45 * 16).round() = 7 -> 7/16 = 0.4375
      // Top = 0.1 -> (0.1 * 16).round() = 2 -> 2/16 = 0.125
      // Width = 0.1 -> Left+Width = 0.55 -> (0.55 * 16).round() = 9 -> Width = (9-7)/16 = 0.125
      // Height = 0.6 -> Top+Height = 0.7 -> (0.7 * 16).round() = 11 -> Height = (11-2)/16 = 0.5625
      expect(
        result[0][0].relativeBoundingBox,
        equals(const Rect.fromLTWH(0.4375, 0.125, 0.125, 0.5625)),
      );

      // Option 2
      expect(result[1], hasLength(1));
      expect(result[1][0].name, equals('hilt'));
    });

    test(
      'falls back to default main component when response is null',
      () async {
        final agent = DecomposerAgent();
        final mockAi = TestMockAiService(responseToReturn: null);
        final result = await agent.decompose(mockAi, context);

        expect(result, hasLength(4));
        expect(result[0], hasLength(1));
        expect(result[0][0].name, equals('main'));
        expect(result[0][0].description, equals(context.userPrompt));
        expect(
          result[0][0].relativeBoundingBox,
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

        expect(result, hasLength(4));
        expect(result[0], hasLength(1));
        expect(result[0][0].name, equals('main'));
        expect(result[0][0].description, equals(context.userPrompt));
        expect(
          result[0][0].relativeBoundingBox,
          equals(const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0)),
        );
      },
    );
  });
}
