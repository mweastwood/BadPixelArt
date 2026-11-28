/// Base class representing a drawing operation that can be executed on a grid.
abstract class DrawingCommand {
  /// Executes the drawing command on the given 2D [grid] using the provided [color] value.
  void execute(List<List<int>> grid, int color, int gridSize);
}
