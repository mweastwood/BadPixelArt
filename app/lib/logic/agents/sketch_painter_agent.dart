import 'base_agent.dart';

class SketchPainterAgent implements PixelArtAgent {
  @override
  String get name => 'sketch_painter';

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

    final shapesInstruction = StringBuffer();
    if (comp.shapes.isNotEmpty) {
      shapesInstruction.writeln(
        '\nThis component is decomposed into the following fundamental geometric shapes that you should draw:',
      );
      for (final shape in comp.shapes) {
        final sBox = shape.relativeBoundingBox;
        final sMinX = (minX + sBox.left * (maxX - minX + 1)).round();
        final sMaxX =
            (minX + (sBox.left + sBox.width) * (maxX - minX + 1)).round() - 1;
        final sMinY = (minY + sBox.top * (maxY - minY + 1)).round();
        final sMaxY =
            (minY + (sBox.top + sBox.height) * (maxY - minY + 1)).round() - 1;

        final sMinXClamped = sMinX.clamp(minX, maxX);
        final sMaxXClamped = sMaxX.clamp(minX, maxX);
        final sMinYClamped = sMinY.clamp(minY, maxY);
        final sMaxYClamped = sMaxY.clamp(minY, maxY);

        shapesInstruction.writeln(
          '- A "${shape.type}" representing: "${shape.description}" inside local/absolute bounds: X in [$sMinXClamped, $sMaxXClamped], Y in [$sMinYClamped, $sMaxYClamped]',
        );
      }
      shapesInstruction.writeln(
        'Draw these shape primitives to construct the overall "${comp.name}" component.',
      );
    }

    return 'You are an AI pixel art painter agent named "sketch_painter". Your goal is to ADD pixels to fill the shape volume of a specific component: "${comp.name}" (${comp.description}).\n'
        'You must draw within its bounding box: X: $minX to $maxX, Y: $minY to $maxY.\n'
        'All coordinates are 0-indexed integers from 0 to ${gridSize - 1}.\n\n'
        'Try to utilize the allocated bounding box space fully (from X: $minX to $maxX, Y: $minY to $maxY) so the component fits well with other parts.\n\n'
        '${shapesInstruction.toString()}'
        '\nYou are restricted to ONLY using filled shapes. You must NOT draw lines, single pixels, or outlines.\n'
        'Available tools and parameters:\n'
        '- {"tool": "circle_filled", "params": [centerX, centerY, radius]}\n'
        '- {"tool": "rectangle_filled", "params": [x1, y1, x2, y2]}\n'
        '- {"tool": "ellipse_filled", "params": [centerX, centerY, rx, ry]}\n'
        '- {"tool": "triangle", "params": [x1, y1, x2, y2, x3, y3]} (draws a filled triangle)\n\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON object. Do not wrap in markdown blocks.\n'
        '- The format must be: { "thought": "reasoning for drawing", "tool": "toolName", "params": [int, int, ...] }\n'
        '- Ensure all coordinates are strictly within the bounding box bounds: X in [$minX, $maxX], Y in [$minY, $maxY].\n'
        '- Keep shapes solid and simple. Do not try to draw outlines yet; fill the volume.';
  }

  @override
  String getFormattedUserPrompt(
    AgentContext context,
    List<PixelArtStepResult> history,
  ) {
    final comp = context.targetComponent!;
    final sb = StringBuffer();
    sb.writeln('Drawing component: "${comp.name}"');
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

    sb.writeln(
      '\nPropose the next drawing action to fill the volume of "${comp.name}":',
    );
    return sb.toString();
  }
}
