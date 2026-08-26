import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/models/canvas_model.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';

void main() {
  group('CanvasModel Unit Tests', () {
    final defaultGrid = List.generate(8, (_) => List.filled(8, 0));
    final defaultPalette = [const Color(0xFF000000), const Color(0xFFFFFFFF)];

    CanvasModel createSampleModel({
      int? creationId = 42,
      String title = 'Star',
      int gridSize = 8,
      List<List<int>>? grid,
      int selectedColorIndex = 1,
      CanvasTool selectedTool = CanvasTool.circle,
      String paletteName = 'bw',
      List<Color>? palette,
      Uint8List? referenceImage,
      Uint8List? originalReferenceImage,
      String userPrompt = 'a shining star',
      AiCoreStatus aiStatus = AiCoreStatus.available,
      bool isGenerating = false,
      bool autoRun = true,
      double autoRunSpeed = 2.0,
      List<List<List<int>>>? undoStack,
      List<List<List<int>>>? redoStack,
      List<AgentHistoryEntry>? aiHistory,
      List<Color>? suggestedPalette,
      bool isSuggestingPalette = false,
      bool isSuggestingDescription = false,
      bool isPausing = false,
      bool showPaletteSuggestion = false,
      String? nextFocus,
      String modelReleaseStage = 'stable',
      String modelPreference = 'full',
      List<List<PixelArtComponent>>? pendingDecompositionOptions,
      List<PixelArtComponent>? decomposedComponents,
      int activeComponentIndex = 0,
      int? decomposingComponentIndex,
      String? sculptingStatus,
    }) {
      return CanvasModel(
        creationId: creationId,
        title: title,
        gridSize: gridSize,
        grid: grid ?? List.generate(8, (_) => List.filled(8, 0)),
        selectedColorIndex: selectedColorIndex,
        selectedTool: selectedTool,
        paletteName: paletteName,
        palette: palette ?? [const Color(0xFF000000), const Color(0xFFFFFFFF)],
        referenceImage: referenceImage,
        originalReferenceImage: originalReferenceImage,
        userPrompt: userPrompt,
        aiStatus: aiStatus,
        isGenerating: isGenerating,
        autoRun: autoRun,
        autoRunSpeed: autoRunSpeed,
        undoStack:
            undoStack ??
            [
              [
                [1, 0],
                [0, 1],
              ],
            ],
        redoStack:
            redoStack ??
            [
              [
                [0, 1],
                [1, 0],
              ],
            ],
        aiHistory: aiHistory ?? const [],
        suggestedPalette: suggestedPalette,
        isSuggestingPalette: isSuggestingPalette,
        isSuggestingDescription: isSuggestingDescription,
        isPausing: isPausing,
        showPaletteSuggestion: showPaletteSuggestion,
        nextFocus: nextFocus,
        modelReleaseStage: modelReleaseStage,
        modelPreference: modelPreference,
        pendingDecompositionOptions: pendingDecompositionOptions ?? const [],
        decomposedComponents: decomposedComponents ?? const [],
        activeComponentIndex: activeComponentIndex,
        decomposingComponentIndex: decomposingComponentIndex,
        sculptingStatus: sculptingStatus,
      );
    }

    test('CanvasModel construct sets values correctly', () {
      final model = CanvasModel(
        creationId: 42,
        title: 'Star',
        gridSize: 8,
        grid: defaultGrid,
        selectedColorIndex: 1,
        selectedTool: CanvasTool.circle,
        paletteName: 'bw',
        palette: defaultPalette,
        userPrompt: 'a shining star',
        aiStatus: AiCoreStatus.available,
        isGenerating: false,
        autoRun: true,
        autoRunSpeed: 2.0,
        undoStack: const [],
        redoStack: const [],
        aiHistory: const [],
      );

      expect(model.creationId, equals(42));
      expect(model.title, equals('Star'));
      expect(model.gridSize, equals(8));
      expect(model.grid, equals(defaultGrid));
      expect(model.selectedColorIndex, equals(1));
      expect(model.selectedTool, equals(CanvasTool.circle));
      expect(model.paletteName, equals('bw'));
      expect(model.palette, equals(defaultPalette));
      expect(model.userPrompt, equals('a shining star'));
      expect(model.aiStatus, equals(AiCoreStatus.available));
      expect(model.isGenerating, isFalse);
      expect(model.autoRun, isTrue);
      expect(model.autoRunSpeed, equals(2.0));
      expect(model.undoStack, isEmpty);
      expect(model.redoStack, isEmpty);
      expect(model.aiHistory, isEmpty);
    });

    test('CanvasModel copyWith works correctly including clearing values', () {
      final model = CanvasModel(
        creationId: 42,
        title: 'Star',
        gridSize: 8,
        grid: defaultGrid,
        selectedColorIndex: 1,
        selectedTool: CanvasTool.circle,
        paletteName: 'bw',
        palette: defaultPalette,
        userPrompt: 'a shining star',
        aiStatus: AiCoreStatus.available,
        isGenerating: false,
        autoRun: true,
        autoRunSpeed: 2.0,
        undoStack: const [],
        redoStack: const [],
        aiHistory: const [],
      );

      final updated = model.copyWith(
        title: 'Updated Star',
        clearCreationId: true,
      );

      expect(updated.title, equals('Updated Star'));
      expect(updated.creationId, isNull);
    });

    test(
      'Two separate instances with identical properties compare equal and have same hashCode',
      () {
        final model1 = createSampleModel();
        final model2 = createSampleModel();

        expect(model1, equals(model2));
        expect(model1 == model2, isTrue);
        expect(model1.hashCode, equals(model2.hashCode));
      },
    );

    test('Modifying grid evaluates as unequal and changes hashCode', () {
      final model1 = createSampleModel();
      final modifiedGrid = List.generate(8, (_) => List.filled(8, 0));
      modifiedGrid[0][0] = 1;
      final model2 = model1.copyWith(grid: modifiedGrid);

      expect(model1 == model2, isFalse);
      expect(model1.hashCode == model2.hashCode, isFalse);
    });

    test('Modifying creationId evaluates as unequal', () {
      final model1 = createSampleModel(creationId: 42);
      final model2 = createSampleModel(creationId: 99);
      final model3 = model1.copyWith(clearCreationId: true);

      expect(model1 == model2, isFalse);
      expect(model1 == model3, isFalse);
    });

    test('Modifying title evaluates as unequal', () {
      final model1 = createSampleModel(title: 'Title A');
      final model2 = createSampleModel(title: 'Title B');

      expect(model1 == model2, isFalse);
      expect(model1.hashCode == model2.hashCode, isFalse);
    });

    test('Modifying undoStack evaluates as unequal', () {
      final model1 = createSampleModel(
        undoStack: [
          [
            [1, 0],
            [0, 1],
          ],
        ],
      );
      final model2 = createSampleModel(
        undoStack: [
          [
            [1, 1],
            [0, 1],
          ],
        ],
      );
      final model3 = createSampleModel(undoStack: const []);

      expect(model1 == model2, isFalse);
      expect(model1 == model3, isFalse);
      expect(model1.hashCode == model2.hashCode, isFalse);
    });

    test('Modifying redoStack evaluates as unequal', () {
      final model1 = createSampleModel(
        redoStack: [
          [
            [1, 0],
            [0, 1],
          ],
        ],
      );
      final model2 = createSampleModel(
        redoStack: [
          [
            [1, 1],
            [0, 1],
          ],
        ],
      );
      final model3 = createSampleModel(redoStack: const []);

      expect(model1 == model2, isFalse);
      expect(model1 == model3, isFalse);
      expect(model1.hashCode == model2.hashCode, isFalse);
    });

    test('Modifying isSuggestingDescription evaluates as unequal', () {
      final model1 = createSampleModel(isSuggestingDescription: false);
      final model2 = createSampleModel(isSuggestingDescription: true);

      expect(model1 == model2, isFalse);
      expect(model1.hashCode == model2.hashCode, isFalse);
    });

    test('Modifying isPausing evaluates as unequal', () {
      final model1 = createSampleModel(isPausing: false);
      final model2 = createSampleModel(isPausing: true);

      expect(model1 == model2, isFalse);
      expect(model1.hashCode == model2.hashCode, isFalse);
    });

    test('Modifying nextFocus evaluates as unequal', () {
      final model1 = createSampleModel(nextFocus: 'layer1');
      final model2 = createSampleModel(nextFocus: 'layer2');
      final model3 = createSampleModel(nextFocus: null);

      expect(model1 == model2, isFalse);
      expect(model1 == model3, isFalse);
    });

    test('Modifying modelReleaseStage evaluates as unequal', () {
      final model1 = createSampleModel(modelReleaseStage: 'stable');
      final model2 = createSampleModel(modelReleaseStage: 'beta');

      expect(model1 == model2, isFalse);
      expect(model1.hashCode == model2.hashCode, isFalse);
    });

    test('Modifying modelPreference evaluates as unequal', () {
      final model1 = createSampleModel(modelPreference: 'full');
      final model2 = createSampleModel(modelPreference: 'flash');

      expect(model1 == model2, isFalse);
      expect(model1.hashCode == model2.hashCode, isFalse);
    });

    test('Modifying sculptingStatus evaluates as unequal', () {
      final model1 = createSampleModel(sculptingStatus: 'sculpting');
      final model2 = createSampleModel(sculptingStatus: 'idle');
      final model3 = createSampleModel(sculptingStatus: null);

      expect(model1 == model2, isFalse);
      expect(model1 == model3, isFalse);
    });

    test(
      'Modifying pendingDecompositionOptions deeply evaluates as unequal',
      () {
        final comp1 = PixelArtComponent(
          name: 'Head',
          description: 'Head circle',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        );
        final comp2 = PixelArtComponent(
          name: 'Body',
          description: 'Body square',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 1, 1),
        );

        final model1 = createSampleModel(
          pendingDecompositionOptions: [
            [comp1],
          ],
        );
        final model2 = createSampleModel(
          pendingDecompositionOptions: [
            [comp1],
          ],
        );
        final model3 = createSampleModel(
          pendingDecompositionOptions: [
            [comp2],
          ],
        );

        expect(model1 == model2, isTrue);
        expect(model1 == model3, isFalse);
        expect(model1.hashCode == model2.hashCode, isTrue);
      },
    );
  });
}
