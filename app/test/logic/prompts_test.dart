import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/models/sprite_template.dart';
import 'package:bad_pixel_art/logic/prompts.dart';

import '../test_helper.dart';

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

  group('PixelArtAiServiceExtension', () {
    final dummyCanvasImage = Uint8List.fromList([1, 2, 3, 4]);

    group('describeCanvas', () {
      test(
        'successfully parses model response and returns map with prompt and response',
        () async {
          final mockAi = TestMockAiService(
            response: 'A red circle in the center of the canvas.',
          );
          final result = await mockAi.describeCanvas(
            canvasImage: dummyCanvasImage,
          );

          expect(result, isNotNull);
          expect(
            result!['prompt'],
            contains(formatDescriberSystemInstruction()),
          );
          expect(result['prompt'], contains(formatDescriberUserPrompt()));
          expect(
            result['response'],
            equals('A red circle in the center of the canvas.'),
          );
          expect(mockAi.capturedImageBytes.first, equals(dummyCanvasImage));
        },
      );

      test('returns null when underlying service returns null', () {
        fakeAsync((async) {
          final mockAi = TestMockAiService(response: null);
          Map<String, String>? result;
          bool completed = false;

          mockAi.describeCanvas(canvasImage: dummyCanvasImage).then((val) {
            result = val;
            completed = true;
          });

          async.elapse(const Duration(seconds: 10));

          expect(completed, isTrue);
          expect(result, isNull);
        });
      });

      test('returns null when underlying service throws an exception', () {
        fakeAsync((async) {
          final mockAi = TestMockAiService(shouldThrow: true);
          Map<String, String>? result;
          bool completed = false;

          mockAi.describeCanvas(canvasImage: dummyCanvasImage).then((val) {
            result = val;
            completed = true;
          });

          async.elapse(const Duration(seconds: 10));

          expect(completed, isTrue);
          expect(result, isNull);
        });
      });
    });

    group('getNextStroke', () {
      test('parses clean JSON response into Map<String, dynamic>', () async {
        const jsonResponse =
            '{"tool": "circle", "color": 2, "params": {"cx": 8, "cy": 8, "r": 3}}';
        final mockAi = TestMockAiService(response: jsonResponse);

        final result = await mockAi.getNextStroke(
          canvasImage: dummyCanvasImage,
          prompt: 'draw a circle',
          temperature: 0.2,
        );

        expect(result, isNotNull);
        expect(result!['tool'], equals('circle'));
        expect(result['color'], equals(2));
        expect(result['params'], equals({'cx': 8, 'cy': 8, 'r': 3}));
        expect(mockAi.capturedImageBytes.first, equals(dummyCanvasImage));
        expect(mockAi.capturedPrompts.first, equals('draw a circle'));
      });

      test('strips markdown code blocks via cleanJsonString', () async {
        const jsonResponse =
            '```json\n{"tool": "line", "color": 1, "params": {"x1": 0, "y1": 0, "x2": 5, "y2": 5}}\n```';
        final mockAi = TestMockAiService(response: jsonResponse);

        final result = await mockAi.getNextStroke(
          canvasImage: dummyCanvasImage,
          prompt: 'draw a line',
          temperature: 0.1,
        );

        expect(result, isNotNull);
        expect(result!['tool'], equals('line'));
        expect(result['color'], equals(1));
      });

      test('returns error map when response contains error object', () async {
        const jsonResponse = '{\n  "error" : "model overloaded"\n}';
        final mockAi = TestMockAiService(response: jsonResponse);

        final result = await mockAi.getNextStroke(
          canvasImage: dummyCanvasImage,
          prompt: 'draw a star',
          temperature: 0.1,
        );

        expect(result, isNotNull);
        expect(result!['error'], equals('model overloaded'));
        expect(result['rawResponse'], equals(jsonResponse));
      });

      test(
        'catches JSON decoding errors and returns formatted error map with rawResponse N/A',
        () async {
          const malformedResponse = '{not_valid_json: true}';
          final mockAi = TestMockAiService(response: malformedResponse);

          final result = await mockAi.getNextStroke(
            canvasImage: dummyCanvasImage,
            prompt: 'draw a star',
            temperature: 0.1,
          );

          expect(result, isNotNull);
          expect(result!['error'], contains('FormatException'));
          expect(result['rawResponse'], equals('N/A'));
        },
      );

      test('returns null when parsed JSON is not a Map', () async {
        const arrayResponse = '["tool", "circle"]';
        final mockAi = TestMockAiService(response: arrayResponse);

        final result = await mockAi.getNextStroke(
          canvasImage: dummyCanvasImage,
          prompt: 'draw a circle',
          temperature: 0.1,
        );

        expect(result, isNull);
      });

      test('returns null when underlying service returns null', () {
        fakeAsync((async) {
          final mockAi = TestMockAiService(response: null);
          Map<String, dynamic>? result;
          bool completed = false;

          mockAi
              .getNextStroke(
                canvasImage: dummyCanvasImage,
                prompt: 'draw a circle',
                temperature: 0.1,
              )
              .then((val) {
                result = val;
                completed = true;
              });

          async.elapse(const Duration(seconds: 10));

          expect(completed, isTrue);
          expect(result, isNull);
        });
      });
    });

    group('suggestPalette & suggestPaletteForTemplate', () {
      test(
        'suggestPalette parses palette colors when model returns valid hex strings',
        () async {
          const hexList =
              '["#112233", "#445566", "#778899", "#aabbcc", "#ddeeff", "#123456", "#789abc", "#fedcba"]';
          final mockAi = TestMockAiService(response: hexList);

          final result = await mockAi.suggestPalette(dummyCanvasImage);

          expect(result, isNotNull);
          expect(result!.length, equals(8));
          expect(result[0], equals(const Color(0xFF112233)));
          expect(result[1], equals(const Color(0xFF445566)));
          expect(mockAi.capturedImageBytes.first, equals(dummyCanvasImage));
          expect(mockAi.capturedPrompts.first, equals(formatPalettePrompt()));
        },
      );

      test('suggestPalette returns null when model returns null', () {
        fakeAsync((async) {
          final mockAi = TestMockAiService(response: null);
          List<Color>? result;
          bool completed = false;

          mockAi.suggestPalette(dummyCanvasImage).then((val) {
            result = val;
            completed = true;
          });

          async.elapse(const Duration(seconds: 10));

          expect(completed, isTrue);
          expect(result, isNull);
        });
      });

      test('suggestPalette returns null when model throws an exception', () {
        fakeAsync((async) {
          final mockAi = TestMockAiService(shouldThrow: true);
          List<Color>? result;
          bool completed = false;

          mockAi.suggestPalette(dummyCanvasImage).then((val) {
            result = val;
            completed = true;
          });

          async.elapse(const Duration(seconds: 10));

          expect(completed, isTrue);
          expect(result, isNull);
        });
      });

      test(
        'suggestPaletteForTemplate parses palette colors for template with imageBytes null',
        () async {
          const hexList =
              '["#111111", "#222222", "#333333", "#444444", "#555555", "#666666", "#777777", "#888888"]';
          final mockAi = TestMockAiService(response: hexList);

          const template = SpriteTemplate(
            id: 'sword',
            name: 'Sword',
            description: 'A pixel art sword',
            width: 16,
            height: 16,
            rawTemplate: '0000\n0110\n0110\n0000',
          );

          final result = await mockAi.suggestPaletteForTemplate(
            prompt: 'iron sword',
            template: template,
          );

          expect(result, isNotNull);
          expect(result!.length, equals(8));
          expect(result[0], equals(const Color(0xFF111111)));
          expect(mockAi.capturedImageBytes.first, isNull);
          expect(mockAi.capturedPrompts.first, contains('iron sword'));
          expect(mockAi.capturedPrompts.first, contains('Sword'));
        },
      );

      test(
        'suggestPaletteForTemplate works with null template and returns parsed colors',
        () async {
          const hexList =
              '["#111111", "#222222", "#333333", "#444444", "#555555", "#666666", "#777777", "#888888"]';
          final mockAi = TestMockAiService(response: hexList);

          final result = await mockAi.suggestPaletteForTemplate(
            prompt: 'blank sprite',
            template: null,
          );

          expect(result, isNotNull);
          expect(result!.length, equals(8));
          expect(mockAi.capturedImageBytes.first, isNull);
          expect(mockAi.capturedPrompts.first, contains('blank sprite'));
        },
      );

      test(
        'suggestPaletteForTemplate returns null when model returns null',
        () {
          fakeAsync((async) {
            final mockAi = TestMockAiService(response: null);
            List<Color>? result;
            bool completed = false;

            mockAi.suggestPaletteForTemplate(prompt: 'potion').then((val) {
              result = val;
              completed = true;
            });

            async.elapse(const Duration(seconds: 10));

            expect(completed, isTrue);
            expect(result, isNull);
          });
        },
      );

      test(
        'suggestPaletteForTemplate returns null when model throws an exception',
        () {
          fakeAsync((async) {
            final mockAi = TestMockAiService(shouldThrow: true);
            List<Color>? result;
            bool completed = false;

            mockAi.suggestPaletteForTemplate(prompt: 'potion').then((val) {
              result = val;
              completed = true;
            });

            async.elapse(const Duration(seconds: 10));

            expect(completed, isTrue);
            expect(result, isNull);
          });
        },
      );
    });

    group('evaluateStroke', () {
      test('parses valid critic evaluation JSON', () async {
        const jsonResponse =
            '{"action": "keep", "reasoning": "Stroke accurately shapes outline"}';
        final mockAi = TestMockAiService(response: jsonResponse);

        final result = await mockAi.evaluateStroke(
          canvasImage: dummyCanvasImage,
        );

        expect(result, isNotNull);
        expect(result!['action'], equals('keep'));
        expect(result['reasoning'], equals('Stroke accurately shapes outline'));
        expect(mockAi.capturedImageBytes.first, equals(dummyCanvasImage));
        expect(
          mockAi.capturedPrompts.first,
          contains(formatCriticSystemInstruction()),
        );
        expect(
          mockAi.capturedPrompts.first,
          contains(formatCriticUserPrompt()),
        );
      });

      test('strips markdown code blocks from critic response', () async {
        const jsonResponse =
            '```json\n{"action": "undo", "reasoning": "Wrong position"}\n```';
        final mockAi = TestMockAiService(response: jsonResponse);

        final result = await mockAi.evaluateStroke(
          canvasImage: dummyCanvasImage,
        );

        expect(result, isNotNull);
        expect(result!['action'], equals('undo'));
        expect(result['reasoning'], equals('Wrong position'));
      });

      test('returns error map when response contains error payload', () async {
        const jsonResponse = '{\n  "error" : "service overloaded"\n}';
        final mockAi = TestMockAiService(response: jsonResponse);

        final result = await mockAi.evaluateStroke(
          canvasImage: dummyCanvasImage,
        );

        expect(result, isNotNull);
        expect(result!['error'], equals('service overloaded'));
        expect(result['rawResponse'], equals(jsonResponse));
      });

      test(
        'catches malformed JSON and returns formatted error map with rawResponse N/A',
        () async {
          const jsonResponse = 'not valid JSON.';
          final mockAi = TestMockAiService(response: jsonResponse);

          final result = await mockAi.evaluateStroke(
            canvasImage: dummyCanvasImage,
          );

          expect(result, isNotNull);
          expect(result!['error'], contains('FormatException'));
          expect(result['rawResponse'], equals('N/A'));
        },
      );

      test('returns null when parsed JSON is not a Map', () async {
        const jsonResponse = '["keep", "good"]';
        final mockAi = TestMockAiService(response: jsonResponse);

        final result = await mockAi.evaluateStroke(
          canvasImage: dummyCanvasImage,
        );

        expect(result, isNull);
      });

      test('returns null when underlying call returns null', () {
        fakeAsync((async) {
          final mockAi = TestMockAiService(response: null);
          Map<String, dynamic>? result;
          bool completed = false;

          mockAi.evaluateStroke(canvasImage: dummyCanvasImage).then((val) {
            result = val;
            completed = true;
          });

          async.elapse(const Duration(seconds: 10));

          expect(completed, isTrue);
          expect(result, isNull);
        });
      });

      test(
        'catches thrown exception from underlying call and returns error map',
        () {
          fakeAsync((async) {
            final mockAi = TestMockAiService(
              shouldThrow: true,
              exceptionMessage: 'Connection failed',
            );
            Map<String, dynamic>? result;
            bool completed = false;

            mockAi.evaluateStroke(canvasImage: dummyCanvasImage).then((val) {
              result = val;
              completed = true;
            });

            async.elapse(const Duration(seconds: 10));

            expect(completed, isTrue);
            expect(result, isNotNull);
            expect(result!['error'], contains('Connection failed'));
            expect(result!['rawResponse'], equals('N/A'));
          });
        },
      );
    });

    group('evaluateCandidates', () {
      test('passes text-only prompt and parses valid evaluation JSON', () async {
        const jsonResponse =
            '{"choice": 2, "reasoning": "better colors", "nextFocus": "outline"}';
        final mockAi = TestMockAiService(response: jsonResponse);

        final result = await mockAi.evaluateCandidates(
          userPrompt: 'Draw a dragon',
          referenceDescription: 'Red dragon',
          startingCanvasDescription: 'Empty',
          candidate1Description: 'Candidate 1',
          candidate2Description: 'Candidate 2',
          candidate3Description: 'Candidate 3',
        );

        expect(result, isNotNull);
        expect(result!['choice'], equals(2));
        expect(result['reasoning'], equals('better colors'));
        expect(result['nextFocus'], equals('outline'));
        expect(mockAi.capturedImageBytes.first, isNull);
        expect(mockAi.capturedPrompts.first, contains('Draw a dragon'));
        expect(mockAi.capturedPrompts.first, contains('Red dragon'));
      });

      test('strips markdown code blocks in evaluateCandidates', () async {
        const jsonResponse =
            '```json\n{"choice": 1, "reasoning": "accurate", "nextFocus": "shading"}\n```';
        final mockAi = TestMockAiService(response: jsonResponse);

        final result = await mockAi.evaluateCandidates(
          userPrompt: 'Draw a dragon',
          referenceDescription: 'Red dragon',
          startingCanvasDescription: 'Empty',
          candidate1Description: 'Candidate 1',
          candidate2Description: 'Candidate 2',
          candidate3Description: 'Candidate 3',
        );

        expect(result, isNotNull);
        expect(result!['choice'], equals(1));
        expect(result['reasoning'], equals('accurate'));
      });

      test('returns error map when response contains error payload', () async {
        const jsonResponse = '{\n  "error" : "model quota reached"\n}';
        final mockAi = TestMockAiService(response: jsonResponse);

        final result = await mockAi.evaluateCandidates(
          userPrompt: 'test',
          referenceDescription: 'ref',
          startingCanvasDescription: 'start',
          candidate1Description: 'c1',
          candidate2Description: 'c2',
          candidate3Description: 'c3',
        );

        expect(result, isNotNull);
        expect(result!['error'], equals('model quota reached'));
        expect(result['rawResponse'], equals(jsonResponse));
      });

      test(
        'catches malformed JSON and returns formatted error map with rawResponse N/A',
        () async {
          const jsonResponse = '{invalid_json: 123}';
          final mockAi = TestMockAiService(response: jsonResponse);

          final result = await mockAi.evaluateCandidates(
            userPrompt: 'test',
            referenceDescription: 'ref',
            startingCanvasDescription: 'start',
            candidate1Description: 'c1',
            candidate2Description: 'c2',
            candidate3Description: 'c3',
          );

          expect(result, isNotNull);
          expect(result!['error'], contains('FormatException'));
          expect(result['rawResponse'], equals('N/A'));
        },
      );

      test('returns null when parsed JSON is not a Map', () async {
        const jsonResponse = '[1, 2, 3]';
        final mockAi = TestMockAiService(response: jsonResponse);

        final result = await mockAi.evaluateCandidates(
          userPrompt: 'test',
          referenceDescription: 'ref',
          startingCanvasDescription: 'start',
          candidate1Description: 'c1',
          candidate2Description: 'c2',
          candidate3Description: 'c3',
        );

        expect(result, isNull);
      });

      test('returns null when underlying call returns null', () {
        fakeAsync((async) {
          final mockAi = TestMockAiService(response: null);
          Map<String, dynamic>? result;
          bool completed = false;

          mockAi
              .evaluateCandidates(
                userPrompt: 'test',
                referenceDescription: 'ref',
                startingCanvasDescription: 'start',
                candidate1Description: 'c1',
                candidate2Description: 'c2',
                candidate3Description: 'c3',
              )
              .then((val) {
                result = val;
                completed = true;
              });

          async.elapse(const Duration(seconds: 10));

          expect(completed, isTrue);
          expect(result, isNull);
        });
      });

      test('catches thrown exception and returns error map', () {
        fakeAsync((async) {
          final mockAi = TestMockAiService(
            shouldThrow: true,
            exceptionMessage: 'Timeout',
          );
          Map<String, dynamic>? result;
          bool completed = false;

          mockAi
              .evaluateCandidates(
                userPrompt: 'test',
                referenceDescription: 'ref',
                startingCanvasDescription: 'start',
                candidate1Description: 'c1',
                candidate2Description: 'c2',
                candidate3Description: 'c3',
              )
              .then((val) {
                result = val;
                completed = true;
              });

          async.elapse(const Duration(seconds: 10));

          expect(completed, isTrue);
          expect(result, isNotNull);
          expect(result!['error'], contains('Timeout'));
          expect(result!['rawResponse'], equals('N/A'));
        });
      });
    });

    group('generateContentWithRetry', () {
      test(
        'returns response immediately on first successful attempt',
        () async {
          final mockAi = TestMockAiService(response: 'instant success.');

          final result = await mockAi.generateContentWithRetry(
            prompt: 'test prompt',
            imageBytes: dummyCanvasImage,
            temperature: 0.1,
          );

          expect(result, equals('instant success.'));
          expect(mockAi.callCount, equals(1));
        },
      );

      test('retries on error payload and succeeds on next attempt', () {
        fakeAsync((async) {
          final mockAi = TestMockAiService(
            responses: [
              '{"error": "rate limit exceeded"}',
              'Success after retry.',
            ],
          );

          String? result;
          bool completed = false;

          mockAi
              .generateContentWithRetry(
                prompt: 'test',
                imageBytes: null,
                temperature: 0.1,
              )
              .then((val) {
                result = val;
                completed = true;
              });

          // Attempt 1 fails immediately, then waits 1000ms.
          expect(mockAi.callCount, equals(1));
          expect(completed, isFalse);

          async.elapse(const Duration(milliseconds: 1000));

          expect(completed, isTrue);
          expect(result, equals('Success after retry.'));
          expect(mockAi.callCount, equals(2));
        });
      });

      test('retries when underlying service throws exception and recovers', () {
        fakeAsync((async) {
          int call = 0;
          final mockAi = TestMockAiService(
            onGenerateContentRaw:
                ({
                  required String prompt,
                  Uint8List? imageBytes,
                  double? temperature,
                  int? maxOutputTokens,
                }) {
                  call++;
                  if (call == 1) throw Exception('Temporary network glitch');
                  return AiResponse(text: 'Glitch recovered.');
                },
          );

          String? result;
          bool completed = false;

          mockAi
              .generateContentWithRetry(
                prompt: 'test',
                imageBytes: null,
                temperature: 0.1,
              )
              .then((val) {
                result = val;
                completed = true;
              });

          expect(mockAi.callCount, equals(1));
          expect(completed, isFalse);

          async.elapse(const Duration(milliseconds: 1000));

          expect(completed, isTrue);
          expect(result, equals('Glitch recovered.'));
          expect(mockAi.callCount, equals(2));
        });
      });

      test('rethrows exception when max retries exceeded on error blocks', () {
        fakeAsync((async) {
          final mockAi = TestMockAiService(
            responses: [
              '{"error": "fail 1"}',
              '{"error": "fail 2"}',
              '{"error": "fail 3"}',
            ],
          );

          Object? caughtError;
          bool completed = false;

          mockAi
              .generateContentWithRetry(
                prompt: 'test',
                imageBytes: null,
                temperature: 0.1,
                maxRetries: 3,
              )
              .catchError((e) {
                caughtError = e;
                completed = true;
                return null;
              });

          // Attempt 1: immediate. Wait 1000ms.
          async.elapse(const Duration(milliseconds: 1000));
          // Attempt 2: at 1000ms. Wait 2000ms.
          async.elapse(const Duration(milliseconds: 2000));

          expect(completed, isTrue);
          expect(caughtError, isA<Exception>());
          expect(caughtError.toString(), contains('fail 3'));
          expect(mockAi.callCount, equals(3));
        });
      });

      test(
        'rethrows exception when max retries exceeded on service exceptions',
        () {
          fakeAsync((async) {
            final mockAi = TestMockAiService(
              shouldThrow: true,
              exceptionMessage: 'Fatal API error',
            );

            Object? caughtError;
            bool completed = false;

            mockAi
                .generateContentWithRetry(
                  prompt: 'test',
                  imageBytes: null,
                  temperature: 0.1,
                  maxRetries: 3,
                )
                .catchError((e) {
                  caughtError = e;
                  completed = true;
                  return null;
                });

            // Attempt 1 (0ms) -> delay 1000ms -> Attempt 2 (1000ms) -> delay 2000ms -> Attempt 3 (3000ms)
            async.elapse(const Duration(milliseconds: 3000));

            expect(completed, isTrue);
            expect(caughtError, isA<Exception>());
            expect(caughtError.toString(), contains('Fatal API error'));
            expect(mockAi.callCount, equals(3));
          });
        },
      );

      test(
        'returns null when model returns null on all attempts without throwing',
        () {
          fakeAsync((async) {
            final mockAi = TestMockAiService(response: null);

            String? result;
            bool completed = false;

            mockAi
                .generateContentWithRetry(
                  prompt: 'test',
                  imageBytes: null,
                  temperature: 0.1,
                  maxRetries: 3,
                )
                .then((val) {
                  result = val;
                  completed = true;
                });

            // Attempt 1 (0ms) -> delay 1000ms -> Attempt 2 (1000ms) -> delay 2000ms -> Attempt 3 (3000ms) -> delay 4000ms -> finish (7000ms)
            async.elapse(const Duration(milliseconds: 7000));

            expect(completed, isTrue);
            expect(result, isNull);
            expect(mockAi.callCount, equals(3));
          });
        },
      );

      test('verifies exponential backoff timing increments', () {
        fakeAsync((async) {
          final mockAi = TestMockAiService(
            responses: [
              '{"error": "delay test 1"}',
              '{"error": "delay test 2"}',
              'Final success.',
            ],
          );

          String? result;
          bool completed = false;

          mockAi
              .generateContentWithRetry(
                prompt: 'test',
                imageBytes: null,
                temperature: 0.1,
                maxRetries: 3,
              )
              .then((val) {
                result = val;
                completed = true;
              });

          // Attempt 1 at t=0ms
          expect(mockAi.callCount, equals(1));

          // At t=500ms, attempt 2 should not have run yet (delay is 1000ms)
          async.elapse(const Duration(milliseconds: 500));
          expect(mockAi.callCount, equals(1));

          // At t=1000ms, attempt 2 executes
          async.elapse(const Duration(milliseconds: 500));
          expect(mockAi.callCount, equals(2));

          // Attempt 2 fails, delay is now 2000ms. At t=2000ms (1000ms after attempt 2), attempt 3 should not have run yet
          async.elapse(const Duration(milliseconds: 1000));
          expect(mockAi.callCount, equals(2));

          // At t=3000ms (2000ms after attempt 2), attempt 3 executes and succeeds
          async.elapse(const Duration(milliseconds: 1000));
          expect(mockAi.callCount, equals(3));
          expect(completed, isTrue);
          expect(result, equals('Final success.'));
        });
      });
    });
  });
}
