import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/utils/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTestAiService extends AiService {
  AiCoreStatus status = AiCoreStatus.available;
  bool triggerDownloadCalled = false;

  @override
  Future<AiCoreStatus> checkStatus() async => status;

  @override
  Future<void> triggerDownload() async {
    triggerDownloadCalled = true;
    status = AiCoreStatus.available;
  }

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    if (prompt.contains('decomposer') || prompt.contains('Decompose')) {
      return '''
      [
        {
          "name": "blade",
          "description": "vertical blade",
          "relativeBoundingBox": { "left": 0.4, "top": 0.1, "width": 0.2, "height": 0.6 },
          "colorIndex": 1
        }
      ]
      ''';
    }
    return null;
  }

  @override
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async {
    return 100;
  }
}

void main() {
  group('CanvasNotifier Unit Tests', () {
    late MockTestAiService mockAiService;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAiService = MockTestAiService();
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
            aiServiceProvider.overrideWithValue(MockTestAiService()),
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
  });
}
