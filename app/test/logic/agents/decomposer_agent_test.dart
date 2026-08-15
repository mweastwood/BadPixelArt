import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import 'package:bad_pixel_art/logic/agents/decomposer_agent.dart';
import '../../test_helper.dart';

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
      final agent = DecomposerAgent();
      final mockAi = TestMockAiService(
        responseToReturn: TestJsonFixtures.decomposerFlatResponse,
      );
      final result = await agent.decompose(mockAi, context);

      expect(result.components, hasLength(2));
      expect(
        result.rawResponse,
        equals(TestJsonFixtures.decomposerFlatResponse),
      );
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
        equals(const Rect.fromLTWH(0.4375, 0.0, 0.125, 0.75)),
      );

      expect(result.components[1].name, equals('hilt'));
    });

    test('decomposes prompt correctly with shapes JSON response', () async {
      final agent = DecomposerAgent();
      final mockAi = TestMockAiService(
        responseToReturn: TestJsonFixtures.decomposerShapesResponse,
      );
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
        final agent = DecomposerAgent();
        final mockAi = TestMockAiService(
          responseToReturn: TestJsonFixtures.decomposerOffCenterResponse,
        );
        final result = await agent.decompose(mockAi, context);

        expect(result.components, hasLength(1));

        // Rescaled to 100% full canvas: 0.0..1.0
        expect(
          result.components[0].relativeBoundingBox,
          equals(const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0)),
        );
      },
    );

    test(
      'scales and centers multiple boxes based on area-weighted center of mass',
      () async {
        final agent = DecomposerAgent();
        final mockAi = TestMockAiService(
          responseToReturn: TestJsonFixtures.decomposerMultiBoxResponse,
        );
        final result = await agent.decompose(mockAi, context);

        expect(result.components, hasLength(2));

        // Rescaled to 100% full canvas:
        expect(
          result.components[0].relativeBoundingBox,
          equals(const Rect.fromLTWH(0.0, 0.0, 0.375, 0.375)),
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
