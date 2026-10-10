import 'package:flutter/foundation.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import 'canvas_state.dart';
import 'utils/database.dart';
import 'utils/database_helpers.dart';

/// Loads the canvas state from the persisted workspace session, falling back
/// to a default blank canvas when nothing (valid) is stored.
Future<CanvasModel> loadInitialCanvasState(AppDatabase db) async {
  try {
    final session = await db.getSession();
    if (session != null && session.activeCreationId != null) {
      final creation = await db.getCreationById(session.activeCreationId!);
      if (creation != null) {
        final logContext = 'creation ${creation.id}';
        final palette = resolvePalette(
          creation.paletteColors,
          logContext: logContext,
        );
        final recoveredGrid = tryDeserializeGrid(
          creation.gridData,
          gridSize: creation.gridSize,
          paletteLength: palette.length,
          logContext: logContext,
        );
        final grid = recoveredGrid ?? createBlankGrid(creation.gridSize);
        final components = deserializeComponents(creation.decomposedComponents);
        final history = deserializeHistory(creation.aiHistoryLogs);
        final tool = CanvasTool.values.firstWhere(
          (t) => t.name == session.selectedTool,
          orElse: () => CanvasTool.line,
        );

        return CanvasModel(
          creationId: creation.id,
          title: creation.title,
          gridSize: creation.gridSize,
          grid: grid,
          isGridRecovered: recoveredGrid == null,
          paletteName: creation.paletteName,
          palette: palette,
          decomposedComponents: components,
          aiHistory: history,
          referenceImage: creation.referenceImage,
          originalReferenceImage: creation.originalReferenceImage,
          selectedColorIndex: clampColorIndex(
            session.selectedColorIndex,
            palette.length,
          ),
          selectedTool: tool,
          userPrompt: session.userPrompt,
          undoStack: const [],
          redoStack: const [],
          aiStatus: AiCoreStatus.available,
          isGenerating: false,
          autoRun: false,
          autoRunSpeed: 1.5,
        );
      }
    }
  } catch (e) {
    debugPrint('Error loading initial canvas state: $e');
  }
  return CanvasModel(
    gridSize: 16,
    grid: List.generate(16, (_) => List.filled(16, 0)),
    selectedColorIndex: 1,
    selectedTool: CanvasTool.line,
    paletteName: 'primary',
    palette: CanvasNotifier.primaryPalette,
    userPrompt: '',
    aiStatus: AiCoreStatus.available,
    isGenerating: false,
    autoRun: false,
    autoRunSpeed: 1.5,
    undoStack: const [],
    redoStack: const [],
    aiHistory: const [],
  );
}
