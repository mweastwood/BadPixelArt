import 'base_agent.dart';

class SketchEraserAgent implements PixelArtAgent {
  @override
  String get name => 'sketch_eraser';

  @override
  List<String> get availableTools => [
    'circle_filled',
    'rectangle_filled',
    'ellipse_filled',
    'triangle',
  ];

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

    return 'You are an AI pixel art eraser agent named "sketch_eraser". Your goal is to REMOVE pixels (erase) to sculpt or clean the shape volume of a specific component: "${comp.name}" (${comp.description}).\n'
        'You must erase within its bounding box: X: $minX to $maxX, Y: $minY to $maxY.\n'
        'All coordinates are 0-indexed integers from 0 to ${gridSize - 1}.\n\n'
        'You are restricted to ONLY using filled shapes to erase regions. You must NOT use lines, single pixels, or outlines.\n'
        'Available tools and parameters (actions with these will clear/erase the pixels in their region):\n'
        '- {"tool": "circle_filled", "params": [centerX, centerY, radius]}\n'
        '- {"tool": "rectangle_filled", "params": [x1, y1, x2, y2]}\n'
        '- {"tool": "ellipse_filled", "params": [centerX, centerY, rx, ry]}\n'
        '- {"tool": "triangle", "params": [x1, y1, x2, y2, x3, y3]} (erases the region of a filled triangle)\n\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON object. Do not wrap in markdown blocks.\n'
        '- The format must be: { "thought": "reasoning for erasing", "tool": "toolName", "params": [int, int, ...] }\n'
        '- Ensure all coordinates are strictly within the bounding box bounds: X in [$minX, $maxX], Y in [$minY, $maxY].\n'
        '- Identify stray pixels, over-filled areas, or double corners inside the component bounds and propose clearing them.';
  }

  @override
  String getFormattedUserPrompt(
    AgentContext context,
    List<PixelArtStepResult> history,
  ) {
    final comp = context.targetComponent!;
    final sb = StringBuffer();
    sb.writeln('Erasing / Sculpting component: "${comp.name}"');
    sb.writeln('Description: "${comp.description}"');
    sb.writeln('\nCurrent grid state (0=empty, 1=filled):');

    final size = context.gridSize;
    for (int y = 0; y < size; y++) {
      final row = context.currentGrid[y].map((v) => v > 0 ? '#' : '.').join('');
      sb.writeln(row);
    }

    if (history.isNotEmpty) {
      sb.writeln('\nHistory of actions in this phase:');
      for (final step in history) {
        sb.writeln('- Thought: ${step.thought}');
        sb.writeln('  Action: ${step.tool} with params ${step.params}');
        sb.writeln('  Feedback: ${step.feedback}');
      }
    }

    sb.writeln('\nPropose the next erasing action to sculpt "${comp.name}":');
    return sb.toString();
  }
}
