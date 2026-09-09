import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/prompts.dart';

void main() {
  group('AI Service Shared Prompt Formatting Helpers', () {
    test('formatSystemInstruction returns correct rules and tools', () {
      final sysInstruction = formatSystemInstruction();
      expect(sysInstruction, contains('AI pixel art painter agent'));
      expect(sysInstruction, contains('16x16 grid'));
      expect(sysInstruction, contains('"line"'));
      expect(sysInstruction, contains('"circle"'));
      expect(sysInstruction, contains('"circle_filled"'));
      expect(sysInstruction, contains('"circle_hatched"'));
      expect(sysInstruction, contains('"rectangle"'));
      expect(sysInstruction, contains('"rectangle_filled"'));
      expect(sysInstruction, contains('"rectangle_hatched"'));
      expect(sysInstruction, contains('"fill"'));
      expect(sysInstruction, contains('"hatch"'));
      expect(sysInstruction, isNot(contains('"undo"')));
      expect(sysInstruction, contains('output EXACTLY a valid JSON block'));
    });

    test('formatUserPrompt formats empty canvas correctly', () {
      final canvasImage = Uint8List.fromList(utf8.encode('00000000'));
      final prompt = 'draw a line';
      final paletteColors = ['#000000', '#ffffff', '#ff0000'];

      final userPrompt = formatUserPrompt(
        canvasImage: canvasImage,
        prompt: prompt,
        paletteColors: paletteColors,
      );

      expect(userPrompt, contains('User Instruction: "draw a line"'));
      expect(userPrompt, contains('The grid is completely empty (all 0s).'));
      expect(userPrompt, contains('Available Color Palette'));
      expect(userPrompt, contains('- Index 0: Eraser'));
      expect(userPrompt, contains('- Index 1: #000000'));
      expect(userPrompt, contains('- Index 3: #ff0000'));
    });

    test('formatUserPrompt formats active canvas correctly', () {
      final canvasImage = Uint8List.fromList(utf8.encode('01002000'));
      final prompt = 'draw a circle';
      final paletteColors = ['#000000', '#ffffff', '#ff0000', '#00ff00'];

      final userPrompt = formatUserPrompt(
        canvasImage: canvasImage,
        prompt: prompt,
        paletteColors: paletteColors,
      );

      expect(userPrompt, contains('User Instruction: "draw a circle"'));
      expect(userPrompt, isNot(contains('The grid is completely empty')));
      expect(userPrompt, contains('01002000'));
      expect(userPrompt, contains('Available Color Palette'));
      expect(userPrompt, contains('- Index 0: Eraser'));
      expect(userPrompt, contains('- Index 1: #000000'));
      expect(userPrompt, contains('- Index 4: #00ff00'));
    });

    test('formatUserPrompt includes custom reference image description', () {
      final canvasImage = Uint8List.fromList(utf8.encode('00000000'));
      final prompt = 'draw reference';
      final paletteColors = ['#000000', '#ffffff'];

      final userPrompt = formatUserPrompt(
        canvasImage: canvasImage,
        prompt: prompt,
        paletteColors: paletteColors,
        referenceDescription: 'A red circle in the center.',
      );

      expect(
        userPrompt,
        contains(
          'DESCRIPTION OF THE TARGET REFERENCE IMAGE:\nA red circle in the center.',
        ),
      );
    });

    test('cleanJsonString strips markdown blocks correctly', () {
      final input = '```json\n{"tool": "line"}\n```';
      expect(cleanJsonString(input), equals('{"tool": "line"}'));

      final inputNoLang = '```\n{"tool": "circle"}\n```';
      expect(cleanJsonString(inputNoLang), equals('{"tool": "circle"}'));

      final inputNoMarkdown = '{"tool": "fill"}';
      expect(cleanJsonString(inputNoMarkdown), equals('{"tool": "fill"}'));
    });

    test('formatUserPrompt includes custom text grids when provided', () {
      final canvasImage = Uint8List.fromList(utf8.encode('00000000'));
      final prompt = 'draw reference';
      final paletteColors = ['#000000', '#ffffff'];

      final userPrompt = formatUserPrompt(
        canvasImage: canvasImage,
        prompt: prompt,
        paletteColors: paletteColors,
        currentCanvasTextGrid: 'CANVAS_GRID_MOCK',
      );

      expect(userPrompt, contains('CURRENT CANVAS STATE'));
      expect(userPrompt, contains('CANVAS_GRID_MOCK'));
    });
  });

  group('Critic and Describer Prompt Formatting Helpers', () {
    group('formatCriticSystemInstruction', () {
      test('returns expected role, constraints, and JSON schema', () {
        final instruction = formatCriticSystemInstruction();
        expect(instruction, isNotEmpty);
        expect(instruction, contains('AI pixel art critic'));
        expect(instruction, contains('16x16 grid'));
        expect(
          instruction,
          contains(
            '1. Reference (Quantized): Smoothed, color-quantized reference.',
          ),
        );
        expect(
          instruction,
          contains(
            '2. Current Canvas: The current state of the canvas with the latest stroke applied.',
          ),
        );
        expect(instruction, contains('latest stroke'));
        expect(instruction, contains('"keep"'));
        expect(instruction, contains('"undo"'));
        expect(instruction, contains('"reasoning"'));
        expect(instruction, contains('"action"'));
        expect(instruction, contains('max 1 sentence/15 words'));
      });
    });

    group('formatCriticUserPrompt', () {
      test(
        'returns non-empty instructions with expected schema and actions',
        () {
          final prompt = formatCriticUserPrompt();
          expect(prompt, isNotEmpty);
          expect(
            prompt,
            contains(
              'Evaluate the latest stroke applied to the Current Canvas.',
            ),
          );
          expect(
            prompt,
            contains(
              'Determine if the stroke aligns with the target reference image.',
            ),
          );
          expect(prompt, contains('"reasoning"'));
          expect(prompt, contains('"action"'));
          expect(prompt, contains('"keep"'));
          expect(prompt, contains('"undo"'));
        },
      );
    });

    group('formatCriticComparisonPrompt', () {
      test('specifies role, 2x2 grid panel layout, and schema constraints', () {
        final prompt = formatCriticComparisonPrompt();
        expect(prompt, isNotEmpty);
        expect(
          prompt,
          contains(
            'evaluating candidate drawings produced by three different Painter agents',
          ),
        );
        expect(prompt, contains('select the single best candidate drawing'));
        expect(prompt, contains('2x2 grid of panels'));
        expect(
          prompt,
          contains(
            'Top-Left: Reference Image (or the Starting Canvas before the 5-turn block started)',
          ),
        );
        expect(
          prompt,
          contains('Top-Right: Candidate 1 (Painter Agent - Run 1)'),
        );
        expect(
          prompt,
          contains('Bottom-Left: Candidate 2 (Painter Agent - Run 2)'),
        );
        expect(
          prompt,
          contains('Bottom-Right: Candidate 3 (Painter Agent - Run 3)'),
        );
        expect(prompt, contains('"choice": 1'));
        expect(prompt, contains('"reasoning"'));
        expect(prompt, contains('max 1 sentence/15 words'));
        expect(
          prompt,
          contains(
            'Output only the JSON block. Do not write any markdown tags or explanations.',
          ),
        );
      });
    });

    group('formatDescriberSystemInstruction', () {
      test(
        'includes describer role, 16x16 grid size, length guideline, and 4 focal points',
        () {
          final instruction = formatDescriberSystemInstruction();
          expect(instruction, isNotEmpty);
          expect(instruction, contains('AI pixel art describer'));
          expect(instruction, contains('16x16 pixel art canvas'));
          expect(instruction, contains('about 100 words'));
          expect(instruction, contains('Shapes & Layout:'));
          expect(instruction, contains('Colors & Contrast:'));
          expect(instruction, contains('Details & Texture:'));
          expect(instruction, contains('Subject Identity:'));
        },
      );
    });

    group('formatDescriberUserPrompt', () {
      test('specifies 16x16 image analysis and ~100 words description', () {
        final prompt = formatDescriberUserPrompt();
        expect(prompt, isNotEmpty);
        expect(prompt, contains('16x16 pixel art image'));
        expect(prompt, contains('about 100 words'));
        expect(
          prompt,
          contains(
            'shapes, colors, fine details, and speculating on what it is depicting',
          ),
        );
      });
    });

    group('formatCriticTextOnlyPrompt', () {
      test(
        'interpolates all provided descriptions and includes schema with nextFocus',
        () {
          final prompt = formatCriticTextOnlyPrompt(
            userPrompt: 'Draw a red dragon',
            referenceDescription: 'A red winged dragon on black',
            startingCanvasDescription: 'Empty canvas',
            candidate1Description: 'Body drawn',
            candidate2Description: 'Wings added',
            candidate3Description: 'Tail only',
          );

          expect(prompt, isNotEmpty);
          expect(
            prompt,
            contains(
              'evaluating candidate drawings produced by three different Painter agents',
            ),
          );
          expect(prompt, contains('USER INSTRUCTION:\n"Draw a red dragon"'));
          expect(
            prompt,
            contains(
              'TARGET REFERENCE IMAGE DESCRIPTION:\nA red winged dragon on black',
            ),
          );
          expect(
            prompt,
            contains('STARTING CANVAS DESCRIPTION:\nEmpty canvas'),
          );
          expect(
            prompt,
            contains('CANDIDATE 1 DESCRIPTION (Painter Run 1):\nBody drawn'),
          );
          expect(
            prompt,
            contains('CANDIDATE 2 DESCRIPTION (Painter Run 2):\nWings added'),
          );
          expect(
            prompt,
            contains('CANDIDATE 3 DESCRIPTION (Painter Run 3):\nTail only'),
          );
          expect(prompt, contains('"choice"'));
          expect(prompt, contains('"reasoning"'));
          expect(prompt, contains('"nextFocus"'));
          expect(prompt, contains('max 1 sentence/15 words each'));
          expect(
            prompt,
            contains(
              'Output only the JSON block. Do not write any markdown tags or explanations.',
            ),
          );
        },
      );

      test('handles empty strings without errors', () {
        final prompt = formatCriticTextOnlyPrompt(
          userPrompt: '',
          referenceDescription: '',
          startingCanvasDescription: '',
          candidate1Description: '',
          candidate2Description: '',
          candidate3Description: '',
        );

        expect(prompt, isNotEmpty);
        expect(prompt, contains('USER INSTRUCTION:\n""'));
        expect(prompt, contains('TARGET REFERENCE IMAGE DESCRIPTION:\n\n'));
        expect(prompt, contains('STARTING CANVAS DESCRIPTION:\n\n'));
        expect(
          prompt,
          contains('CANDIDATE 1 DESCRIPTION (Painter Run 1):\n\n'),
        );
        expect(
          prompt,
          contains('CANDIDATE 2 DESCRIPTION (Painter Run 2):\n\n'),
        );
        expect(
          prompt,
          contains('CANDIDATE 3 DESCRIPTION (Painter Run 3):\n\n'),
        );
      });

      test('handles multiline descriptions and special characters intact', () {
        const multilineRef =
            'Line 1: Red shape\nLine 2: "Quoted text"\nLine 3: Path/with/slashes';
        const multilineCand =
            'Candidate details with special characters: { "key": "value" }, \$symbols & 100%';

        final prompt = formatCriticTextOnlyPrompt(
          userPrompt: 'Draw a "complex" object',
          referenceDescription: multilineRef,
          startingCanvasDescription: 'Start\nState',
          candidate1Description: multilineCand,
          candidate2Description: 'Candidate 2',
          candidate3Description: 'Candidate 3',
        );

        expect(prompt, contains('Draw a "complex" object'));
        expect(prompt, contains(multilineRef));
        expect(prompt, contains('Start\nState'));
        expect(prompt, contains(multilineCand));
      });
    });
  });
}
