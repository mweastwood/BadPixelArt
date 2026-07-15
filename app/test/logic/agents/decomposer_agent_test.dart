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

    test('decomposes prompt correctly on valid JSON response', () async {
      final mockJson = '''
      [
        {
          "name": "blade",
          "description": "sharp blue blade",
          "relativeBoundingBox": { "left": 0.45, "top": 0.1, "width": 0.1, "height": 0.6 },
          "colorIndex": 3
        },
        {
          "name": "guard",
          "description": "horizontal red guard",
          "relativeBoundingBox": { "left": 0.3, "top": 0.7, "width": 0.4, "height": 0.1 },
          "colorIndex": 1
        }
      ]
      ''';

      final agent = DecomposerAgent();
      final mockAi = TestMockAiService(responseToReturn: mockJson);
      final result = await agent.decompose(mockAi, context);

      expect(result, hasLength(2));
      expect(result[0].name, equals('blade'));
      expect(result[0].description, equals('sharp blue blade'));
      expect(
        result[0].relativeBoundingBox,
        equals(const Rect.fromLTWH(0.45, 0.1, 0.1, 0.6)),
      );
      expect(result[0].proposedBaseColor, equals(const Color(0xFF0000FF)));

      expect(result[1].name, equals('guard'));
      expect(result[1].description, equals('horizontal red guard'));
      expect(
        result[1].relativeBoundingBox,
        equals(const Rect.fromLTWH(0.3, 0.7, 0.4, 0.1)),
      );
      expect(result[1].proposedBaseColor, equals(const Color(0xFFFF0000)));
    });

    test(
      'falls back to default main component when response is null',
      () async {
        final agent = DecomposerAgent();
        final mockAi = TestMockAiService(responseToReturn: null);
        final result = await agent.decompose(mockAi, context);

        expect(result, hasLength(1));
        expect(result[0].name, equals('main'));
        expect(result[0].description, equals(context.userPrompt));
        expect(
          result[0].relativeBoundingBox,
          equals(const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0)),
        );
        expect(result[0].proposedBaseColor, equals(activePalette[1]));
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

        expect(result, hasLength(1));
        expect(result[0].name, equals('main'));
        expect(result[0].description, equals(context.userPrompt));
        expect(
          result[0].relativeBoundingBox,
          equals(const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0)),
        );
      },
    );
  });
}
