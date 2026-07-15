import 'base_agent.dart';

class SketchEraserAgent implements PixelArtAgent {
  @override
  String get name => 'sketch_eraser';

  @override
  List<String> get availableTools => [];

  @override
  String getSystemInstruction(AgentContext context) {
    final comp = context.targetComponent;
    if (comp == null) return 'No target component provided.';

    final gridSize = context.gridSize;
    final bbox = comp.relativeBoundingBox;
    final minX = (bbox.left * gridSize).round();
    final maxX = ((bbox.left + bbox.width) * gridSize).round() - 1;
    final minY = (bbox.top * gridSize).round();
    final maxY = ((bbox.top + bbox.height) * gridSize).round() - 1;

    return 'You are an AI pixel art eraser agent named "sketch_eraser". Your goal is to REMOVE pixels (erase) to sculpt, smooth out outlines, or create curves for a specific component: "${comp.name}" (${comp.description}).\n'
        'You are given a list of all active pixels on the outline/border of the current shape.\n'
        'You must decide which of these border pixels should be erased to make the shape smoother, more circular, or curvier.\n\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON object. Do not wrap in markdown blocks.\n'
        '- The format must be: { "thought": "reasoning for erasing", "erase": [ [x, y], [x, y], ... ] }\n'
        '- In "erase", provide a JSON array of coordinate pairs [x, y] to be erased. Only suggest erasing pixels that are present in the provided list of border pixels.\n'
        '- Ensure all coordinates are strictly within the bounding box bounds: X in [$minX, $maxX], Y in [$minY, $maxY].';
  }

  @override
  String getFormattedUserPrompt(
    AgentContext context,
    List<PixelArtStepResult> history,
  ) {
    final comp = context.targetComponent!;
    final compGrid = context.currentGrid;
    final gridSize = context.gridSize;
    final bbox = comp.relativeBoundingBox;
    final minX = (bbox.left * gridSize).round();
    final maxX = ((bbox.left + bbox.width) * gridSize).round() - 1;
    final minY = (bbox.top * gridSize).round();
    final maxY = ((bbox.top + bbox.height) * gridSize).round() - 1;

    final List<String> borderCoords = [];
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        if (compGrid[y][x] > 0) {
          bool isBorder = false;
          if (y == minY || y == maxY || x == minX || x == maxX) {
            isBorder = true;
          } else {
            if (compGrid[y - 1][x] == 0 ||
                compGrid[y + 1][x] == 0 ||
                compGrid[y][x - 1] == 0 ||
                compGrid[y][x + 1] == 0) {
              isBorder = true;
            }
          }
          if (isBorder) {
            borderCoords.add('[$x, $y]');
          }
        }
      }
    }

    final sb = StringBuffer();
    sb.writeln('Erasing / Sculpting component: "${comp.name}"');
    sb.writeln('Description: "${comp.description}"');
    sb.writeln('\nCurrent grid state (0=empty, 1=filled):');

    for (int y = 0; y < gridSize; y++) {
      final row = compGrid[y].map((v) => v > 0 ? '#' : '.').join('');
      sb.writeln(row);
    }

    sb.writeln('\nActive border pixels currently on the shape outline:');
    sb.writeln('[${borderCoords.join(', ')}]');

    if (history.isNotEmpty) {
      sb.writeln('\nHistory of actions in this phase:');
      for (final step in history) {
        sb.writeln('- Thought: ${step.thought}');
        sb.writeln('  Action: ${step.tool} with params ${step.params}');
        sb.writeln('  Feedback: ${step.feedback}');
      }
    }

    sb.writeln(
      '\nPropose the list of coordinates to erase from the outline to sculpt and smooth it:',
    );
    return sb.toString();
  }
}
