import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../models/canvas_model.dart';
import '../utils/database.dart';
import '../utils/database_helpers.dart';

final canvasRepositoryProvider = Provider<CanvasRepository>((ref) {
  return CanvasRepository();
});

/// Repository handling database operations and persistence for [CanvasModel].
class CanvasRepository {
  final AppDatabase Function() _getDb;

  CanvasRepository({AppDatabase Function()? dbGetter})
    : _getDb = dbGetter ?? (() => AppDatabaseHelper.db);

  AppDatabase get _db => _getDb();

  /// Saves the current canvas state to DB (Creations table and WorkspaceSessions table).
  /// Returns the updated [CanvasModel] with creationId set.
  Future<CanvasModel> saveCanvas(CanvasModel state) async {
    final now = DateTime.now();

    final creationsCompanion = CreationsCompanion(
      title: drift.Value(state.title),
      gridSize: drift.Value(state.gridSize),
      gridData: drift.Value(serializeGrid(state.grid)),
      paletteName: drift.Value(state.paletteName),
      paletteColors: drift.Value(serializePalette(state.palette)),
      decomposedComponents: drift.Value(
        serializeComponents(state.decomposedComponents),
      ),
      aiHistoryLogs: drift.Value(serializeHistory(state.aiHistory)),
      referenceImage: drift.Value(state.referenceImage),
      originalReferenceImage: drift.Value(state.originalReferenceImage),
      updatedAt: drift.Value(now),
    );

    int? creationId = state.creationId;
    if (creationId == null) {
      final newCompanion = creationsCompanion.copyWith(
        createdAt: drift.Value(now),
      );
      creationId = await _db.createCreation(newCompanion);
    } else {
      final updateCompanion = creationsCompanion.copyWith(
        id: drift.Value(creationId),
      );
      await _db.updateCreation(updateCompanion);
    }

    final updatedState = state.copyWith(creationId: creationId);

    final sessionCompanion = WorkspaceSessionsCompanion(
      id: const drift.Value(1),
      activeCreationId: drift.Value(creationId),
      selectedColorIndex: drift.Value(updatedState.selectedColorIndex),
      selectedTool: drift.Value(updatedState.selectedTool.name),
      userPrompt: drift.Value(updatedState.userPrompt),
      lastSavedAt: drift.Value(now),
    );
    await _db.saveSession(sessionCompanion);

    return updatedState;
  }

  /// Loads creation by id from DB and updates the workspace session.
  /// Returns updated state or null if creation is not found.
  Future<CanvasModel?> loadCanvas(int id, CanvasModel currentState) async {
    final creation = await _db.getCreationById(id);
    if (creation == null) return null;

    final grid = deserializeGrid(creation.gridData);
    final palette = deserializePalette(creation.paletteColors);
    final components = deserializeComponents(creation.decomposedComponents);
    final history = deserializeHistory(creation.aiHistoryLogs);

    final newState = currentState.copyWith(
      creationId: creation.id,
      title: creation.title,
      gridSize: creation.gridSize,
      grid: grid,
      paletteName: creation.paletteName,
      palette: palette,
      decomposedComponents: components,
      aiHistory: history,
      referenceImage: creation.referenceImage,
      originalReferenceImage: creation.originalReferenceImage,
      undoStack: const [],
      redoStack: const [],
      autoRun: false,
    );

    final now = DateTime.now();
    final sessionCompanion = WorkspaceSessionsCompanion(
      id: const drift.Value(1),
      activeCreationId: drift.Value(creation.id),
      selectedColorIndex: drift.Value(newState.selectedColorIndex),
      selectedTool: drift.Value(newState.selectedTool.name),
      userPrompt: drift.Value(newState.userPrompt),
      lastSavedAt: drift.Value(now),
    );
    await _db.saveSession(sessionCompanion);

    return newState;
  }

