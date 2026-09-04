import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/agents/base_agent.dart';
import 'package:bad_pixel_art/logic/pixel_art_agent_delegate.dart';
import 'package:bad_pixel_art/logic/prompts.dart';

class AppliedCommand {
  final String toolName;
  final List<num> params;
  final int colorIndex;

  const AppliedCommand(this.toolName, this.params, this.colorIndex);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppliedCommand &&
          runtimeType == other.runtimeType &&
          toolName == other.toolName &&
          _listEquals(params, other.params) &&
          colorIndex == other.colorIndex;

  @override
  int get hashCode => Object.hash(toolName, Object.hashAll(params), colorIndex);

  static bool _listEquals(List<num> a, List<num> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class FakeAgentCanvas implements AgentCanvas {
  @override
  List<List<int>> grid;

  @override
  List<Color> palette;

  final List<AppliedCommand> appliedCommands = [];
  Uint8List? lastReferenceBmp;
  Uint8List? lastPreviousBmp;
  Uint8List? mockVisualInput;

  FakeAgentCanvas({
    List<List<int>>? grid,
    List<Color>? palette,
    this.mockVisualInput,
  }) : grid = grid ?? List.generate(16, (_) => List.filled(16, 0)),
       palette =
           palette ??
           const [
             Color(0xFF000000),
             Color(0xFFFFFFFF),
             Color(0xFFFF0000),
             Color(0xFF0000FF),
           ];

  @override
  void applyCommand(String toolName, List<num> params, int colorIndex) {
    appliedCommands.add(AppliedCommand(toolName, params, colorIndex));
  }

  @override
  Uint8List generateCombinedVisualInput(
    Uint8List? referenceBmp,
    Uint8List? previousBmp,
  ) {
    lastReferenceBmp = referenceBmp;
    lastPreviousBmp = previousBmp;
    return mockVisualInput ?? Uint8List.fromList([0x42, 0x4D, 0x00, 0x00]);
  }
}

void main() {
  group('PixelArtAgentDelegate Unit Tests', () {
    late FakeAgentCanvas fakeCanvas;
    late Uint8List sample16x16Bmp;

    setUp(() {
      fakeCanvas = FakeAgentCanvas(
        palette: const [
          Color(0xFF000000), // #000000
          Color(0xFF000005), // #000005 (leading zeroes test)
          Color(0xFF0A0B0C), // #0a0b0c (leading zeroes test)
          Color(0xFFFFFFFF), // #ffffff
          Color(0xFFFF0000), // #ff0000
          Color(0xFF00FF00), // #00ff00
          Color(0xFF0000FF), // #0000ff
        ],
      );

      final grid = List.generate(
        16,
        (y) => List.generate(16, (x) => (x + y) % 2 == 0 ? 1 : 2),
      );
      sample16x16Bmp = generateBmp(grid, fakeCanvas.palette);
    });

    group('Constructor Initialization & State', () {
      test('converts palette colors to formatted 6-digit hex strings', () {
        final delegate = PixelArtAgentDelegate(
          canvas: fakeCanvas,
          referenceImageBmp: null,
          previousCanvasBmp: null,
        );

        expect(
          delegate.paletteHexes,
          equals([
            '#000000',
            '#000005',
            '#0a0b0c',
            '#ffffff',
            '#ff0000',
            '#00ff00',
            '#0000ff',
          ]),
        );
      });

      test(
        'quantizes reference image text grid when referenceImageBmp is provided',
        () {
          final delegate = PixelArtAgentDelegate(
            canvas: fakeCanvas,
            referenceImageBmp: sample16x16Bmp,
            previousCanvasBmp: null,
          );

          expect(delegate.quantizedReferenceTextGrid, isNotNull);
          final expectedGrid = getQuantizedIndexGrid(
            sample16x16Bmp,
            fakeCanvas.palette,
          );
          final expectedTextGrid = canvasToTextGrid(expectedGrid);
          expect(delegate.quantizedReferenceTextGrid, equals(expectedTextGrid));
        },
      );

      test(
        'quantizedReferenceTextGrid remains null when referenceImageBmp is null',
        () {
          final delegate = PixelArtAgentDelegate(
            canvas: fakeCanvas,
            referenceImageBmp: null,
            previousCanvasBmp: null,
          );

          expect(delegate.quantizedReferenceTextGrid, isNull);
        },
      );
    });

    group('formatPrompt', () {
      test(
        'assembles full prompt with system instructions and user prompt',
        () {
          fakeCanvas.grid[2][3] = 4;
          final delegate = PixelArtAgentDelegate(
            canvas: fakeCanvas,
            referenceImageBmp: null,
            previousCanvasBmp: null,
          );

          final formattedPrompt = delegate.formatPrompt('draw a red apple', []);

          // System instructions check
          final expectedSysInstruction = formatSystemInstruction();
          expect(formattedPrompt, contains(expectedSysInstruction));

          // User prompt components
          expect(
            formattedPrompt,
            contains('User Instruction: "draw a red apple"'),
          );
          expect(formattedPrompt, contains('Available Color Palette'));
          expect(formattedPrompt, contains('#000000'));
          expect(formattedPrompt, contains('#ff0000'));
          expect(formattedPrompt, contains('CURRENT CANVAS STATE'));
        },
      );

      test('formats multi-turn action history buffer correctly', () {
        final delegate = PixelArtAgentDelegate(
          canvas: fakeCanvas,
          referenceImageBmp: null,
          previousCanvasBmp: null,
        );

        final history = [
          PixelArtStepResult(
            thought: 'Draw an outline circle',
            tool: 'circle',
            params: [8, 8, 5],
            colorIndex: 3,
            feedback:
                'Executed circle with params [8, 8, 5] and color index 3.',
          ),
          PixelArtStepResult(
            thought: 'Fill the circle center',
            tool: 'fill',
            params: [8, 8],
            colorIndex: 4,
            feedback: 'Executed fill with params [8, 8] and color index 4.',
          ),
        ];

        final formattedPrompt = delegate.formatPrompt('draw a ball', history);

        expect(
          formattedPrompt,
          contains('[Step 1] Thoughts: "Draw an outline circle"'),
        );
        expect(
          formattedPrompt,
          contains('Action: circle with params [8, 8, 5] and color index 3'),
        );
        expect(
          formattedPrompt,
          contains(
            'Result: Executed circle with params [8, 8, 5] and color index 3.',
          ),
        );

        expect(
          formattedPrompt,
          contains('[Step 2] Thoughts: "Fill the circle center"'),
        );
        expect(
          formattedPrompt,
          contains('Action: fill with params [8, 8] and color index 4'),
        );
        expect(
          formattedPrompt,
          contains(
            'Result: Executed fill with params [8, 8] and color index 4.',
          ),
        );
      });

      test('formats empty history with no step logs', () {
        final delegate = PixelArtAgentDelegate(
          canvas: fakeCanvas,
          referenceImageBmp: null,
          previousCanvasBmp: null,
        );

        final formattedPrompt = delegate.formatPrompt('draw a cat', []);
        expect(formattedPrompt, isNot(contains('[Step 1]')));
      });

      test(
        'constructs prompt with previous canvas image present or absent',
        () {
          final previousBmp = Uint8List.fromList([0x42, 0x4D, 0x11, 0x22]);
          final delegateWithPrevious = PixelArtAgentDelegate(
            canvas: fakeCanvas,
            referenceImageBmp: null,
            previousCanvasBmp: previousBmp,
          );

          final promptWithPrev = delegateWithPrevious.formatPrompt('edit', []);
          expect(promptWithPrev, contains('User Instruction: "edit"'));

          final delegateWithoutPrevious = PixelArtAgentDelegate(
            canvas: fakeCanvas,
            referenceImageBmp: null,
            previousCanvasBmp: null,
          );

          final promptWithoutPrev = delegateWithoutPrevious.formatPrompt(
            'edit',
            [],
          );
          expect(promptWithoutPrev, contains('User Instruction: "edit"'));
        },
      );
    });

    group('getVisualInput', () {
      test(
        'delegates to canvas.generateCombinedVisualInput with reference and previous bitmaps',
        () {
          final refBmp = Uint8List.fromList([0x42, 0x4D, 0x01]);
          final prevBmp = Uint8List.fromList([0x42, 0x4D, 0x02]);
          final expectedVisualBytes = Uint8List.fromList([0x42, 0x4D, 0x99]);

          fakeCanvas.mockVisualInput = expectedVisualBytes;

          final delegate = PixelArtAgentDelegate(
            canvas: fakeCanvas,
            referenceImageBmp: refBmp,
            previousCanvasBmp: prevBmp,
          );

          final visualInput = delegate.getVisualInput();

          expect(visualInput, equals(expectedVisualBytes));
          expect(fakeCanvas.lastReferenceBmp, equals(refBmp));
          expect(fakeCanvas.lastPreviousBmp, equals(prevBmp));
        },
      );

      test(
        'passes null reference and previous bitmaps when they are not provided',
        () {
          final delegate = PixelArtAgentDelegate(
            canvas: fakeCanvas,
            referenceImageBmp: null,
            previousCanvasBmp: null,
          );

          delegate.getVisualInput();

          expect(fakeCanvas.lastReferenceBmp, isNull);
          expect(fakeCanvas.lastPreviousBmp, isNull);
        },
      );
    });

    group('applyAction', () {
      test(
        'dispatches command to canvas and returns execution message',
        () async {
          final delegate = PixelArtAgentDelegate(
            canvas: fakeCanvas,
            referenceImageBmp: null,
            previousCanvasBmp: null,
          );

          final result = await delegate.applyAction({
            'tool': 'pixel',
            'params': [2, 3],
            'color': 1,
          });

          expect(
            result,
            equals('Executed pixel with params [2, 3] and color index 1.'),
          );
          expect(fakeCanvas.appliedCommands.length, equals(1));
          expect(
            fakeCanvas.appliedCommands.first,
            equals(const AppliedCommand('pixel', [2, 3], 1)),
          );
        },
      );

      test(
        'handles missing or null action parameters with graceful defaults',
        () async {
          final delegate = PixelArtAgentDelegate(
            canvas: fakeCanvas,
            referenceImageBmp: null,
            previousCanvasBmp: null,
          );

          final result = await delegate.applyAction({});

          expect(result, equals('Executed  with params [] and color index 0.'));
          expect(fakeCanvas.appliedCommands.length, equals(1));
          expect(
            fakeCanvas.appliedCommands.first,
            equals(const AppliedCommand('', [], 0)),
          );
        },
      );

      test('handles null params field explicitly', () async {
        final delegate = PixelArtAgentDelegate(
          canvas: fakeCanvas,
          referenceImageBmp: null,
          previousCanvasBmp: null,
        );

        final result = await delegate.applyAction({
          'tool': 'clear',
          'params': null,
          'color': 1,
        });

        expect(
          result,
          equals('Executed clear with params [] and color index 1.'),
        );
        expect(fakeCanvas.appliedCommands.length, equals(1));
        expect(
          fakeCanvas.appliedCommands.first,
          equals(const AppliedCommand('clear', [], 1)),
        );
      });

      test('handles non-list params gracefully', () async {
        final delegate = PixelArtAgentDelegate(
          canvas: fakeCanvas,
          referenceImageBmp: null,
          previousCanvasBmp: null,
        );

        final result = await delegate.applyAction({
          'tool': 'fill',
          'params': 'invalid_string',
          'color': 2,
        });

        expect(
          result,
          equals('Executed fill with params [] and color index 2.'),
        );
        expect(fakeCanvas.appliedCommands.length, equals(1));
        expect(
          fakeCanvas.appliedCommands.first,
          equals(const AppliedCommand('fill', [], 2)),
        );
      });

      test('handles list params with integer type casting', () async {
        final delegate = PixelArtAgentDelegate(
          canvas: fakeCanvas,
          referenceImageBmp: null,
          previousCanvasBmp: null,
        );

        final result = await delegate.applyAction({
          'tool': 'rectangle_filled',
          'params': <dynamic>[1, 2, 8, 9],
          'color': 3,
        });

        expect(
          result,
          equals(
            'Executed rectangle_filled with params [1, 2, 8, 9] and color index 3.',
          ),
        );
        expect(fakeCanvas.appliedCommands.length, equals(1));
        expect(
          fakeCanvas.appliedCommands.first,
          equals(const AppliedCommand('rectangle_filled', [1, 2, 8, 9], 3)),
        );
      });

      test('handles double or string-encoded color gracefully', () async {
        final delegate = PixelArtAgentDelegate(
          canvas: fakeCanvas,
          referenceImageBmp: null,
          previousCanvasBmp: null,
        );

        final result1 = await delegate.applyAction({
          'tool': 'pixel',
          'params': [1, 2],
          'color': 3.0,
        });

        expect(
          result1,
          equals('Executed pixel with params [1, 2] and color index 3.'),
        );
        expect(
          fakeCanvas.appliedCommands.last,
          equals(const AppliedCommand('pixel', [1, 2], 3)),
        );

        final result2 = await delegate.applyAction({
          'tool': 'pixel',
          'params': [3, 4],
          'color': '4',
        });

        expect(
          result2,
          equals('Executed pixel with params [3, 4] and color index 4.'),
        );
        expect(
          fakeCanvas.appliedCommands.last,
          equals(const AppliedCommand('pixel', [3, 4], 4)),
        );
      });
    });

    group('isFinishAction', () {
      late PixelArtAgentDelegate delegate;

      setUp(() {
        delegate = PixelArtAgentDelegate(
          canvas: fakeCanvas,
          referenceImageBmp: null,
          previousCanvasBmp: null,
        );
      });

      test('returns true when tool is "finish"', () {
        expect(delegate.isFinishAction({'tool': 'finish'}), isTrue);
      });

      test('returns true when tool is null or missing', () {
        expect(delegate.isFinishAction({}), isTrue);
        expect(delegate.isFinishAction({'tool': null}), isTrue);
      });

      test('returns false for active drawing tools', () {
        expect(delegate.isFinishAction({'tool': 'pixel'}), isFalse);
        expect(delegate.isFinishAction({'tool': 'line'}), isFalse);
        expect(delegate.isFinishAction({'tool': 'rectangle'}), isFalse);
        expect(delegate.isFinishAction({'tool': 'rectangle_filled'}), isFalse);
        expect(delegate.isFinishAction({'tool': 'circle'}), isFalse);
        expect(delegate.isFinishAction({'tool': 'circle_filled'}), isFalse);
        expect(delegate.isFinishAction({'tool': 'fill'}), isFalse);
        expect(delegate.isFinishAction({'tool': 'hatch'}), isFalse);
      });
    });

    group('parseStepResult', () {
      late PixelArtAgentDelegate delegate;

      setUp(() {
        delegate = PixelArtAgentDelegate(
          canvas: fakeCanvas,
          referenceImageBmp: null,
          previousCanvasBmp: null,
        );
      });

      test('correctly parses structured action map into PixelArtStepResult', () {
        final actionMap = {
          'thought': 'Draw a border rectangle',
          'tool': 'rectangle',
          'params': [0, 0, 15, 15],
          'color': 2,
        };
        const feedback =
            'Executed rectangle with params [0, 0, 15, 15] and color index 2.';

        final stepResult = delegate.parseStepResult(actionMap, feedback);

        expect(stepResult.thought, equals('Draw a border rectangle'));
        expect(stepResult.tool, equals('rectangle'));
        expect(stepResult.params, equals([0, 0, 15, 15]));
        expect(stepResult.colorIndex, equals(2));
        expect(stepResult.feedback, equals(feedback));
      });

      test('parses fractional and double parameters without error', () {
        final actionMap = {
          'thought': 'Draw a fractional circle',
          'tool': 'circle',
          'params': [7.5, 7.5, 3.5],
          'color': 1,
        };
        const feedback =
            'Executed circle with params [7.5, 7.5, 3.5] and color index 1.';

        final stepResult = delegate.parseStepResult(actionMap, feedback);

        expect(stepResult.thought, equals('Draw a fractional circle'));
        expect(stepResult.tool, equals('circle'));
        expect(stepResult.params, equals([7.5, 7.5, 3.5]));
        expect(stepResult.colorIndex, equals(1));
        expect(stepResult.feedback, equals(feedback));
      });

      test('parses string-encoded numbers in params and color', () {
        final actionMap = {
          'thought': 'Draw with string parameters',
          'tool': 'circle',
          'params': ['7.5', '7.5', '3.5'],
          'color': '2',
        };
        const feedback =
            'Executed circle with params [7.5, 7.5, 3.5] and color index 2.';

        final stepResult = delegate.parseStepResult(actionMap, feedback);

        expect(stepResult.thought, equals('Draw with string parameters'));
        expect(stepResult.tool, equals('circle'));
        expect(stepResult.params, equals([7.5, 7.5, 3.5]));
        expect(stepResult.colorIndex, equals(2));
        expect(stepResult.feedback, equals(feedback));
      });

      test('safely parses color provided as a double', () {
        final actionMap = {
          'thought': 'Draw with double color',
          'tool': 'pixel',
          'params': [1, 2],
          'color': 1.0,
        };
        const feedback = 'Executed pixel';

        final stepResult = delegate.parseStepResult(actionMap, feedback);

        expect(stepResult.colorIndex, equals(1));
      });

      test('filters out non-numeric or null entries in params', () {
        final actionMap = {
          'thought': 'Draw with invalid entries in params',
          'tool': 'circle',
          'params': [7.5, 'invalid', null, 3.5],
          'color': 'invalid',
        };
        const feedback = 'Executed circle';

        final stepResult = delegate.parseStepResult(actionMap, feedback);

        expect(stepResult.params, equals([7.5, 3.5]));
        expect(stepResult.colorIndex, equals(0));
      });

      test(
        'provides default fallback values when fields are missing or null',
        () {
          final stepResult = delegate.parseStepResult({}, 'Initial feedback');

          expect(stepResult.thought, equals(''));
          expect(stepResult.tool, equals(''));
          expect(stepResult.params, equals(<int>[]));
          expect(stepResult.colorIndex, equals(0));
          expect(stepResult.feedback, equals('Initial feedback'));
        },
      );

      test(
        'provides default fallback values when explicit nulls are provided',
        () {
          final stepResult = delegate.parseStepResult({
            'thought': null,
            'tool': null,
            'params': null,
            'color': null,
          }, 'Fallback test');

          expect(stepResult.thought, equals(''));
          expect(stepResult.tool, equals(''));
          expect(stepResult.params, equals(<int>[]));
          expect(stepResult.colorIndex, equals(0));
          expect(stepResult.feedback, equals('Fallback test'));
        },
      );
    });
  });
}
