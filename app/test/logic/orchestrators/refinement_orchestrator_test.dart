import 'dart:typed_data';
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

    test('refine terminates early when agent returns tool: done', () async {
      final aiService = TestMockAiService(
        responses: [
          '{"thought": "add gold highlight", "tool": "pixel", "params": [1, 1], "colorIndex": 2}',
          '{"thought": "The pixel art has clean highlights; finished.", "tool": "done", "params": [], "colorIndex": 0}',
          '{"thought": "should not be called", "tool": "pixel", "params": [0, 0], "colorIndex": 1}',
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
        autoRunSpeed: 0.01,
        onStep: (updated) {},
        onLogHistory: (entry) => history.add(entry),
      );

      // Only 2 calls should have been made before early termination
      expect(aiService.callCount, equals(2));
      expect(result[1][1], equals(2));
      expect(history, hasLength(2));
      expect(
        history.last.response,
        contains('Refinement completed: artwork is finalized.'),
      );
    });

    test(
      'refine terminates early when agent returns tool: none or empty tool',
      () async {
        final aiService = TestMockAiService(
          responses: [
            '{"thought": "Artwork looks complete.", "tool": "none", "params": [], "colorIndex": 0}',
          ],
          tokenCount: 10,
        );
        final orchestrator = RefinementOrchestrator(aiService);

        final grid = List.generate(8, (_) => List.filled(8, 0));
        final palette = [Colors.red, Colors.green, Colors.blue];
        final history = <AgentHistoryEntry>[];

        await orchestrator.refine(
          initialGrid: grid,
          gridSize: 8,
          palette: palette,
          userPrompt: 'add highlights',
          autoRunSpeed: 0.01,
          onStep: (updated) {},
          onLogHistory: (entry) => history.add(entry),
        );

        expect(aiService.callCount, equals(1));
        expect(
          history.last.response,
          contains('Refinement completed: artwork is finalized.'),
        );
      },
    );

    test(
      'refine passes rendered imageBytes to aiService on each step',
      () async {
        final aiService = TestMockAiService(
          responses: [
            '{"thought": "done", "tool": "done", "params": [], "colorIndex": 0}',
          ],
          tokenCount: 10,
        );
        final orchestrator = RefinementOrchestrator(aiService);

        final grid = List.generate(8, (_) => List.filled(8, 0));
        final palette = [Colors.red, Colors.green, Colors.blue];

        await orchestrator.refine(
          initialGrid: grid,
          gridSize: 8,
          palette: palette,
          userPrompt: 'refine',
          autoRunSpeed: 0.01,
          onStep: (updated) {},
          onLogHistory: (_) {},
        );

        expect(aiService.capturedImageBytes.last, isNotNull);
        expect(aiService.capturedImageBytes.last!.length, greaterThan(0));
      },
    );

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
      'refine handles params and colorIndex decoded as strings or with nulls without type error',
      () async {
        final aiService = TestMockAiService(
          responses: [
            '{"thought": "add green dot", "tool": "pixel", "params": ["4", "5", null, "invalid"], "colorIndex": "3"}',
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
          userPrompt: 'add green detail',
          autoRunSpeed: 0.01,
          onStep: (updated) {},
          onLogHistory: (entry) => history.add(entry),
        );

        // Pixel at (x=4, y=5) drawn with colorIndex 3
        expect(result[5][4], equals(3));
        expect(history, hasLength(1));
        expect(history.first.response, contains('add green dot'));
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

    test(
      'refine captures canvas grid visual input and executes drawing actions',
      () async {
        final aiService = TestMockAiService(
          responses: [
            '{"thought": "paint sword matching reference", "tool": "line", "params": [0, 0, 7, 7], "colorIndex": 1}',
            '{"thought": "finished", "tool": "done", "params": [], "colorIndex": 0}',
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
          userPrompt: 'paint sword',
          autoRunSpeed: 0.01,
          referenceImage: Uint8List.fromList([1, 2, 3]),
          onStep: (updated) {},
          onLogHistory: (entry) => history.add(entry),
        );

        expect(result[0][0], equals(1));
        expect(result[7][7], equals(1));
        expect(aiService.capturedImageBytes.isNotEmpty, isTrue);
      },
    );
  });
}
