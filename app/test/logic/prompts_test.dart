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
}
