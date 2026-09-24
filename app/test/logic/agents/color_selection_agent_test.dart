import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/agents/color_selection_agent.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';

import '../../test_helper.dart';

void main() {
  group('ColorSelectionAgent Tests', () {
    test(
      'suggestColors parses JSON response and enforces 1-color rule for non-interior components',
      () async {
        final mockAi = TestMockAiService(
          response: TestJsonFixtures.colorSelectionResponse,
        );
        final agent = ColorSelectionAgent(mockAi);

        final solidGrid = List.generate(
          16,
          (y) => List.generate(
            16,
            (x) => (x >= 1 && x <= 5 && y >= 1 && y <= 5) ? 1 : 0,
          ),
        );
        final thinGrid = List.generate(
          16,
          (y) =>
              List.generate(16, (x) => (x == 5 && y >= 2 && y <= 12) ? 1 : 0),
        );

        final components = [
          PixelArtComponent(
            name: 'blade',
            description: 'solid blade',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
            grid: solidGrid,
          ),
          PixelArtComponent(
            name: 'hilt_line',
            description: 'thin hilt line',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
            grid: thinGrid,
          ),
        ];

        const blue = Color(0xFF0000FF);
        const red = Color(0xFFFF0000);
        const black = Color(0xFF000000);

        final palette = [black, blue, red];

        final result = await agent.suggestColors(
          userPrompt: 'magic sword',
          components: components,
          palette: palette,
        );

        expect(result, isNotNull);
        expect(result!.reasoning, contains('Selected blue to red gradient'));

        final blade = result.updatedComponents[0];
        expect(blade.fillColor?.toARGB32(), equals(blue.toARGB32()));
        expect(blade.fillColor2?.toARGB32(), equals(red.toARGB32()));
        expect(blade.gradientAngle, equals(45.0));

        final hiltLine = result.updatedComponents[1];
        // Hilt line has no interior -> fillColor2 MUST be enforced null (1 color rule)
        expect(hiltLine.fillColor2, isNull);

        // Verify captured prompt includes plain directional descriptions
        final prompt = mockAi.capturedPrompts.first;
        expect(prompt, contains('Left to Right (→)'));
        expect(prompt, contains('Top to Bottom (↓)'));
        expect(prompt, contains('Top-Left to Bottom-Right (↘)'));
        expect(prompt, contains('Bottom to Top (↑)'));
      },
    );

    test(
      'suggestColors returns null for empty components or empty palette',
      () async {
        final mockAi = TestMockAiService();
        final agent = ColorSelectionAgent(mockAi);

        expect(
          await agent.suggestColors(
            userPrompt: 'test',
            components: [],
            palette: [const Color(0xFF000000)],
          ),
          isNull,
        );

        expect(
          await agent.suggestColors(
            userPrompt: 'test',
            components: [
              PixelArtComponent(
                name: 'comp',
                description: 'desc',
                relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
              ),
            ],
            palette: [],
          ),
          isNull,
        );
      },
    );

    test(
      'suggestColors gracefully handles error JSON payload by returning null',
      () async {
        final mockAi = TestMockAiService(
          response: '{"error": "Quota exceeded for model"}',
        );
        final agent = ColorSelectionAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: 'blade',
            description: 'solid blade',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        ];

        final result = await agent.suggestColors(
          userPrompt: 'magic sword',
          components: components,
          palette: const [Color(0xFF000000)],
        );

        expect(result, isNull);
      },
    );

    test(
      'suggestColors gracefully handles non-map JSON shapes by returning null',
      () async {
        final mockAi = TestMockAiService(
          response: '["unexpected", "list", "response"]',
        );
        final agent = ColorSelectionAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: 'blade',
            description: 'solid blade',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        ];

        final result = await agent.suggestColors(
          userPrompt: 'magic sword',
          components: components,
          palette: const [Color(0xFF000000)],
        );

        expect(result, isNull);
      },
    );

    test('suggestColors parses string-typed gradientAngle correctly', () async {
      final mockAi = TestMockAiService(
        response: '''
{
  "reasoning": "Selected palette with string-typed angle",
  "componentColors": [
    {
      "name": "blade",
      "fillColorHex": "#0000FF",
      "fillColor2Hex": "#FF0000",
      "gradientAngle": "45.0",
      "outlineColorHex": "#000000"
    }
  ]
}
''',
      );
      final agent = ColorSelectionAgent(mockAi);

      final solidGrid = List.generate(
        16,
        (y) => List.generate(
          16,
          (x) => (x >= 1 && x <= 5 && y >= 1 && y <= 5) ? 1 : 0,
        ),
      );

      final components = [
        PixelArtComponent(
          name: 'blade',
          description: 'solid blade',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          grid: solidGrid,
        ),
      ];

      const blue = Color(0xFF0000FF);
      const red = Color(0xFFFF0000);
      const black = Color(0xFF000000);
      final palette = [black, blue, red];

      final result = await agent.suggestColors(
        userPrompt: 'magic sword',
        components: components,
        palette: palette,
      );

      expect(result, isNotNull);
      expect(
        result!.reasoning,
        equals('Selected palette with string-typed angle'),
      );
      final blade = result.updatedComponents[0];
      expect(blade.fillColor?.toARGB32(), equals(blue.toARGB32()));
      expect(blade.fillColor2?.toARGB32(), equals(red.toARGB32()));
      expect(blade.gradientAngle, equals(45.0));
    });

    test(
      'suggestColors defaults missing or unparseable gradientAngle to 90.0 and supports integer strings',
      () async {
        final mockAi = TestMockAiService(
          response: '''
{
  "reasoning": "Angle tests",
  "componentColors": [
    {
      "name": "comp1",
      "fillColorHex": "#0000FF",
      "gradientAngle": "invalid_angle"
    },
    {
      "name": "comp2",
      "fillColorHex": "#0000FF"
    },
    {
      "name": "comp3",
      "fillColorHex": "#0000FF",
      "gradientAngle": "180"
    }
  ]
}
''',
        );
        final agent = ColorSelectionAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: 'comp1',
            description: 'comp 1',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
          PixelArtComponent(
            name: 'comp2',
            description: 'comp 2',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
          PixelArtComponent(
            name: 'comp3',
            description: 'comp 3',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        ];

        const blue = Color(0xFF0000FF);
        final palette = [blue];

        final result = await agent.suggestColors(
          userPrompt: 'test',
          components: components,
          palette: palette,
        );

        expect(result, isNotNull);
        expect(result!.updatedComponents[0].gradientAngle, equals(90.0));
        expect(result.updatedComponents[1].gradientAngle, equals(90.0));
        expect(result.updatedComponents[2].gradientAngle, equals(180.0));
      },
    );

    test(
      'suggestColors gracefully handles non-string or numeric fields without throwing TypeError',
      () async {
        final mockAi = TestMockAiService(
          response: '''
{
  "reasoning": 12345,
  "componentColors": [
    {
      "name": 1,
      "fillColorHex": 123,
      "gradientAngle": "90",
      "outlineColorHex": 456
    },
    {
      "name": "blade",
      "fillColorHex": 12345,
      "fillColor2Hex": 8888,
      "gradientAngle": null,
      "outlineColorHex": false
    }
  ]
}
''',
        );
        final agent = ColorSelectionAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: '1',
            description: 'numbered component',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
          PixelArtComponent(
            name: 'blade',
            description: 'solid blade',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        ];

        final result = await agent.suggestColors(
          userPrompt: 'magic sword',
          components: components,
          palette: const [Color(0xFF000000)],
        );

        expect(result, isNotNull);
        expect(result!.reasoning, equals('12345'));

        final numberedComp = result.updatedComponents[0];
        expect(numberedComp.name, equals('1'));
        expect(numberedComp.gradientAngle, equals(90.0));
        expect(numberedComp.fillColor, isNull);

        final blade = result.updatedComponents[1];
        expect(blade.fillColor, isNull);
        expect(blade.fillColor2, isNull);
        expect(blade.outlineColor, isNull);
        expect(blade.gradientAngle, equals(90.0));
      },
    );

    test('suggestColors safely handles non-list componentColors', () async {
      final mockAi = TestMockAiService(
        response: '''
{
  "reasoning": "Invalid componentColors shape",
  "componentColors": "not_a_list"
}
''',
      );
      final agent = ColorSelectionAgent(mockAi);

      final components = [
        PixelArtComponent(
          name: 'blade',
          description: 'solid blade',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        ),
      ];

      final result = await agent.suggestColors(
        userPrompt: 'magic sword',
        components: components,
        palette: const [Color(0xFF000000)],
      );

      expect(result, isNotNull);
      expect(result!.reasoning, equals('Invalid componentColors shape'));
      expect(result.updatedComponents[0].name, equals('blade'));
    });

    test(
      'suggestColors defaults non-finite gradientAngle inputs (NaN, Infinity, -Infinity) to 90.0',
      () async {
        final mockAi = TestMockAiService(
          response: '''
{
  "reasoning": "Non-finite angle tests",
  "componentColors": [
    {
      "name": "comp_nan",
      "fillColorHex": "#0000FF",
      "gradientAngle": "NaN"
    },
    {
      "name": "comp_inf",
      "fillColorHex": "#0000FF",
      "gradientAngle": "Infinity"
    },
    {
      "name": "comp_neg_inf",
      "fillColorHex": "#0000FF",
      "gradientAngle": "-Infinity"
    }
  ]
}
''',
        );
        final agent = ColorSelectionAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: 'comp_nan',
            description: 'comp nan',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
          PixelArtComponent(
            name: 'comp_inf',
            description: 'comp inf',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
          PixelArtComponent(
            name: 'comp_neg_inf',
            description: 'comp neg inf',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        ];

        final result = await agent.suggestColors(
          userPrompt: 'test',
          components: components,
          palette: const [Color(0xFF0000FF)],
        );

        expect(result, isNotNull);
        expect(result!.updatedComponents[0].gradientAngle, equals(90.0));
        expect(result.updatedComponents[1].gradientAngle, equals(90.0));
        expect(result.updatedComponents[2].gradientAngle, equals(90.0));
      },
    );

    test(
      'suggestColors correctly matches component names with whitespace',
      () async {
        final mockAi = TestMockAiService(
          response: '''
{
  "reasoning": "Whitespace matching test",
  "componentColors": [
    {
      "name": "  blade  ",
      "fillColorHex": "#0000FF"
    },
    {
      "name": "hilt",
      "fillColorHex": "#FF0000"
    }
  ]
}
''',
        );
        final agent = ColorSelectionAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: 'blade',
            description: 'solid blade',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
          PixelArtComponent(
            name: '  hilt  ',
            description: 'solid hilt',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        ];

        const blue = Color(0xFF0000FF);
        const red = Color(0xFFFF0000);

        final result = await agent.suggestColors(
          userPrompt: 'test',
          components: components,
          palette: const [blue, red],
        );

        expect(result, isNotNull);
        expect(
          result!.updatedComponents[0].fillColor?.toARGB32(),
          equals(blue.toARGB32()),
        );
        expect(
          result.updatedComponents[1].fillColor?.toARGB32(),
          equals(red.toARGB32()),
        );
      },
    );

    test(
      'suggestColors performs case-insensitive component name matching',
      () async {
        final mockAi = TestMockAiService(
          response: '''
{
  "reasoning": "Case-insensitive test",
  "componentColors": [
    {
      "name": "Blade",
      "fillColorHex": "#0000FF"
    },
    {
      "name": "hilt",
      "fillColorHex": "#FF0000"
    }
  ]
}
''',
        );
        final agent = ColorSelectionAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: 'blade',
            description: 'solid blade',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
          PixelArtComponent(
            name: 'HILT',
            description: 'solid hilt',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        ];

        const blue = Color(0xFF0000FF);
        const red = Color(0xFFFF0000);

        final result = await agent.suggestColors(
          userPrompt: 'test',
          components: components,
          palette: const [blue, red],
        );

        expect(result, isNotNull);
        expect(
          result!.updatedComponents[0].fillColor?.toARGB32(),
          equals(blue.toARGB32()),
        );
        expect(
          result.updatedComponents[1].fillColor?.toARGB32(),
          equals(red.toARGB32()),
        );
      },
    );

    test(
      'suggestColors parses 0x-prefixed and 8-digit ARGB hex color strings',
      () async {
        final mockAi = TestMockAiService(
          response: '''
{
  "reasoning": "Hex prefix and ARGB tests",
  "componentColors": [
    {
      "name": "comp1",
      "fillColorHex": "0x0000FF",
      "outlineColorHex": "0x000000"
    },
    {
      "name": "comp2",
      "fillColorHex": "#FF0000FF",
      "fillColor2Hex": "0xFFFF0000"
    }
  ]
}
''',
        );
        final agent = ColorSelectionAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: 'comp1',
            description: 'comp 1',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
          PixelArtComponent(
            name: 'comp2',
            description: 'comp 2',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
            grid: List.generate(16, (y) => List.generate(16, (x) => 1)),
          ),
        ];

        const blue = Color(0xFF0000FF);
        const red = Color(0xFFFF0000);
        const black = Color(0xFF000000);

        final result = await agent.suggestColors(
          userPrompt: 'test',
          components: components,
          palette: const [blue, red, black],
        );

        expect(result, isNotNull);
        expect(
          result!.updatedComponents[0].fillColor?.toARGB32(),
          equals(blue.toARGB32()),
        );
        expect(
          result.updatedComponents[0].outlineColor?.toARGB32(),
          equals(black.toARGB32()),
        );
        expect(
          result.updatedComponents[1].fillColor?.toARGB32(),
          equals(blue.toARGB32()),
        );
        expect(
          result.updatedComponents[1].fillColor2?.toARGB32(),
          equals(red.toARGB32()),
        );
      },
    );

    test(
      'suggestColors parses shorthand 3-digit and 4-digit hex color strings',
      () async {
        final mockAi = TestMockAiService(
          response: '''
{
  "reasoning": "Shorthand hex tests",
  "componentColors": [
    {
      "name": "comp1",
      "fillColorHex": "#00F",
      "outlineColorHex": "#000"
    },
    {
      "name": "comp2",
      "fillColorHex": "0xF00",
      "fillColor2Hex": "#FFF"
    }
  ]
}
''',
        );
        final agent = ColorSelectionAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: 'comp1',
            description: 'comp 1',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
          PixelArtComponent(
            name: 'comp2',
            description: 'comp 2',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
            grid: List.generate(16, (y) => List.generate(16, (x) => 1)),
          ),
        ];

        const blue = Color(0xFF0000FF);
        const red = Color(0xFFFF0000);
        const black = Color(0xFF000000);
        const white = Color(0xFFFFFFFF);

        final result = await agent.suggestColors(
          userPrompt: 'test',
          components: components,
          palette: const [blue, red, black, white],
        );

        expect(result, isNotNull);
        expect(
          result!.updatedComponents[0].fillColor?.toARGB32(),
          equals(blue.toARGB32()),
        );
        expect(
          result.updatedComponents[0].outlineColor?.toARGB32(),
          equals(black.toARGB32()),
        );
        expect(
          result.updatedComponents[1].fillColor?.toARGB32(),
          equals(red.toARGB32()),
        );
        expect(
          result.updatedComponents[1].fillColor2?.toARGB32(),
          equals(white.toARGB32()),
        );
      },
    );

    test(
      'suggestColors matches palette colors with non-opaque alpha channels by RGB',
      () async {
        final mockAi = TestMockAiService(
          response: '''
{
  "reasoning": "Semi-transparent palette matching test",
  "componentColors": [
    {
      "name": "comp1",
      "fillColorHex": "#0000FF"
    },
    {
      "name": "comp2",
      "fillColorHex": "#F00"
    }
  ]
}
''',
        );
        final agent = ColorSelectionAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: 'comp1',
            description: 'comp 1',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
          PixelArtComponent(
            name: 'comp2',
            description: 'comp 2',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        ];

        // Non-opaque palette colors (e.g. alpha = 0x80 or 0xAA)
        const semiTransparentBlue = Color(0x800000FF);
        const semiTransparentRed = Color(0xAAFF0000);
        const fallbackColor = Color(0xFF112233);

        final result = await agent.suggestColors(
          userPrompt: 'test',
          components: components,
          palette: const [
            fallbackColor,
            semiTransparentBlue,
            semiTransparentRed,
          ],
        );

        expect(result, isNotNull);
        expect(
          result!.updatedComponents[0].fillColor?.toARGB32(),
          equals(semiTransparentBlue.toARGB32()),
        );
        expect(
          result.updatedComponents[1].fillColor?.toARGB32(),
          equals(semiTransparentRed.toARGB32()),
        );
      },
    );

    test(
      'suggestColors keeps duplicate component name overrides in sync for case-insensitive lookup',
      () async {
        final mockAi = TestMockAiService(
          response: '''
{
  "reasoning": "Duplicate component override test",
  "componentColors": [
    {
      "name": "blade",
      "fillColorHex": "#0000FF"
    },
    {
      "name": "blade",
      "fillColorHex": "#FF0000"
    }
  ]
}
''',
        );
        final agent = ColorSelectionAgent(mockAi);

        final components = [
          PixelArtComponent(
            name: 'BLADE',
            description: 'blade uppercase',
            relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          ),
        ];

        const blue = Color(0xFF0000FF);
        const red = Color(0xFFFF0000);

        final result = await agent.suggestColors(
          userPrompt: 'test',
          components: components,
          palette: const [blue, red],
        );

        expect(result, isNotNull);
        expect(
          result!.updatedComponents[0].fillColor?.toARGB32(),
          equals(red.toARGB32()),
        );
      },
    );
  });
}
