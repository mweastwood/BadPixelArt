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

    test('throws FormatException when response is null', () async {
      final agent = DecomposerAgent();
      final mockAi = TestMockAiService(responseToReturn: null);
      expect(
        () => agent.decompose(mockAi, context),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on malformed JSON response', () async {
      final agent = DecomposerAgent();
      final mockAi = TestMockAiService(
        responseToReturn: 'not a json array { ]',
      );
      expect(
        () => agent.decompose(mockAi, context),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'retains base_template component when canvas has existing template grid',
      () async {
        final templateGrid = List.generate(16, (_) => List.filled(16, 0));
        // Put some template pixels in the center
        templateGrid[4][5] = 1;
        templateGrid[4][6] = 2;

        final templateContext = AgentContext(
          gridSize: 16,
          activePalette: activePalette,
          userPrompt: 'add golden armor and wings to character',
          currentGrid: templateGrid,
        );

        final agent = DecomposerAgent();
        expect(
          agent.getSystemInstruction(templateContext),
          contains('EXISTING BASE TEMPLATE PRESENT'),
        );
        expect(
          agent.getFormattedUserPrompt(templateContext, []),
          contains('A base template is already loaded on the canvas'),
        );

        final mockAi = TestMockAiService(
          responseToReturn: '''
[
  {
    "name": "wings",
    "description": "white feathered wings",
    "relativeBoundingBox": { "left": 0.0, "top": 0.1, "width": 1.0, "height": 0.5 }
  },
  {
    "name": "golden_armor",
    "description": "yellow breastplate armor",
    "relativeBoundingBox": { "left": 0.3, "top": 0.5, "width": 0.4, "height": 0.35 }
  }
]
''',
        );

        final result = await agent.decompose(mockAi, templateContext);

        // Should contain base_template at index 0 + 2 add-on components = 3 components
        expect(result.components, hasLength(3));
        expect(result.components[0].name, equals('base_template'));
        expect(result.components[0].isSculpted, isTrue);
        expect(result.components[0].grid![4][5], equals(1));
        expect(result.components[0].grid![4][6], equals(1));
        expect(result.components[1].name, equals('wings'));
        expect(result.components[2].name, equals('golden_armor'));
      },
    );

    test(
      'getDefaultComponents returns base_template if template is present',
      () {
        final templateGrid = List.generate(16, (_) => List.filled(16, 0));
        templateGrid[2][3] = 1;

        final templateContext = AgentContext(
          gridSize: 16,
          activePalette: activePalette,
          userPrompt: 'test prompt',
          currentGrid: templateGrid,
        );

        final agent = DecomposerAgent();
        final defaults = agent.getDefaultComponents(templateContext);
        expect(defaults, hasLength(1));
        expect(defaults[0].name, equals('base_template'));
        expect(defaults[0].isSculpted, isTrue);
        expect(defaults[0].grid![2][3], equals(1));
      },
    );

    test('propagates exception when aiService throws', () async {
      final agent = DecomposerAgent();
      final mockAi = TestMockAiService(
        shouldThrow: true,
        exceptionMessage: 'Network timeout',
      );
      expect(() => agent.decompose(mockAi, context), throwsA(isA<Exception>()));
    });
  });
}
