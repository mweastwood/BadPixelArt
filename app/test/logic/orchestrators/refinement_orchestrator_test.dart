import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/orchestrators/refinement_orchestrator.dart';
import '../../test_helper.dart';

void main() {
  group('RefinementOrchestrator Unit Tests', () {
    test('refine executes drawing commands and logs history', () async {
      final aiService = TestMockAiService(
        responses: [
          '{"thought": "add gold highlight", "tool": "pixel", "params": [1, 1], "colorIndex": 2}',
        ],
        tokenCount: 10,
      );
      final orchestrator = RefinementOrchestrator(aiService);

      final grid = List.generate(8, (_) => List.filled(8, 0));
      final palette = [Colors.red, Colors.green, Colors.blue];
      final history = <AgentHistoryEntry>[];

      final result = await orchestrator.refine(
        initialGrid: grid,
        gridSize: 8,
        palette: palette,
        userPrompt: 'add highlights',
        autoRunSpeed: 0.01, // fast delay
        onStep: (updated) {},
        onLogHistory: (entry) => history.add(entry),
      );

      // Verify command drawn: pixel at (1, 1) with colorIndex 2
      expect(result[1][1], equals(2));
      expect(history, hasLength(1));
      expect(history.first.response, contains('add gold highlight'));
    });

    test(
      'refine handles colorIndex decoded as double without type error',
      () async {
        final aiService = TestMockAiService(
          responses: [
            '{"thought": "add blue pixel", "tool": "pixel", "params": [2, 3], "colorIndex": 2.0}',
          ],
          tokenCount: 10,
        );
        final orchestrator = RefinementOrchestrator(aiService);

        final grid = List.generate(8, (_) => List.filled(8, 0));
        final palette = [Colors.red, Colors.green, Colors.blue];
        final history = <AgentHistoryEntry>[];

        final result = await orchestrator.refine(
          initialGrid: grid,
          gridSize: 8,
          palette: palette,
          userPrompt: 'add blue detail',
          autoRunSpeed: 0.01,
          onStep: (updated) {},
          onLogHistory: (entry) => history.add(entry),
        );

        // Verify command drawn: pixel at (x=2, y=3) with colorIndex 2
        expect(result[3][2], equals(2));
        expect(history, hasLength(1));
        expect(history.first.response, contains('add blue pixel'));
      },
    );

    test(
      'refine logs error AgentHistoryEntry with isError: true and propagates exception on AI error',
      () async {
        final aiService = TestMockAiService(
          shouldThrow: true,
          exceptionMessage: 'Network error',
        );
        final orchestrator = RefinementOrchestrator(aiService);

        final grid = List.generate(8, (_) => List.filled(8, 0));
        final palette = [Colors.red, Colors.green, Colors.blue];
        final history = <AgentHistoryEntry>[];

        await expectLater(
          () => orchestrator.refine(
            initialGrid: grid,
            gridSize: 8,
            palette: palette,
            userPrompt: 'add highlights',
            autoRunSpeed: 0.01,
            onStep: (updated) {},
            onLogHistory: (entry) => history.add(entry),
          ),
          throwsA(isA<Exception>()),
        );

        expect(history, hasLength(1));
        expect(history.first.isError, isTrue);
        expect(history.first.response, contains('Network error'));
      },
    );

    test(
      'refine logs error AgentHistoryEntry with isError: true and throws FormatException on invalid JSON',
      () async {
        final aiService = TestMockAiService(response: 'not valid json');
        final orchestrator = RefinementOrchestrator(aiService);

        final grid = List.generate(8, (_) => List.filled(8, 0));
        final palette = [Colors.red, Colors.green, Colors.blue];
        final history = <AgentHistoryEntry>[];

        await expectLater(
          () => orchestrator.refine(
            initialGrid: grid,
            gridSize: 8,
            palette: palette,
            userPrompt: 'add highlights',
            autoRunSpeed: 0.01,
            onStep: (updated) {},
            onLogHistory: (entry) => history.add(entry),
          ),
          throwsA(isA<FormatException>()),
        );

        expect(history, hasLength(1));
        expect(history.first.isError, isTrue);
      },
    );
  });
}
