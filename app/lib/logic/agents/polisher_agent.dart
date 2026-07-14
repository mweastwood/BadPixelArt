// ignore_for_file: deprecated_member_use
import 'base_agent.dart';

class PolisherAgent implements PixelArtAgent {
  @override
  String get name => 'Polisher';

  @override
  List<String> get availableTools => const [];

  @override
  String getSystemInstruction(AgentContext context) {
    return 'You are an AI pixel art master polisher agent. Your job is to analyze the canvas grid and suggest micro-adjustments for a specific polish action.\n'
        'The available polish actions are:\n'
        '1. "anti-aliasing": Soften jagged lines by placing intermediate-shade pixels on corner diagonals.\n'
        '2. "selout" (Selective Outlining): Replace dark outlines with lighter shades where light would hit them.\n\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON block containing: "reasoning" and "modifications".\n'
        '- "modifications": A list of lists, where each list is a triplet of [x, y, colorIndex] representing a pixel modification.\n'
        '- Keep "reasoning" under 15 words.\n'
        '- Do not write markdown blocks (e.g. ```json) or explanations outside the JSON.\n'
        '- Example:\n'
        '{\n'
        '  "reasoning": "Softening the sharp corner of the blade",\n'
        '  "modifications": [[5, 6, 2], [6, 5, 2]]\n'
        '}';
  }

  @override
  String getFormattedUserPrompt(AgentContext context, List<dynamic> history) {
    // Generate text grid representation
    final gridRepresentation = StringBuffer();
    for (int y = 0; y < context.gridSize; y++) {
      for (int x = 0; x < context.gridSize; x++) {
        final val = context.currentGrid[y][x];
        gridRepresentation.write(val == 0 ? '.' : val.toString());
      }
      gridRepresentation.write('\n');
    }

    final paletteHexes = context.activePalette
        .map(
          (c) => '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        )
        .toList();

    final paletteText = StringBuffer();
    for (int i = 0; i < paletteHexes.length; i++) {
      paletteText.writeln('Index ${i + 1}: ${paletteHexes[i]}');
    }

    // We can pass the action to apply via the userPrompt field of the context
    final action = context.userPrompt;

    return 'POLISH ACTION REQUESTED: "$action"\n\n'
        'Current grid state (numbers indicate color indices, . is transparent/empty):\n'
        '${gridRepresentation.toString()}\n'
        'Available Palette:\n'
        '${paletteText.toString()}\n'
        'Please suggest the exact pixel coordinate modifications [x, y, colorIndex] to execute this polish action.';
  }
}
