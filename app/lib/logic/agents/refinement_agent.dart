import 'base_agent.dart';

class RefinementAgent implements PixelArtAgent {
  @override
  String get name => 'refinement';

  @override
  List<String> get availableTools => [
    'pixel',
    'pixels',
    'line',
    'circle',
    'rectangle',
    'done',
    'none',
    // NOTE: 'ellipse' (outline) was intentionally removed alongside
    // 'ellipse_filled', 'circle_filled', 'rectangle_filled', 'fill', and
    // 'triangle'. The refinement stage is restricted to pixel-precise,
    // non-destructive tools (pixel, pixels, line, circle, rectangle) to avoid
    // accidentally overwriting gradients or large canvas regions during
    // touch-up passes.
  ];

  @override
  String getSystemInstruction(AgentContext context) {
    final gridSize = context.gridSize;
    final paletteLength = context.activePalette.length;

    final toolHelp = StringBuffer();
    toolHelp.writeln('Available refinement tools and parameters:');
    toolHelp.writeln(
      '- {"tool": "pixel", "params": [x, y], "colorIndex": idx} (draws or clears a single pixel)',
    );
    toolHelp.writeln(
      '- {"tool": "pixels", "params": [x1, y1, x2, y2, ...], "colorIndex": idx} (modifies multiple specific pixels)',
    );
    toolHelp.writeln(
      '- {"tool": "line", "params": [x1, y1, x2, y2], "colorIndex": idx} (draws an outline stroke or edge line)',
    );
    toolHelp.writeln(
      '- {"tool": "circle", "params": [centerX, centerY, radius], "colorIndex": idx} (draws a thin outline circle; fractional coordinates like 7.5 on a 16x16 grid are supported for symmetry)',
    );
    toolHelp.writeln(
      '- {"tool": "rectangle", "params": [x1, y1, x2, y2], "colorIndex": idx} (draws a thin outline box)',
    );
    toolHelp.writeln(
      '- {"tool": "done", "params": [], "colorIndex": 0} (signals that refinement is complete)',
    );

    return 'You are an AI pixel art refinement agent named "refinement". Your goal is to inspect the current pixel art canvas and description, and make subtle, targeted refinements (highlights, shading, outline cleanups, stray pixel removal) using the active palette.\n'
        'You have no spatial constraints. You can draw anywhere on the grid from X: 0 to ${gridSize - 1}, Y: 0 to ${gridSize - 1}.\n'
        'Coordinates are 0-indexed.\n\n'
        'You can draw using any color from the active palette. The palette has $paletteLength colors. The colorIndex must be an integer from 1 to $paletteLength (where 1 is the first color, 2 is the second, etc.), or 0 to erase/clear to transparent.\n\n'
        '${toolHelp.toString()}\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON object. Do not wrap in markdown blocks.\n'
        '- Format: { "thought": "reasoning for this step", "tool": "toolName", "params": [...], "colorIndex": int }\n'
        '- Keep edits subtle and targeted to preserve existing gradients and shapes.\n'
        '- TERMINATION: If the artwork looks complete and requires no further touch-ups, immediately return:\n'
        '  { "thought": "Artwork is complete and polished.", "tool": "done", "params": [], "colorIndex": 0 }';
  }

  @override
  String getFormattedUserPrompt(
    AgentContext context,
    List<PixelArtStepResult> history,
  ) {
    final sb = StringBuffer();
    sb.writeln('Drawing Description: "${context.userPrompt}"');

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

    if (context.isTemplate) {
      sb.writeln('\nTemplate Structural Semantics:');
      sb.writeln('- Index 1: Outline / Hair / Silhouette contour');
      sb.writeln('- Index 2: Main body / Skin / Primary clothing fill');
      sb.writeln('- Index 3: Eye / Accent / Highlight features');
      sb.writeln(
        'Refinement Directive: Add micro-details, shadows, highlights, and facial expression refinements on top of the established character sprite foundation without destroying the core silhouette.',
      );
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

    sb.writeln(
      '\nPropose the next refinement drawing action (or "tool": "done" if finished):',
    );
    return sb.toString();
  }
}
