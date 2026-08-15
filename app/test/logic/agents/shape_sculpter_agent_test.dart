import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/agents/shape_sculpter_agent.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import '../../test_helper.dart';

void main() {
  group('generateCanvasWithSculptingBmp Tests', () {
    const red = Color(0xFFFF0000);
    const green = Color(0xFF00FF00);
    const blue = Color(0xFF0000FF);
    final palette = [red, green, blue];

    Color extractPixelColor(Uint8List bmp, int x, int y, int size) {
      const bytesPerPixel = 3;
      final rowPadding = (4 - (size * bytesPerPixel) % 4) % 4;
      final rowStride = size * bytesPerPixel + rowPadding;
      final offset = 54 + (size - 1 - y) * rowStride + x * bytesPerPixel;
      final b = bmp[offset];
      final g = bmp[offset + 1];
      final r = bmp[offset + 2];
      return Color.fromARGB(255, r, g, b);
    }

    test(
      'correctly maps 1-based currentGrid values to palette indices (including last color)',
      () {
        final targetGrid = [
          [1, 0, 0],
          [0, 0, 0],
          [0, 0, 0],
        ];

        final currentGrid = [
          [0, 1, 0], // (1, 0) -> palette[0] = red
          [
            2,
            0,
            3,
          ], // (0, 1) -> palette[1] = green, (2, 1) -> palette[2] = blue (last color)
          [
            0,
            4,
            0,
          ], // (1, 2) -> out-of-bounds palette index -> white background
        ];

        final bmp = generateCanvasWithSculptingBmp(
          currentGrid,
          palette,
          targetGrid,
        );

        // (0, 0) is target grid -> black
        expect(extractPixelColor(bmp, 0, 0, 3), const Color(0xFF000000));

        // (1, 0) is currentGrid=1 -> palette[0] (red)
        expect(extractPixelColor(bmp, 1, 0, 3), red);

        // (0, 1) is currentGrid=2 -> palette[1] (green)
        expect(extractPixelColor(bmp, 0, 1, 3), green);

        // (2, 1) is currentGrid=3 -> palette[2] (blue, last palette entry)
        expect(extractPixelColor(bmp, 2, 1, 3), blue);

        // (1, 2) is currentGrid=4 -> out of palette bounds -> default white
        expect(extractPixelColor(bmp, 1, 2, 3), const Color(0xFFFFFFFF));

        // (2, 2) is background 0 -> white
        expect(extractPixelColor(bmp, 2, 2, 3), const Color(0xFFFFFFFF));
      },
    );

    test(
      'renders default white background when currentGrid or palette is null',
      () {
        final targetGrid = [
          [0, 0],
          [0, 0],
        ];

        final bmpNullGrid = generateCanvasWithSculptingBmp(
          null,
          palette,
          targetGrid,
        );
        expect(
          extractPixelColor(bmpNullGrid, 0, 0, 2),
          const Color(0xFFFFFFFF),
        );

        final currentGrid = [
          [1, 1],
          [1, 1],
        ];
        final bmpNullPalette = generateCanvasWithSculptingBmp(
          currentGrid,
          null,
          targetGrid,
        );
        expect(
          extractPixelColor(bmpNullPalette, 0, 0, 2),
          const Color(0xFFFFFFFF),
        );
      },
    );
  });

  group('ShapeSculpterAgent Tests', () {
    test('getSystemInstruction contains allowed bounds and tools', () {
      final agent = ShapeSculpterAgent();
      final comp = PixelArtComponent(
        name: 'blade',
        description: 'steel sword blade',
        relativeBoundingBox: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
      );

      final context = AgentContext(
        gridSize: 16,
        activePalette: const [Colors.black, Colors.white],
        userPrompt: 'sword',
        targetComponent: comp,
        currentGrid: List.generate(16, (_) => List.filled(16, 0)),
      );

      final instruction = agent.getSystemInstruction(context);
      expect(instruction, contains('circle_filled'));
      expect(instruction, contains('rectangle_filled'));
      expect(instruction, contains('steel sword blade'));
      expect(instruction, contains('Component Bounding Box Bounds'));
    });

    test('sculptComponent modifies grid according to AI response', () async {
      const jsonResponse = '''
      {
        "thought": "Sculpt blade shape",
        "tool": "rectangle_filled",
        "params": [4, 4, 11, 11],
        "add": [{"x": 5, "y": 5}],
        "remove": [{"x": 4, "y": 4}]
      }
      ''';

      final mockAi = TestMockAiService(response: jsonResponse);
      final agent = ShapeSculpterAgent();

      final comp = PixelArtComponent(
        name: 'blade',
        description: 'steel sword blade',
        relativeBoundingBox: const Rect.fromLTWH(
          0.25,
          0.25,
          0.5,
          0.5,
        ), // X: 4..11, Y: 4..11
      );

      final context = AgentContext(
        gridSize: 16,
        activePalette: const [Colors.black, Colors.white],
        userPrompt: 'sword',
        targetComponent: comp,
        currentGrid: List.generate(16, (_) => List.filled(16, 0)),
      );

      final resultGrid = await agent.sculptComponent(mockAi, context);
      // Rectangle filled from 4,4 to 11,11, with 4,4 removed and 5,5 added
      expect(resultGrid[4][4], equals(0)); // Removed
      expect(resultGrid[5][5], equals(1)); // Added / inside rect
      expect(resultGrid[6][6], equals(1)); // Inside rect
    });

    test(
      'sculptComponent returns unchanged grid when AI returns no instructions',
      () async {
        const jsonResponse = '''
      {
        "thought": "Already perfect",
        "tool": "",
        "params": [],
        "add": [],
        "remove": []
      }
      ''';

        final mockAi = TestMockAiService(response: jsonResponse);
        final agent = ShapeSculpterAgent();

        final initialGrid = List.generate(
          16,
          (y) => List.generate(16, (x) => (x == 5 && y == 5) ? 1 : 0),
        );
        final comp = PixelArtComponent(
          name: 'blade',
          description: 'steel blade',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
          grid: initialGrid,
        );

        final context = AgentContext(
          gridSize: 16,
          activePalette: const [Colors.black, Colors.white],
          userPrompt: 'sword',
          targetComponent: comp,
          currentGrid: List.generate(16, (_) => List.filled(16, 0)),
        );

        final resultGrid = await agent.sculptComponent(mockAi, context);
        expect(resultGrid, equals(initialGrid));
      },
    );
  });
}
