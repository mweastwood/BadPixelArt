import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/ai_service.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/agent_harness.dart';
import 'package:bad_pixel_art/logic/pixel_art_agent_delegate.dart';

class MockAiService implements AiService {
  final List<Map<String, dynamic>> responses;
  int callCount = 0;
  final List<String> capturedPrompts = [];

  MockAiService(this.responses);

  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    bool lowTemperature = false,
  }) async {
    capturedPrompts.add(prompt);
    if (callCount < responses.length) {
      return jsonEncode(responses[callCount++]);
    }
    return jsonEncode({'tool': 'finish', 'reasoning': 'Done'});
  }
}

class MockAgentCanvas implements AgentCanvas {
  @override
  final List<List<int>> grid = List.generate(64, (_) => List.filled(64, 0));

  @override
  final List<Color> palette = [
    const Color(0xFF000000),
    const Color(0xFFFFFFFF),
    const Color(0xFFFF0000),
  ];

  final List<String> commandsApplied = [];

  @override
  void applyCommand(String toolName, List<int> params, int colorIndex) {
    commandsApplied.add('$toolName:$params:$colorIndex');
  }

  @override
  Uint8List generateCombinedVisualInput(
    Uint8List? referenceBmp,
    Uint8List? previousBmp,
  ) {
    return Uint8List.fromList([1, 2, 3]);
  }
}

class MockTextAgentDelegate implements AgentDelegate {
  int counter = 0;
  final List<String> actionsApplied = [];

  @override
  String formatPrompt(String userPrompt, List<AgentStepResult> history) {
    final buffer = StringBuffer();
    buffer.write('Prompt: $userPrompt. History:');
    for (var res in history) {
      buffer.write(' [${res.tool}:${res.feedback}]');
    }
    return buffer.toString();
  }

  @override
  Uint8List? getVisualInput() => null;

  @override
  Future<String> applyAction(Map<String, dynamic> actionMap) async {
    final action = actionMap['action'] as String? ?? '';
    actionsApplied.add(action);
    if (action == 'increment') {
      counter++;
      return 'Counter is now $counter';
    }
    return 'Unknown action';
  }

  @override
  bool isFinishAction(Map<String, dynamic> actionMap) {
    return actionMap['action'] == 'stop';
  }
}

