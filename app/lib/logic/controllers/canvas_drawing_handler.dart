import '../commands/base_command.dart';
import 'canvas_history_controller.dart';

/// Handler responsible for drawing coordinate validation, pixel placement, and command execution.
class CanvasDrawingHandler {
  final CanvasHistoryController historyController;

  const CanvasDrawingHandler({
    this.historyController = const CanvasHistoryController(),
  });

  /// Draws a single pixel on [grid] at coordinate ([x], [y]) with [colorIndex].
  ///
  /// Returns a new cloned 2D grid matrix if the coordinates are within bounds [0, [gridSize]),
  /// or `null` if the coordinate is out of bounds.
  List<List<int>>? drawPixel(
    List<List<int>> grid,
    int x,
    int y,
    int colorIndex,
    int gridSize,
  ) {
    if (x < 0 || x >= gridSize || y < 0 || y >= gridSize) {
      return null;
    }
    final newGrid = historyController.cloneGrid(grid);
    newGrid[y][x] = colorIndex;
    return newGrid;
  }

  /// Executes a [DrawingCommand] on a copy of [grid] using [colorIndex] and [gridSize].
  ///
  /// Returns the updated 2D grid matrix.
  List<List<int>> executeCommand(
    List<List<int>> grid,
    DrawingCommand command,
    int colorIndex,
    int gridSize,
  ) {
    final newGrid = historyController.cloneGrid(grid);
    command.execute(newGrid, colorIndex, gridSize);
    return newGrid;
  }
}
