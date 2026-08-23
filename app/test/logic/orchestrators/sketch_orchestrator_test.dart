import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/orchestrators/sketch_orchestrator.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';
import '../../test_helper.dart';

void main() {
  group('SketchOrchestrator Unit Tests', () {
    test(
      'isComponentDone returns true when evaluator approves and edges touch bounds',
      () {
        final aiService = TestMockAiService(response: '{}');
        final orchestrator = SketchOrchestrator(aiService);

        final grid = List.generate(
          8,
          (y) => List.generate(
            8,
            (x) => (x >= 1 && x <= 6 && y >= 1 && y <= 6) ? 1 : 0,
          ),
        );
        final comp = PixelArtComponent(
          name: 'Head',
          description: 'Robot head',
          relativeBoundingBox: const Rect.fromLTWH(0.125, 0.125, 0.75, 0.75),
          shapes: const [],
          grid: grid,
        );

        expect(orchestrator.isComponentDone(grid, comp, 8, true), isTrue);
        expect(orchestrator.isComponentDone(grid, comp, 8, false), isFalse);
      },
    );

    test(
      'sketch orchestrates components sculpting and updates components',
      () async {
        final aiService = TestMockAiService(
          responses: [
            '{"thought": "sculpt head", "tool": "apply_rectangle_filled", "params": [1, 1, 3, 3], "isComplete": true}',
            '{"thought": "sculpt body", "tool": "apply_rectangle_filled", "params": [4, 4, 6, 6], "isComplete": true}',
          ],
          tokenCount: 15,
        );
        final orchestrator = SketchOrchestrator(aiService);

        final comp1 = PixelArtComponent(
          name: 'Head',
          description: 'Head component',
          relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 0.5, 0.5),
          shapes: const [],
          grid: List.generate(8, (_) => List.filled(8, 0)),
        );
        final comp2 = PixelArtComponent(
          name: 'Body',
          description: 'Body component',
          relativeBoundingBox: const Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
          shapes: const [],
          grid: List.generate(8, (_) => List.filled(8, 0)),
        );

        final history = <AgentHistoryEntry>[];
        final stepRecords = <List<PixelArtComponent>>[];

        final result = await orchestrator.sketch(
          components: [comp1, comp2],
          gridSize: 8,
          palette: [Colors.black, Colors.red, Colors.green, Colors.blue],
          userPrompt: 'a robot character',
          autoRunSpeed: 0.001,
          onStep: (idx, updated, status) {
            stepRecords.add(List.from(updated));
          },
          onLogHistory: (log) {
            history.add(log);
          },
        );

        expect(result.length, equals(2));
        expect(result[0].isSculpted, isTrue);
        expect(result[1].isSculpted, isTrue);
        expect(stepRecords, isNotEmpty);
      },
    );

    test(
      'sketch logs error AgentHistoryEntry with isError: true and propagates exception when AI throws',
      () async {
        final aiService = TestMockAiService(
          shouldThrow: true,
          exceptionMessage: 'Quota exceeded',
        );
        final orchestrator = SketchOrchestrator(aiService);

        final comp = PixelArtComponent(
          name: 'Head',
          description: 'Head component',
          relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 0.5, 0.5),
          shapes: const [],
          grid: List.generate(8, (_) => List.filled(8, 0)),
        );

        final history = <AgentHistoryEntry>[];

        await expectLater(
          () => orchestrator.sketch(
            components: [comp],
            gridSize: 8,
            palette: [Colors.black, Colors.red],
            userPrompt: 'a robot character',
            autoRunSpeed: 0.001,
            onStep: (idx, updated, status) {},
            onLogHistory: (log) {
              history.add(log);
            },
          ),
          throwsA(isA<Exception>()),
        );

        expect(history, hasLength(1));
        expect(history.first.isError, isTrue);
        expect(history.first.response, contains('Quota exceeded'));
      },
    );

    test(
      'sketch logs error AgentHistoryEntry with isError: true and throws FormatException on malformed JSON',
      () async {
        final aiService = TestMockAiService(response: 'invalid non-json text');
        final orchestrator = SketchOrchestrator(aiService);

        final comp = PixelArtComponent(
          name: 'Head',
          description: 'Head component',
          relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 0.5, 0.5),
          shapes: const [],
          grid: List.generate(8, (_) => List.filled(8, 0)),
        );

        final history = <AgentHistoryEntry>[];

        await expectLater(
          () => orchestrator.sketch(
            components: [comp],
            gridSize: 8,
            palette: [Colors.black, Colors.red],
            userPrompt: 'a robot character',
            autoRunSpeed: 0.001,
            onStep: (idx, updated, status) {},
            onLogHistory: (log) {
              history.add(log);
            },
          ),
          throwsA(isA<FormatException>()),
        );

        expect(history, hasLength(1));
        expect(history.first.isError, isTrue);
      },
    );

    test(
      'sketch gracefully handles null and malformed coordinates in add and erase without throwing TypeError',
      () async {
        final aiService = TestMockAiService(
          response: jsonEncode({
            'thought': 'sculpt with invalid and valid coords',
            'tool': '',
            'params': [1, null, 'invalid'],
            'add': [
              [null, 2],
              [2, null],
              ['invalid', 3],
              {'x': null, 'y': 2},
              {'x': 1, 'y': null},
              [2, 2],
              {'x': 1, 'y': 1},
              ['3', '3'],
            ],
            'erase': [
              [null, 1],
              ['bad', 'coords'],
              {'x': 1, 'y': null},
              {'x': null, 'y': 1},
              [1, 1],
            ],
            'isComplete': true,
          }),
        );
        final orchestrator = SketchOrchestrator(aiService);

        final comp = PixelArtComponent(
          name: 'Shape',
          description: 'Shape component',
          relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
          shapes: const [],
          grid: List.generate(8, (_) => List.filled(8, 0)),
        );

        final history = <AgentHistoryEntry>[];
        final results = await orchestrator.sketch(
          components: [comp],
          gridSize: 8,
          palette: [Colors.black, Colors.red],
          userPrompt: 'test prompt',
          autoRunSpeed: 0.001,
          onStep: (idx, updated, status) {},
          onLogHistory: (log) {
            history.add(log);
          },
        );

        expect(results, hasLength(1));
        expect(results.first.isSculpted, isTrue);
        final updatedGrid = results.first.grid!;
        // Valid additions (2, 2) and (3, 3) should be set to 1
        expect(updatedGrid[2][2], equals(1));
        expect(updatedGrid[3][3], equals(1));
        // (1, 1) was added and then erased back to 0
        expect(updatedGrid[1][1], equals(0));
        // Out-of-bounds or null coords should be ignored
        expect(updatedGrid[0][0], equals(0));
        expect(history.isEmpty || history.every((h) => !h.isError), isTrue);
      },
    );

    test('sketchSingleComponent sculpts only target component index', () async {
      final aiService = TestMockAiService(
        responses: [
          '{"thought": "sculpt body", "tool": "apply_rectangle_filled", "params": [4, 4, 6, 6], "isComplete": true}',
        ],
        tokenCount: 15,
      );
      final orchestrator = SketchOrchestrator(aiService);

      final comp1 = PixelArtComponent(
        name: 'Head',
        description: 'Head component',
        relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 0.5, 0.5),
        shapes: const [],
        grid: List.generate(8, (_) => List.filled(8, 0)),
      );
      final comp2 = PixelArtComponent(
        name: 'Body',
        description: 'Body component',
        relativeBoundingBox: const Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
        shapes: const [],
        grid: List.generate(8, (_) => List.filled(8, 0)),
      );

      final history = <AgentHistoryEntry>[];
      final result = await orchestrator.sketchSingleComponent(
        components: [comp1, comp2],
        targetIndex: 1,
        gridSize: 8,
        palette: [Colors.black, Colors.red],
        userPrompt: 'a robot character',
        autoRunSpeed: 0.001,
        onStep: (idx, updated, status) {},
        onLogHistory: (log) => history.add(log),
      );

      expect(result[0].isSculpted, isFalse);
      expect(result[1].isSculpted, isTrue);
      expect(aiService.callCount, equals(1));
    });

    test('sketch records out-of-bounds warnings in step history feedback', () async {
      final aiService = TestMockAiService(
        responses: [
          // Coordinate (10, 10) is outside the 8x8 grid bounds
          '{"thought": "sculpt with oob coords", "tool": "", "params": [], "add": [[10, 10]], "erase": [[9, 9]], "isComplete": false}',
          '{"thought": "done", "tool": "", "params": [], "add": [], "erase": [], "isComplete": true}',
        ],
        tokenCount: 15,
      );
      final orchestrator = SketchOrchestrator(aiService);

      final comp = PixelArtComponent(
        name: 'Head',
        description: 'Head component',
        relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 0.5, 0.5),
        shapes: const [],
        grid: List.generate(8, (_) => List.filled(8, 0)),
      );

      await orchestrator.sketchSingleComponent(
        components: [comp],
        targetIndex: 0,
        gridSize: 8,
        palette: [Colors.black, Colors.red],
        userPrompt: 'a robot character',
        autoRunSpeed: 0.001,
        onStep: (idx, updated, status) {},
        onLogHistory: (log) {},
      );

      expect(aiService.callCount, equals(2));
      // Second prompt sent to AI must contain the out-of-bounds warning feedback from turn 1
      expect(aiService.capturedPrompts.last, contains('WARNING:'));
      expect(aiService.capturedPrompts.last, contains('OUT OF BOUNDS'));
    });

    test(
      'sketch skips already sculpted components and only sculpts incomplete ones',
      () async {
        final aiService = TestMockAiService(
          responses: [
            '{"thought": "sculpt body", "tool": "apply_rectangle_filled", "params": [4, 4, 6, 6], "isComplete": true}',
          ],
          tokenCount: 15,
        );
        final orchestrator = SketchOrchestrator(aiService);

        final alreadySculptedHead = PixelArtComponent(
          name: 'Head',
          description: 'Head component',
          relativeBoundingBox: const Rect.fromLTWH(0.0, 0.0, 0.5, 0.5),
          shapes: const [],
          isSculpted: true,
          grid: List.generate(8, (_) => List.filled(8, 1)),
        );
        final unsculptedBody = PixelArtComponent(
          name: 'Body',
          description: 'Body component',
          relativeBoundingBox: const Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
          shapes: const [],
          isSculpted: false,
          grid: null,
        );

        final result = await orchestrator.sketch(
          components: [alreadySculptedHead, unsculptedBody],
          gridSize: 8,
          palette: [Colors.black, Colors.red],
          userPrompt: 'a robot character',
          autoRunSpeed: 0.001,
          onStep: (idx, updated, status) {},
          onLogHistory: (log) {},
        );

        expect(result.length, equals(2));
        expect(result[0].isSculpted, isTrue);
        expect(result[0].grid![0][0], equals(1)); // Untouched
        expect(result[1].isSculpted, isTrue);
        expect(
          aiService.callCount,
          equals(1),
        ); // Only called for unsculptedBody!
      },
    );
  });
}
