import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import '../agents/base_agent.dart';
import '../agents/shape_sculpter_agent.dart';

/// Orchestrates component shape sculpting operations for [CanvasNotifier].
class SculptingOrchestrator {
  final AiService _aiService;

  SculptingOrchestrator(this._aiService);

  /// Builds a background grid of existing components for visual reference.
  static List<List<int>> buildBackgroundGrid({
    required List<PixelArtComponent> components,
    required int excludeIndex,
    required int gridSize,
    required int paletteLength,
  }) {
    final existingGrid = List.generate(
      gridSize,
      (_) => List.filled(gridSize, 0),
    );
    for (int j = 0; j < components.length; j++) {
      if (j == excludeIndex) continue;
      final other = components[j];
      if (other.grid != null) {
        final colorIdx = (j % (paletteLength - 1)) + 1;
        for (int y = 0; y < gridSize; y++) {
          for (int x = 0; x < gridSize; x++) {
            if (other.grid![y][x] > 0) {
              existingGrid[y][x] = colorIdx;
            }
          }
        }
      }
    }
    return existingGrid;
  }

  /// Sculpt a single target component by index.
  Future<List<List<int>>> sculptSingleComponent({
    required PixelArtComponent component,
    required int index,
    required List<PixelArtComponent> allComponents,
    required int gridSize,
    required List<Color> activePalette,
    required String userPrompt,
    required Uint8List? referenceImage,
  }) async {
    final comp = component.initializeDefaultGrid(gridSize);
    final existingGrid = buildBackgroundGrid(
      components: allComponents,
      excludeIndex: index,
      gridSize: gridSize,
      paletteLength: activePalette.length,
    );

    final agent = ShapeSculpterAgent();
    final context = AgentContext(
      gridSize: gridSize,
      activePalette: activePalette,
      userPrompt: userPrompt,
      targetComponent: comp,
      currentGrid: existingGrid,
      referenceImage: referenceImage,
      allComponents: allComponents,
    );

    return await agent.sculptComponent(_aiService, context);
  }

  /// Sculpt all components sequentially, notifying progress step-by-step.
  Future<List<PixelArtComponent>> sculptAllComponents({
    required List<PixelArtComponent> components,
    required int gridSize,
    required List<Color> activePalette,
    required String userPrompt,
    required Function(
      int activeIndex,
      List<PixelArtComponent> updated,
      String status,
    )
    onStep,
  }) async {
    final List<PixelArtComponent> updatedComponents = List.from(components);
    final agent = ShapeSculpterAgent();

    for (int i = 0; i < updatedComponents.length; i++) {
      onStep(i, updatedComponents, 'Sculpting shape...');
      var comp = updatedComponents[i];

      comp = comp.initializeDefaultGrid(gridSize);
      final existingGrid = buildBackgroundGrid(
        components: updatedComponents,
        excludeIndex: i,
        gridSize: gridSize,
        paletteLength: activePalette.length,
      );

      final context = AgentContext(
        gridSize: gridSize,
        activePalette: activePalette,
        userPrompt: userPrompt,
        targetComponent: comp,
        currentGrid: existingGrid,
        allComponents: updatedComponents,
      );

      final newGrid = await agent.sculptComponent(_aiService, context);
      updatedComponents[i] = comp.copyWith(grid: newGrid, isSculpted: true);

      onStep(i, List.from(updatedComponents), 'Sculpting shape...');
    }

    return updatedComponents;
  }
}
