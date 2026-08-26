import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import 'package:bad_pixel_art/logic/agents/refinement_agent.dart';

void main() {
  group('RefinementAgent Unit Tests', () {
    final agent = RefinementAgent();

    test('name and available tools are correct and constrained', () {
      expect(agent.name, equals('refinement'));
      expect(agent.availableTools, contains('pixel'));
      expect(agent.availableTools, contains('pixels'));
      expect(agent.availableTools, contains('line'));
      expect(agent.availableTools, contains('circle'));
      expect(agent.availableTools, contains('rectangle'));
      expect(agent.availableTools, contains('done'));
      expect(agent.availableTools, contains('none'));

      // Destructive tools should be excluded
      expect(agent.availableTools, isNot(contains('rectangle_filled')));
      expect(agent.availableTools, isNot(contains('fill')));
      expect(agent.availableTools, isNot(contains('circle_filled')));
      expect(agent.availableTools, isNot(contains('ellipse_filled')));
      expect(agent.availableTools, isNot(contains('triangle')));
    });

    test(
      'getSystemInstruction returns valid instruction with simplified termination rules',
      () {
        final context = AgentContext(
          userPrompt: 'sword',
          gridSize: 16,
          currentGrid: List.generate(16, (_) => List.filled(16, 0)),
          activePalette: [const Color(0xFF000000)],
        );

        final instructions = agent.getSystemInstruction(context);
        expect(instructions, contains('refinement'));
        expect(instructions, contains('X: 0 to 15'));
        expect(instructions, contains('TERMINATION'));
        expect(instructions, contains('"tool": "done"'));
      },
    );

    test(
      'getFormattedUserPrompt focuses on description and canvas grid without reference image notes',
      () {
        final context = AgentContext(
          userPrompt: 'shield',
          gridSize: 8,
          currentGrid: List.generate(8, (_) => List.filled(8, 1)),
          activePalette: [const Color(0xFF000000)],
        );

        final prompt = agent.getFormattedUserPrompt(context, []);
        expect(prompt, contains('Drawing Description: "shield"'));
        expect(prompt, isNot(contains('Reference image is provided')));
        expect(prompt, contains('"tool": "done"'));
      },
    );
  });
}
