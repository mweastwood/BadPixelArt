import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import 'package:bad_pixel_art/logic/agents/refinement_agent.dart';

void main() {
  group('RefinementAgent Unit Tests', () {
    final agent = RefinementAgent();

    test('name and available tools are correct', () {
      expect(agent.name, equals('refinement'));
      expect(agent.availableTools, contains('pixel'));
      expect(agent.availableTools, contains('line'));
      expect(agent.availableTools, contains('circle_filled'));
    });

    test('getSystemInstruction returns valid instruction', () {
      final context = AgentContext(
        userPrompt: 'sword',
        gridSize: 16,
        currentGrid: List.generate(16, (_) => List.filled(16, 0)),
        activePalette: [const Color(0xFF000000)],
      );

      final instructions = agent.getSystemInstruction(context);
      expect(instructions, contains('refinement'));
      expect(instructions, contains('X: 0 to 15'));
    });

    test('getFormattedUserPrompt builds correct prompt string', () {
      final context = AgentContext(
        userPrompt: 'shield',
        gridSize: 8,
        currentGrid: List.generate(8, (_) => List.filled(8, 1)),
        activePalette: [const Color(0xFF000000)],
      );

      final prompt = agent.getFormattedUserPrompt(context, []);
      expect(prompt, contains('Overall Prompt: "shield"'));
      expect(prompt, contains('Index 1: Hex #000000'));
    });
  });
}
