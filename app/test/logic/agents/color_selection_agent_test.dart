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
      },
    );
  });
}
