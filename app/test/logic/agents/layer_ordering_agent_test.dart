import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/agents/layer_ordering_agent.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';
import '../../test_helper.dart';

void main() {
  group('LayerOrderingAgent Tests', () {
    test(
      'suggestLayerOrder successfully reorders components based on AI response',
      () async {
        const responseJson = '''
{
  "reasoning": "Placed flask_body at the bottom (drawn first), red_elixir inside the flask, cork_stopper at the neck, and floating bubbles on top.",
  "orderedComponentNames": [
    "flask_body",
    "red_elixir",
    "cork_stopper",
    "bubbles"
  ]
}
''';

        final mockAi = TestMockAiService(response: responseJson);
        final agent = LayerOrderingAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: 'bubbles',
            description: 'floating bubbles',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.5, 0.2, 0.2),
          ),
          PixelArtComponent(
            name: 'flask_body',
            description: 'glass flask body',
            relativeBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.7),
          ),
          PixelArtComponent(
            name: 'cork_stopper',
            description: 'wooden cork',
            relativeBoundingBox: const Rect.fromLTWH(0.4, 0.1, 0.2, 0.2),
          ),
          PixelArtComponent(
            name: 'red_elixir',
            description: 'red liquid',
            relativeBoundingBox: const Rect.fromLTWH(0.3, 0.5, 0.4, 0.3),
          ),
        ];

        final result = await agent.suggestLayerOrder(
          userPrompt: 'potion flask',
          components: components,
        );

        expect(result, isNotNull);
        expect(result!.reasoning, contains('Placed flask_body at the bottom'));
        expect(
          result.reorderedComponents.map((c) => c.name).toList(),
          equals(['flask_body', 'red_elixir', 'cork_stopper', 'bubbles']),
        );
      },
    );

    test('suggestLayerOrder preserves omitted components at the end', () async {
      const responseJson = '''
{
  "reasoning": "Reordered known components.",
  "orderedComponentNames": [
    "flask_body",
    "red_elixir"
  ]
}
''';

      final mockAi = TestMockAiService(response: responseJson);
      final agent = LayerOrderingAgent(mockAi);

      final components = [
        PixelArtComponent(
          name: 'bubbles',
          description: 'floating bubbles',
          relativeBoundingBox: const Rect.fromLTWH(0.4, 0.5, 0.2, 0.2),
        ),
        PixelArtComponent(
          name: 'flask_body',
          description: 'glass flask body',
          relativeBoundingBox: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.7),
        ),
        PixelArtComponent(
          name: 'red_elixir',
          description: 'red liquid',
          relativeBoundingBox: const Rect.fromLTWH(0.3, 0.5, 0.4, 0.3),
        ),
      ];

      final result = await agent.suggestLayerOrder(
        userPrompt: 'potion flask',
        components: components,
      );

      expect(result, isNotNull);
      expect(
        result!.reorderedComponents.map((c) => c.name).toList(),
        equals(['flask_body', 'red_elixir', 'bubbles']),
      );
    });

    test(
      'suggestLayerOrder returns immediate result for single or empty component list',
      () async {
        final mockAi = TestMockAiService();
        final agent = LayerOrderingAgent(mockAi);

        expect(
          await agent.suggestLayerOrder(userPrompt: 'test', components: []),
          isNull,
        );

        final singleComp = [
          PixelArtComponent(
            name: 'only_comp',
            description: 'desc',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        ];

        final singleResult = await agent.suggestLayerOrder(
          userPrompt: 'test',
          components: singleComp,
        );

        expect(singleResult, isNotNull);
        expect(singleResult!.reorderedComponents.length, equals(1));
        expect(
          mockAi.callCount,
          equals(0),
        ); // No AI call needed for single item
      },
    );

    test('suggestLayerOrder handles errors gracefully', () async {
      final mockAi = TestMockAiService(response: '{"error": "AI unavailable"}');
      final agent = LayerOrderingAgent(mockAi);

      final components = [
        PixelArtComponent(
          name: 'comp1',
          description: 'desc1',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        ),
        PixelArtComponent(
          name: 'comp2',
          description: 'desc2',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        ),
      ];

      final result = await agent.suggestLayerOrder(
        userPrompt: 'test',
        components: components,
      );

      expect(result, isNull);
    });
  });
}
