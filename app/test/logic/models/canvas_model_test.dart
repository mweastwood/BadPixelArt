import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/models/canvas_model.dart';

void main() {
  group('CanvasModel Unit Tests', () {
    final defaultGrid = List.generate(8, (_) => List.filled(8, 0));
    final defaultPalette = [const Color(0xFF000000), const Color(0xFFFFFFFF)];

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
  });
}
