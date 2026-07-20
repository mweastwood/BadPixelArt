import 'base_agent.dart';

class RefinementAgent implements PixelArtAgent {
  @override
  String get name => 'refinement';

  @override
  List<String> get availableTools => [
    'pixel',
    'line',
    'circle',
    'circle_filled',
    'rectangle',
    'rectangle_filled',
    'fill',
    'ellipse',
    'ellipse_filled',
    'triangle',
  ];

  @override
  String getSystemInstruction(AgentContext context) {
    final gridSize = context.gridSize;
    final paletteLength = context.activePalette.length;

    final toolHelp = StringBuffer();
    toolHelp.writeln('Available tools and parameters:');
    toolHelp.writeln(
      '- {"tool": "pixel", "params": [x, y], "colorIndex": idx}',
    );
    toolHelp.writeln(
      '- {"tool": "line", "params": [x1, y1, x2, y2], "colorIndex": idx}',
    );
    toolHelp.writeln(
      '- {"tool": "circle", "params": [centerX, centerY, radius], "colorIndex": idx}',
    );
    toolHelp.writeln(
      '- {"tool": "circle_filled", "params": [centerX, centerY, radius], "colorIndex": idx}',
    );
    toolHelp.writeln(
      '- {"tool": "rectangle", "params": [x1, y1, x2, y2], "colorIndex": idx}',
    );
    toolHelp.writeln(
      '- {"tool": "rectangle_filled", "params": [x1, y1, x2, y2], "colorIndex": idx}',
    );
    toolHelp.writeln(
      '- {"tool": "fill", "params": [x, y], "colorIndex": idx} (flood fills adjacent matching pixels)',
    );
    toolHelp.writeln(
      '- {"tool": "ellipse", "params": [centerX, centerY, rx, ry], "colorIndex": idx}',
    );
    toolHelp.writeln(
      '- {"tool": "ellipse_filled", "params": [centerX, centerY, rx, ry], "colorIndex": idx}',
    );
    toolHelp.writeln(
      '- {"tool": "triangle", "params": [x1, y1, x2, y2, x3, y3], "colorIndex": idx} (draws a filled triangle)',
    );

    return 'You are an AI pixel art refinement agent named "refinement". Your goal is to refine, shade, highlight, or edit the pixel art on the entire canvas.\n'
        'You have no spatial constraints. You can draw anywhere on the grid from X: 0 to ${gridSize - 1}, Y: 0 to ${gridSize - 1}.\n'
        'All coordinates are 0-indexed integers.\n\n'
        'You can draw using any color from the active palette. The palette has $paletteLength colors. The colorIndex must be an integer from 1 to $paletteLength (where 1 is the first color, 2 is the second, etc.), or 0 to erase/clear to transparent.\n\n'
        '${toolHelp.toString()}\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON object. Do not wrap in markdown blocks.\n'
        '- The format must be: { "thought": "reasoning for this step", "tool": "toolName", "params": [int, int, ...], "colorIndex": int }\n'
        '- Ensure all coordinates are strictly within the canvas bounds [0, ${gridSize - 1}].';
  }

  @override
  String getFormattedUserPrompt(
    AgentContext context,
    List<PixelArtStepResult> history,
  ) {
    final sb = StringBuffer();
    sb.writeln('Overall Prompt: "${context.userPrompt}"');

    sb.writeln('\nCurrent palette mapping:');
    for (int i = 0; i < context.activePalette.length; i++) {
      final color = context.activePalette[i];
      final hex =
          '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      sb.writeln('Index ${i + 1}: Hex $hex');
    }

    sb.writeln(
      '\nCurrent canvas grid (each cell is a color index 0-${context.activePalette.length}):',
    );
    final size = context.gridSize;
    for (int y = 0; y < size; y++) {
      final row = context.currentGrid[y]
          .map((v) => v.toString().padLeft(2))
          .join(' ');
      sb.writeln(row);
    }

    if (history.isNotEmpty) {
      sb.writeln('\nHistory of actions in this phase:');
      for (final step in history) {
        sb.writeln('- Thought: ${step.thought}');
        sb.writeln(
          '  Action: ${step.tool} with params ${step.params} using colorIndex ${step.colorIndex}',
        );
        sb.writeln('  Feedback: ${step.feedback}');
      }
    }

    sb.writeln('\nPropose the next refinement drawing action:');
    return sb.toString();
  }
}
