import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/ai_service.dart';

void main() {
  group('AI Service Shared Prompt Formatting Helpers', () {
    test('formatSystemInstruction returns correct rules and tools', () {
      final sysInstruction = formatSystemInstruction();
      expect(sysInstruction, contains('AI pixel art assistant'));
      expect(sysInstruction, contains('64x64 grid'));
      expect(sysInstruction, contains('"line"'));
      expect(sysInstruction, contains('"circle"'));
      expect(sysInstruction, contains('"fill"'));
      expect(sysInstruction, contains('"hatch"'));
      expect(sysInstruction, contains('output EXACTLY a valid JSON block'));
    });

    test('formatUserPrompt formats empty canvas correctly', () {
      final canvasImage = Uint8List.fromList(utf8.encode('00000000'));
      final prompt = 'draw a line';
      final paletteColors = ['#000000', '#ffffff', '#ff0000'];

      final userPrompt = formatUserPrompt(
        referenceImage: null,
        canvasImage: canvasImage,
        prompt: prompt,
        paletteColors: paletteColors,
      );

      expect(userPrompt, contains('User Instruction: "draw a line"'));
      expect(userPrompt, contains('The grid is completely empty (all 0s).'));
      expect(userPrompt, contains('Available Color Palette'));
      expect(userPrompt, contains('- Index 0: #000000'));
      expect(userPrompt, contains('- Index 2: #ff0000'));
    });

    test('formatUserPrompt formats active canvas correctly', () {
      final canvasImage = Uint8List.fromList(utf8.encode('01002000'));
      final prompt = 'draw a circle';
      final paletteColors = ['#000000', '#ffffff', '#ff0000', '#00ff00'];

      final userPrompt = formatUserPrompt(
        referenceImage: null,
        canvasImage: canvasImage,
        prompt: prompt,
        paletteColors: paletteColors,
      );

      expect(userPrompt, contains('User Instruction: "draw a circle"'));
      expect(userPrompt, isNot(contains('The grid is completely empty')));
      expect(userPrompt, contains('01002000'));
      expect(userPrompt, contains('Available Color Palette'));
      expect(userPrompt, contains('- Index 0: #000000'));
      expect(userPrompt, contains('- Index 3: #00ff00'));
    });

    test('formatUserPrompt includes Heart shape reference instructions', () {
      final canvasImage = Uint8List.fromList(utf8.encode('00000000'));
      final referenceImage = Uint8List.fromList(
        utf8.encode('Heart shape reference'),
      );
      final prompt = 'draw a heart';
      final paletteColors = ['#000000', '#ffffff'];

      final userPrompt = formatUserPrompt(
        referenceImage: referenceImage,
        canvasImage: canvasImage,
        prompt: prompt,
        paletteColors: paletteColors,
      );

      expect(userPrompt, contains('The user wants to draw a Heart.'));
    });

    test('formatUserPrompt includes Sword shape reference instructions', () {
      final canvasImage = Uint8List.fromList(utf8.encode('00000000'));
      final referenceImage = Uint8List.fromList(
        utf8.encode('Sword shape reference'),
      );
      final prompt = 'draw a sword';
      final paletteColors = ['#000000', '#ffffff'];

      final userPrompt = formatUserPrompt(
        referenceImage: referenceImage,
        canvasImage: canvasImage,
        prompt: prompt,
        paletteColors: paletteColors,
      );

      expect(userPrompt, contains('The user wants to draw a Sword.'));
    });
  });
}
