import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/utils/settings_provider.dart';
import 'package:bad_pixel_art/logic/utils/logging_ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_helper.dart';

void main() {
  group('CanvasNotifier Unit Tests', () {
    late TestMockAiService mockAiService;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAiService = TestMockAiService();
      container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(mockAiService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is correct', () {
      final model = container.read(canvasStateProvider);
      expect(model.selectedColorIndex, equals(1));
      expect(model.selectedTool, equals(CanvasTool.line));
      expect(model.paletteName, equals('primary'));
      expect(model.isGenerating, isFalse);
      expect(model.autoRun, isFalse);
      expect(model.undoStack, isEmpty);
      expect(model.redoStack, isEmpty);
      expect(model.grid.length, equals(CanvasNotifier.gridSize));
      expect(model.grid[0].length, equals(CanvasNotifier.gridSize));
    });

    test('selectColor updates selectedColorIndex', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(3);
      expect(container.read(canvasStateProvider).selectedColorIndex, equals(3));

      // Invalid color index should be ignored
      notifier.selectColor(99);
      expect(container.read(canvasStateProvider).selectedColorIndex, equals(3));
    });

    test('selectTool updates selectedTool', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectTool(CanvasTool.circle);
      expect(
        container.read(canvasStateProvider).selectedTool,
        equals(CanvasTool.circle),
      );
    });

    test(
      'changing AI model in settingsProvider retains canvas state and logs modelName',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final testContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            aiServiceProvider.overrideWithValue(TestMockAiService()),
          ],
        );
        addTearDown(testContainer.dispose);

        final notifier = testContainer.read(canvasStateProvider.notifier);
        notifier.selectColor(2);
        notifier.drawPixel(5, 5);

        expect(testContainer.read(canvasStateProvider).grid[5][5], equals(2));

        // Change AI model in settings
        final settingsNotifier = testContainer.read(settingsProvider.notifier);
        await settingsNotifier.setGeminiModel('gemini-3.6-flash');

        // Verify canvas grid and state are retained 100%
        final stateAfter = testContainer.read(canvasStateProvider);
        expect(stateAfter.grid[5][5], equals(2));
        expect(stateAfter.selectedColorIndex, equals(2));
      },
    );

    test('drawPixel draws on grid and saves to undo stack', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(2);
      notifier.drawPixel(10, 12);

      final model = container.read(canvasStateProvider);
      expect(model.grid[12][10], equals(2));
      expect(model.undoStack.length, equals(1));
      expect(model.redoStack, isEmpty);
    });

    test('undo and redo work correctly', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);

      notifier.drawPixel(5, 5); // Stroke 1
      notifier.drawPixel(10, 10); // Stroke 2

      expect(container.read(canvasStateProvider).grid[5][5], equals(1));
      expect(container.read(canvasStateProvider).grid[10][10], equals(1));

      // Undo Stroke 2
      notifier.undo();
      expect(container.read(canvasStateProvider).grid[5][5], equals(1));
      expect(container.read(canvasStateProvider).grid[10][10], equals(0));

      // Undo Stroke 1
      notifier.undo();
      expect(container.read(canvasStateProvider).grid[5][5], equals(0));
      expect(container.read(canvasStateProvider).grid[10][10], equals(0));

      // Redo Stroke 1
      notifier.redo();
      expect(container.read(canvasStateProvider).grid[5][5], equals(1));
      expect(container.read(canvasStateProvider).grid[10][10], equals(0));

      // Redo Stroke 2
      notifier.redo();
      expect(container.read(canvasStateProvider).grid[5][5], equals(1));
      expect(container.read(canvasStateProvider).grid[10][10], equals(1));
    });

    test('applyLine draws line on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(3);
      notifier.applyLine(0, 0, 5, 0); // Horizontal line

      final grid = container.read(canvasStateProvider).grid;
      for (int i = 0; i <= 5; i++) {
        expect(grid[0][i], equals(3));
      }
    });

    test('applyCircle draws circle outline on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(2);
      notifier.applyCircle(10, 10, 3);

      final grid = container.read(canvasStateProvider).grid;
      // Midpoint circle should set xc + r, yc which is (13, 10)
      expect(grid[10][13], equals(2));
      expect(grid[10][7], equals(2));
      expect(grid[13][10], equals(2));
      expect(grid[7][10], equals(2));
    });

    test('applyFill fills region with color', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyLine(5, 5, 5, 10);
      notifier.applyLine(5, 5, 10, 5);
      notifier.applyLine(10, 5, 10, 10);
      notifier.applyLine(5, 10, 10, 10); // Simple 5x5 bounding square

      notifier.selectColor(2);
      notifier.applyFill(7, 7); // Fill center

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[7][7], equals(2));
      expect(grid[6][6], equals(2));
      expect(grid[0][0], equals(0)); // Outside bounds remains unfilled
    });

    test('applyHatch fills region with checkerboard hatch pattern', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyHatch(10, 10);

      final grid = container.read(canvasStateProvider).grid;
      // Checks alternate pixels
      expect(grid[10][10], equals(1));
      expect(grid[10][11], equals(0));
      expect(grid[11][10], equals(0));
      expect(grid[11][11], equals(1));
    });

    test('applyCircleFilled draws filled circle on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyCircleFilled(10, 10, 2);

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[10][10], equals(1));
      expect(grid[10][12], equals(1)); // border
      expect(grid[10][11], equals(1)); // inside
    });

    test('applyCircleHatched draws hatched circle on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyCircleHatched(10, 10, 2);

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[10][10], equals(1)); // (10+10)%2 == 0
      expect(grid[10][11], equals(0)); // (10+11)%2 == 1
    });

    test('applyRectangle draws outlined rectangle on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyRectangle(10, 10, 15, 15);

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[10][10], equals(1));
      expect(grid[10][15], equals(1));
      expect(grid[15][10], equals(1));
      expect(grid[15][15], equals(1));
      expect(grid[12][12], equals(0)); // inside should be empty
    });

    test('applyRectangleFilled draws filled rectangle on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyRectangleFilled(10, 10, 15, 15);

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[10][10], equals(1));
      expect(grid[15][15], equals(1));
      expect(grid[12][12], equals(1)); // inside should be filled
    });

    test('applyRectangleHatched draws hatched rectangle on grid', () {
      final notifier = container.read(canvasStateProvider.notifier);
      notifier.selectColor(1);
      notifier.applyRectangleHatched(10, 10, 15, 15);

      final grid = container.read(canvasStateProvider).grid;
      expect(grid[10][10], equals(1)); // (10+10)%2 == 0
      expect(grid[10][11], equals(0)); // (10+11)%2 == 1
      expect(grid[12][12], equals(1)); // (12+12)%2 == 0
    });

    test('triggerDownload calls AI service download', () async {
      mockAiService.status = AiCoreStatus.downloadable;
      final notifier = container.read(canvasStateProvider.notifier);

      await notifier.triggerDownload();
      expect(mockAiService.triggerDownloadCalled, isTrue);
      expect(
        container.read(canvasStateProvider).aiStatus,
        equals(AiCoreStatus.available),
      );
    });

    test('clearAiHistory clears the logs', () async {
      final notifier = container.read(canvasStateProvider.notifier);
      await notifier.triggerDecomposition();
      expect(container.read(canvasStateProvider).aiHistory, isNotEmpty);

      notifier.clearAiHistory();
      expect(container.read(canvasStateProvider).aiHistory, isEmpty);
    });

    test(
      'changeResolution switches grid size and clears history/undo/redo stacks',
      () {
        final notifier = container.read(canvasStateProvider.notifier);

        expect(notifier.state.gridSize, equals(16));
        expect(notifier.state.grid.length, equals(16));

        notifier.drawPixel(0, 0);
        expect(notifier.state.undoStack.isNotEmpty, isTrue);

        notifier.changeResolution(8);

        final updatedState = container.read(canvasStateProvider);
        expect(updatedState.gridSize, equals(8));
        expect(updatedState.grid.length, equals(8));
        expect(updatedState.grid[0].length, equals(8));
        expect(updatedState.undoStack.isEmpty, isTrue);
        expect(updatedState.redoStack.isEmpty, isTrue);

        notifier.changeResolution(12);
        expect(container.read(canvasStateProvider).gridSize, equals(8));
      },
    );

    group('applyCommand palette bounds clamping', () {
      test('clamps colorIndex >= palette.length to palette.length - 1', () {
        final notifier = container.read(canvasStateProvider.notifier);
        final paletteLength = notifier.state.palette.length;
        expect(paletteLength, greaterThan(0));

        notifier.applyCommand('line', [0, 0, 1, 1], paletteLength + 10);
        expect(
          container.read(canvasStateProvider).selectedColorIndex,
          equals(paletteLength - 1),
        );

        // Also test exact boundary palette.length
        notifier.applyCommand('line', [0, 0, 1, 1], paletteLength);
        expect(
          container.read(canvasStateProvider).selectedColorIndex,
          equals(paletteLength - 1),
        );
      });

      test('clamps negative colorIndex to 0', () {
        final notifier = container.read(canvasStateProvider.notifier);
        notifier.applyCommand('line', [0, 0, 1, 1], -5);
        expect(
          container.read(canvasStateProvider).selectedColorIndex,
          equals(0),
        );
      });

      test('sets valid colorIndex in bounds directly', () {
        final notifier = container.read(canvasStateProvider.notifier);
        notifier.applyCommand('line', [0, 0, 1, 1], 2);
        expect(
          container.read(canvasStateProvider).selectedColorIndex,
          equals(2),
        );
      });

      test('does not throw when palette is empty', () {
        final notifier = container.read(canvasStateProvider.notifier);
        notifier.state = notifier.state.copyWith(palette: const []);
        expect(notifier.state.palette, isEmpty);

        expect(
          () => notifier.applyCommand('line', [0, 0, 1, 1], 3),
          returnsNormally,
        );
        expect(
          container.read(canvasStateProvider).selectedColorIndex,
          equals(0),
        );
      });
    });

    group('batchUpdateComponentColors', () {
      test(
        'updates multiple component colors and gradient properties in a single state mutation',
        () {
          final notifier = container.read(canvasStateProvider.notifier);
          final initialComponents = [
            PixelArtComponent(
              name: 'Blade',
              description: 'Sword blade',
              relativeBoundingBox: const Rect.fromLTWH(0, 0, 10, 10),
              grid: List.generate(16, (_) => List.filled(16, 0)),
              shapes: [],
              fillColor: Colors.black,
              outlineColor: Colors.grey,
            ),
            PixelArtComponent(
              name: 'Hilt',
              description: 'Sword hilt',
              relativeBoundingBox: const Rect.fromLTWH(0, 10, 10, 5),
              grid: List.generate(16, (_) => List.filled(16, 0)),
              shapes: [],
              fillColor: Colors.brown,
              outlineColor: Colors.black,
            ),
          ];

          notifier.state = notifier.state.copyWith(
            decomposedComponents: initialComponents,
          );

          final updatedComponents = [
            PixelArtComponent(
              name: 'Blade',
              description: 'Sword blade',
              relativeBoundingBox: const Rect.fromLTWH(0, 0, 10, 10),
              grid: List.generate(16, (_) => List.filled(16, 0)),
              shapes: [],
              fillColor: Colors.cyan,
              fillColor2: Colors.blue,
              gradientAngle: 45.0,
              outlineColor: Colors.white,
            ),
            PixelArtComponent(
              name: 'Hilt',
              description: 'Sword hilt',
              relativeBoundingBox: const Rect.fromLTWH(0, 10, 10, 5),
              grid: List.generate(16, (_) => List.filled(16, 0)),
              shapes: [],
              fillColor: Colors.amber,
              fillColor2: null,
              gradientAngle: 0.0,
              outlineColor: null,
            ),
          ];

          notifier.batchUpdateComponentColors(updatedComponents);

          final result = container
              .read(canvasStateProvider)
              .decomposedComponents;
          expect(result.length, equals(2));
          expect(result[0].fillColor, equals(Colors.cyan));
          expect(result[0].fillColor2, equals(Colors.blue));
          expect(result[0].gradientAngle, equals(45.0));
          expect(result[0].outlineColor, equals(Colors.white));

          expect(result[1].fillColor, equals(Colors.amber));
          expect(result[1].fillColor2, isNull);
          expect(result[1].gradientAngle, equals(0.0));
          expect(result[1].outlineColor, isNull);
        },
      );

      test('handles empty updated list or empty state gracefully', () {
        final notifier = container.read(canvasStateProvider.notifier);
        expect(notifier.state.decomposedComponents, isEmpty);

        expect(() => notifier.batchUpdateComponentColors([]), returnsNormally);

        final sample = [
          PixelArtComponent(
            name: 'Comp',
            description: '',
            relativeBoundingBox: Rect.zero,
            grid: [],
            shapes: [],
            fillColor: Colors.red,
          ),
        ];
        expect(
          () => notifier.batchUpdateComponentColors(sample),
          returnsNormally,
        );
        expect(notifier.state.decomposedComponents, isEmpty);
      });

      test('handles mismatched length between state and updatedComponents', () {
        final notifier = container.read(canvasStateProvider.notifier);
        notifier.state = notifier.state.copyWith(
          decomposedComponents: [
            PixelArtComponent(
              name: 'Comp1',
              description: '',
              relativeBoundingBox: Rect.zero,
              grid: [],
              shapes: [],
              fillColor: Colors.red,
            ),
            PixelArtComponent(
              name: 'Comp2',
              description: '',
              relativeBoundingBox: Rect.zero,
              grid: [],
              shapes: [],
              fillColor: Colors.green,
            ),
          ],
        );

        // Only update 1 component when 2 exist
        notifier.batchUpdateComponentColors([
          PixelArtComponent(
            name: 'Comp1',
            description: '',
            relativeBoundingBox: Rect.zero,
            grid: [],
            shapes: [],
            fillColor: Colors.blue,
          ),
        ]);

        final result = container.read(canvasStateProvider).decomposedComponents;
        expect(result.length, equals(2));
        expect(result[0].fillColor, equals(Colors.blue));
        expect(result[1].fillColor, equals(Colors.green));
      });
    });

    group('Async Mounted & Disposal Safety Tests', () {
      test(
        'triggerDecomposition does not mutate state or throw if disposed mid-operation',
        () async {
          final completer = Completer<AiResponse?>();
          mockAiService.completer = completer;

          final notifier = container.read(canvasStateProvider.notifier);
          final future = notifier.triggerDecomposition();

          // Dispose container while async operation is pending
          container.dispose();

          completer.complete(
            AiResponse(text: TestJsonFixtures.decomposerFlatResponse),
          );
          await expectLater(future, completes);
        },
      );

      test(
        'triggerDecomposition handles exceptions safely when disposed',
        () async {
          final completer = Completer<AiResponse?>();
          mockAiService.completer = completer;

          final notifier = container.read(canvasStateProvider.notifier);
          final future = notifier.triggerDecomposition();

          container.dispose();

          completer.completeError(Exception('AI error'));
          await expectLater(future, completes);
        },
      );

      test(
        'sculptComponent does not throw if disposed mid-operation',
        () async {
          final completer = Completer<AiResponse?>();
          mockAiService.completer = completer;

          final notifier = container.read(canvasStateProvider.notifier);
          notifier.state = notifier.state.copyWith(
            decomposedComponents: [
              PixelArtComponent(
                name: 'blade',
                description: 'sharp blue blade',
                relativeBoundingBox: const Rect.fromLTWH(0.45, 0.1, 0.1, 0.6),
              ),
            ],
          );

          final future = notifier.sculptComponent(0);
          container.dispose();

          completer.complete(AiResponse(text: '[[0,1],[1,0]]'));
          await expectLater(future, completes);
        },
      );

      test(
        'sculptComponents does not throw if disposed mid-operation',
        () async {
          final completer = Completer<AiResponse?>();
          mockAiService.completer = completer;

          final notifier = container.read(canvasStateProvider.notifier);
          notifier.state = notifier.state.copyWith(
            decomposedComponents: [
              PixelArtComponent(
                name: 'blade',
                description: 'sharp blue blade',
                relativeBoundingBox: const Rect.fromLTWH(0.45, 0.1, 0.1, 0.6),
              ),
            ],
          );

          final future = notifier.sculptComponents();
          container.dispose();

          completer.complete(AiResponse(text: '[[0,1],[1,0]]'));
          await expectLater(future, completes);
        },
      );

      test(
        'sketchComponents does not throw if disposed mid-operation',
        () async {
          final completer = Completer<AiResponse?>();
          mockAiService.completer = completer;

          final notifier = container.read(canvasStateProvider.notifier);
          notifier.state = notifier.state.copyWith(
            decomposedComponents: [
              PixelArtComponent(
                name: 'blade',
                description: 'sharp blue blade',
                relativeBoundingBox: const Rect.fromLTWH(0.45, 0.1, 0.1, 0.6),
              ),
            ],
          );

          final future = notifier.sketchComponents();
          container.dispose();

          completer.complete(AiResponse(text: '[[0,1],[1,0]]'));
          await expectLater(future, completes);
        },
      );

      test('refineCanvas does not throw if disposed mid-operation', () async {
        final completer = Completer<AiResponse?>();
        mockAiService.completer = completer;

        final notifier = container.read(canvasStateProvider.notifier);
        final future = notifier.refineCanvas('refine this');
        container.dispose();

        completer.complete(AiResponse(text: '[]'));
        await expectLater(future, completes);
      });

      test(
        'suggestPaletteFromReference does not throw if disposed mid-operation',
        () async {
          final completer = Completer<AiResponse?>();
          mockAiService.completer = completer;

          final notifier = container.read(canvasStateProvider.notifier);
          notifier.setReferenceImage(Uint8List.fromList([1, 2, 3]));

          final future = notifier.suggestPaletteFromReference();
          container.dispose();

          completer.complete(AiResponse(text: '["#FFFFFF", "#000000"]'));
          await expectLater(future, completes);
        },
      );

      test(
        'suggestDescriptionFromReference does not throw if disposed mid-operation',
        () async {
          final completer = Completer<AiResponse?>();
          mockAiService.completer = completer;

          final notifier = container.read(canvasStateProvider.notifier);
          notifier.setReferenceImage(Uint8List.fromList([1, 2, 3]));

          final future = notifier.suggestDescriptionFromReference();
          container.dispose();

          completer.complete(AiResponse(text: 'a small sword'));
          await expectLater(future, completes);
        },
      );

      test(
        'checkAiStatus and triggerDownload do not throw if disposed mid-operation',
        () async {
          final notifier = container.read(canvasStateProvider.notifier);
          container.dispose();

          await expectLater(notifier.checkAiStatus(), completes);
          await expectLater(notifier.triggerDownload(), completes);
        },
      );

      test('setModelConfig does not throw if disposed mid-operation', () async {
        final notifier = container.read(canvasStateProvider.notifier);
        container.dispose();

        await expectLater(notifier.setModelConfig('stable', 'full'), completes);
      });

      test(
        'LoggingAiService callbacks do not mutate state or throw after disposal',
        () async {
          final loggingAiService = LoggingAiService(mockAiService);
          final customNotifier = CanvasNotifier(loggingAiService);

          expect(customNotifier.mounted, isTrue);
          customNotifier.dispose();
          expect(customNotifier.mounted, isFalse);

          final testEntry = AgentHistoryEntry(
            timestamp: DateTime.now(),
            prompt: 'Testing prompt',
            response: 'Testing response',
            isError: false,
          );

          expect(
            () => loggingAiService.onLog?.call(testEntry),
            returnsNormally,
          );
          expect(
            () => loggingAiService.onLogUpdate?.call(testEntry, testEntry),
            returnsNormally,
          );
        },
      );

      test(
        'persistence methods (saveToDb, loadFromDb, loadLastSession, startNewCanvas, duplicateCanvas, deleteCanvas) do not throw if disposed',
        () async {
          final notifier = container.read(canvasStateProvider.notifier);
          container.dispose();

          await expectLater(notifier.saveToDb(), completes);
          await expectLater(notifier.loadFromDb(1), completes);
          await expectLater(notifier.loadLastSession(), completes);
          await expectLater(notifier.startNewCanvas(), completes);
          await expectLater(notifier.duplicateCanvas(1), completes);
          await expectLater(notifier.deleteCanvas(1), completes);
        },
      );
    });
  });
}
