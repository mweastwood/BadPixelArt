/// Result of pushing a snapshot onto the undo history stack.
class HistoryPushResult {
  final List<List<List<int>>> undoStack;
  final List<List<List<int>>> redoStack;

  const HistoryPushResult({required this.undoStack, required this.redoStack});
}

/// Alias for [HistoryPushResult] to represent history state snapshots.
typedef HistoryState = HistoryPushResult;

/// Result of performing an undo operation.
class HistoryUndoResult {
  final List<List<int>> grid;
  final List<List<List<int>>> undoStack;
  final List<List<List<int>>> redoStack;

  const HistoryUndoResult({
    required this.grid,
    required this.undoStack,
    required this.redoStack,
  });
}

/// Result of performing a redo operation.
class HistoryRedoResult {
  final List<List<int>> grid;
  final List<List<List<int>>> undoStack;
  final List<List<List<int>>> redoStack;

  const HistoryRedoResult({
    required this.grid,
    required this.undoStack,
    required this.redoStack,
  });
}

/// Controller responsible for managing undo/redo history stacks and 2D grid matrix cloning.
class CanvasHistoryController {
  const CanvasHistoryController();

  /// Performs a deep copy of a 2D integer [grid].
  List<List<int>> cloneGrid(List<List<int>> grid) {
    return grid.map((row) => List<int>.from(row)).toList();
  }

  /// Pushes a snapshot of [currentGrid] onto [undoStack] and clears the redo stack.
  ///
  /// Optionally caps the history depth using [maxHistory] (default 50).
  HistoryPushResult push(
    List<List<int>> currentGrid,
    List<List<List<int>>> undoStack, {
    int maxHistory = 50,
  }) {
    final clonedGrid = cloneGrid(currentGrid);
    final newUndo = List<List<List<int>>>.from(undoStack)..add(clonedGrid);
    if (maxHistory > 0 && newUndo.length > maxHistory) {
      newUndo.removeRange(0, newUndo.length - maxHistory);
    }
    return HistoryPushResult(undoStack: newUndo, redoStack: const []);
  }

  /// Restores the previous grid snapshot from [undoStack] and records [currentGrid] in [redoStack].
  ///
  /// Returns `null` if [undoStack] is empty.
  HistoryUndoResult? undo({
    required List<List<List<int>>> undoStack,
    required List<List<List<int>>> redoStack,
    required List<List<int>> currentGrid,
  }) {
    if (undoStack.isEmpty) return null;

    final newUndo = List<List<List<int>>>.from(undoStack);
    final previousGrid = newUndo.removeLast();

    final currentCloned = cloneGrid(currentGrid);
    final newRedo = List<List<List<int>>>.from(redoStack)..add(currentCloned);

    return HistoryUndoResult(
      grid: previousGrid,
      undoStack: newUndo,
      redoStack: newRedo,
    );
  }

  /// Restores the next grid snapshot from [redoStack] and records [currentGrid] in [undoStack].
  ///
  /// Returns `null` if [redoStack] is empty.
  HistoryRedoResult? redo({
    required List<List<List<int>>> undoStack,
    required List<List<List<int>>> redoStack,
    required List<List<int>> currentGrid,
  }) {
    if (redoStack.isEmpty) return null;

    final newRedo = List<List<List<int>>>.from(redoStack);
    final nextGrid = newRedo.removeLast();

    final currentCloned = cloneGrid(currentGrid);
    final newUndo = List<List<List<int>>>.from(undoStack)..add(currentCloned);

    return HistoryRedoResult(
      grid: nextGrid,
      undoStack: newUndo,
      redoStack: newRedo,
    );
  }
}