void main() {
  group('AgentHarness ReAct Loop Tests', () {
    test('harness executes drawing steps and updates canvas', () async {
      final mockAi = MockAiService([
        {
          'understanding': 'drawing body',
          'tool': 'rectangle_filled',
          'params': [10, 10, 20, 20],
          'color': 2,
        },
        {
          'understanding': 'drawing head',
          'tool': 'circle',
          'params': [15, 5, 4],
          'color': 1,
        },
        {
          'understanding': 'all done',
          'tool': 'finish',
          'params': [],
          'color': 0,
        },
      ]);
      final mockCanvas = MockAgentCanvas();
      final delegate = PixelArtAgentDelegate(
        canvas: mockCanvas,
        referenceImageBmp: null,
        previousCanvasBmp: null,
      );
      final harness = AgentHarness(aiService: mockAi, delegate: delegate);

      final steps = await harness.runDrawingLoop(
        userPrompt: 'draw a stick figure',
        maxSteps: 5,
      );

      // Verify execution steps
      expect(steps.length, equals(3));
      expect(steps[0].tool, equals('rectangle_filled'));
      expect(steps[0].params, equals([10, 10, 20, 20]));
      expect(steps[0].colorIndex, equals(2));
      expect(steps[0].isFinish, isFalse);

      expect(steps[1].tool, equals('circle'));
      expect(steps[1].params, equals([15, 5, 4]));
      expect(steps[1].colorIndex, equals(1));
      expect(steps[1].isFinish, isFalse);

      expect(steps[2].tool, equals('finish'));
      expect(steps[2].isFinish, isTrue);

      // Verify canvas commands applied
      expect(mockCanvas.commandsApplied.length, equals(2));
      expect(
        mockCanvas.commandsApplied[0],
        equals('rectangle_filled:[10, 10, 20, 20]:2'),
      );
      expect(mockCanvas.commandsApplied[1], equals('circle:[15, 5, 4]:1'));
    });

    test('harness stops early on maximum steps limit', () async {
      final mockAi = MockAiService([
        {
          'understanding': 'drawing body',
          'tool': 'rectangle_filled',
          'params': [10, 10, 20, 20],
          'color': 2,
        },
        {
          'understanding': 'drawing head',
          'tool': 'circle',
          'params': [15, 5, 4],
          'color': 1,
        },
      ]);
      final mockCanvas = MockAgentCanvas();
      final delegate = PixelArtAgentDelegate(
        canvas: mockCanvas,
        referenceImageBmp: null,
        previousCanvasBmp: null,
      );
      final harness = AgentHarness(aiService: mockAi, delegate: delegate);

      final steps = await harness.runDrawingLoop(
        userPrompt: 'draw a stick figure',
        maxSteps: 2,
      );

      expect(steps.length, equals(2));
      expect(mockCanvas.commandsApplied.length, equals(2));
    });

    test('harness handles errors gracefully and stops loop', () async {
      final mockAi = MockAiService([
        {'error': 'Aicore model crashed'},
      ]);
      final mockCanvas = MockAgentCanvas();
      final delegate = PixelArtAgentDelegate(
        canvas: mockCanvas,
        referenceImageBmp: null,
        previousCanvasBmp: null,
      );
      final harness = AgentHarness(aiService: mockAi, delegate: delegate);

      final steps = await harness.runDrawingLoop(
        userPrompt: 'draw a stick figure',
      );

      expect(steps.length, equals(1));
      expect(steps[0].isFinish, isTrue);
      expect(steps[0].thought, contains('Aicore model crashed'));
      expect(mockCanvas.commandsApplied.isEmpty, isTrue);
    });

    test('harness appends past action history to prompt in loop', () async {
      final mockAi = MockAiService([
        {
          'understanding': 'step 1 thought',
          'tool': 'line',
          'params': [0, 0, 5, 5],
          'color': 1,
        },
        {
          'understanding': 'step 2 thought',
          'tool': 'finish',
          'params': [],
          'color': 0,
        },
      ]);
      final mockCanvas = MockAgentCanvas();
      final delegate = PixelArtAgentDelegate(
        canvas: mockCanvas,
        referenceImageBmp: null,
        previousCanvasBmp: null,
      );
      final harness = AgentHarness(aiService: mockAi, delegate: delegate);

      await harness.runDrawingLoop(userPrompt: 'draw a line', maxSteps: 2);

      expect(mockAi.capturedPrompts.length, equals(2));
      // Second prompt should contain Step 1 details
      expect(mockAi.capturedPrompts[1], contains('Thoughts: "step 1 thought"'));
      expect(
        mockAi.capturedPrompts[1],
        contains('Action: line with params [0, 0, 5, 5] and color index 1'),
      );
    });

    test(
      'harness executes steps with a completely generic text delegate',
      () async {
        final mockAi = MockAiService([
          {
            'action': 'increment',
            'understanding': 'incrementing count',
            'tool': 'inc',
            'params': [],
            'color': 0,
          },
          {
            'action': 'increment',
            'understanding': 'incrementing count again',
            'tool': 'inc',
            'params': [],
            'color': 0,
          },
          {
            'action': 'stop',
            'understanding': 'done now',
            'tool': 'finish',
            'params': [],
            'color': 0,
          },
        ]);
        final delegate = MockTextAgentDelegate();
        final harness = AgentHarness(aiService: mockAi, delegate: delegate);

        final steps = await harness.runDrawingLoop(
          userPrompt: 'count to 2',
          maxSteps: 5,
        );

        expect(steps.length, equals(3));
        expect(steps[0].tool, equals('inc'));
        expect(steps[0].feedback, equals('Counter is now 1'));
        expect(steps[0].isFinish, isFalse);

        expect(steps[1].tool, equals('inc'));
        expect(steps[1].feedback, equals('Counter is now 2'));
        expect(steps[1].isFinish, isFalse);

        expect(steps[2].isFinish, isTrue);

        expect(delegate.counter, equals(2));
        expect(delegate.actionsApplied, equals(['increment', 'increment']));
      },
    );
  });
}