  /// Loads last saved session and its associated creation.
  /// Returns updated state if found, or null otherwise.
  Future<CanvasModel?> loadLastSession(CanvasModel currentState) async {
    final session = await _db.getSession();
    if (session != null && session.activeCreationId != null) {
      final creation = await _db.getCreationById(session.activeCreationId!);
      if (creation != null) {
        final grid = deserializeGrid(creation.gridData);
        final palette = deserializePalette(creation.paletteColors);
        final components = deserializeComponents(creation.decomposedComponents);
        final history = deserializeHistory(creation.aiHistoryLogs);

        final tool = CanvasTool.values.firstWhere(
          (t) => t.name == session.selectedTool,
          orElse: () => CanvasTool.line,
        );

        return currentState.copyWith(
          creationId: creation.id,
          title: creation.title,
          gridSize: creation.gridSize,
          grid: grid,
          paletteName: creation.paletteName,
          palette: palette,
          decomposedComponents: components,
          aiHistory: history,
          referenceImage: creation.referenceImage,
          originalReferenceImage: creation.originalReferenceImage,
          selectedColorIndex: session.selectedColorIndex,
          selectedTool: tool,
          userPrompt: session.userPrompt,
          undoStack: const [],
          redoStack: const [],
        );
      }
    }
    return null;
  }

  /// Saves session with no active creation ID (for brand new canvas).
  Future<void> saveNewSession(CanvasModel state) async {
    final now = DateTime.now();
    final sessionCompanion = WorkspaceSessionsCompanion(
      id: const drift.Value(1),
      activeCreationId: const drift.Value(null),
      selectedColorIndex: drift.Value(state.selectedColorIndex),
      selectedTool: drift.Value(state.selectedTool.name),
      userPrompt: drift.Value(state.userPrompt),
      lastSavedAt: drift.Value(now),
    );
    await _db.saveSession(sessionCompanion);
  }

  /// Duplicates a creation by ID and returns the new creation's ID.
  Future<int?> duplicateCanvas(int id) async {
    final creation = await _db.getCreationById(id);
    if (creation == null) return null;

    final now = DateTime.now();
    final duplicateCompanion = CreationsCompanion(
      title: drift.Value('${creation.title} (Copy)'),
      gridSize: drift.Value(creation.gridSize),
      gridData: drift.Value(creation.gridData),
      paletteName: drift.Value(creation.paletteName),
      paletteColors: drift.Value(creation.paletteColors),
      decomposedComponents: drift.Value(creation.decomposedComponents),
      aiHistoryLogs: drift.Value(creation.aiHistoryLogs),
      referenceImage: drift.Value(creation.referenceImage),
      originalReferenceImage: drift.Value(creation.originalReferenceImage),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    );

    return await _db.createCreation(duplicateCompanion);
  }

  /// Deletes a creation by ID from DB and returns the ID of the next creation to load, if any exist.
  Future<int?> deleteCanvas(int id) async {
    await _db.deleteCreation(id);
    final creationsList = await _db.getAllCreations();
    if (creationsList.isNotEmpty) {
      return creationsList.first.id;
    }
    return null;
  }

  /// Returns a list of all saved creations.
  Future<List<Creation>> getAllCreations() async {
    return await _db.getAllCreations();
  }

  /// Renames a creation by ID without modifying other fields.
  Future<void> renameCanvasById(int id, String newTitle) async {
    final creationData = await _db.getCreationById(id);
    if (creationData != null) {
      final now = DateTime.now();
      await _db.updateCreation(
        CreationsCompanion(
          id: drift.Value(id),
          title: drift.Value(newTitle),
          gridSize: drift.Value(creationData.gridSize),
          gridData: drift.Value(creationData.gridData),
          paletteName: drift.Value(creationData.paletteName),
          paletteColors: drift.Value(creationData.paletteColors),
          decomposedComponents: drift.Value(creationData.decomposedComponents),
          aiHistoryLogs: drift.Value(creationData.aiHistoryLogs),
          referenceImage: drift.Value(creationData.referenceImage),
          originalReferenceImage: drift.Value(
            creationData.originalReferenceImage,
          ),
          createdAt: drift.Value(creationData.createdAt),
          updatedAt: drift.Value(now),
        ),
      );
    }
  }
}
