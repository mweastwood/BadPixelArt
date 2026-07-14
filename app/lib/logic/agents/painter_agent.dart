// ignore_for_file: deprecated_member_use
import 'base_agent.dart';

class PainterAgent implements PixelArtAgent {
  @override
  String get name => 'Painter';

  @override
  List<String> get availableTools => const [
    'line',
    'circle',
    'pixel',
    'pixels',
  ];

  @override
  String getSystemInstruction(AgentContext context) {
    final comp = context.targetComponent;
    final compInfo = comp != null
        ? 'You are currently drawing the outline for the component "${comp.name}" (${comp.description}) inside the bounding box (normalized coordinates: x=${comp.relativeBoundingBox.left.toStringAsFixed(2)}, y=${comp.relativeBoundingBox.top.toStringAsFixed(2)}, w=${comp.relativeBoundingBox.width.toStringAsFixed(2)}, h=${comp.relativeBoundingBox.height.toStringAsFixed(2)}).\n'
        : 'You are drawing pixel art outlines on the canvas.\n';

    return 'You are an AI pixel art assistant painter agent. Your goal is to draw clean outlines on a ${context.gridSize}x${context.gridSize} grid (coordinates 0 to ${context.gridSize - 1}).\n'
        '$compInfo'
        'You can only ADD pixels to form outlines. Do not fill the interior; focus entirely on clean, single-pixel outlines.\n\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON block containing: "understanding", "reasoning", "tool", "params", and "color".\n'
        '- Set "color" to a non-zero index from the available palette (usually index 1 or the outline color index).\n'
        '- Keep "understanding" and "reasoning" under 15 words.\n'
        '- Example:\n'
        '{\n'
        '  "understanding": "Need to draw base hilt line",\n'
        '  "reasoning": "Placing a horizontal line at the hilt position",\n'
        '  "tool": "line",\n'
        '  "params": [6, 12, 10, 12],\n'
        '  "color": 1\n'
        '}';
  }

  @override
  String getFormattedUserPrompt(AgentContext context, List<dynamic> history) {
    final historyBuffer = StringBuffer();
    for (int i = 0; i < history.length; i++) {
      final res = history[i];
      historyBuffer.write(
        '\n[Step ${i + 1}] Action: ${res['tool']} with params ${res['params']} -> Result: ${res['feedback']}\n',
      );
    }

    final paletteHexes = context.activePalette
        .map(
          (c) => '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        )
        .toList();

    final comp = context.targetComponent;
    final targetDescription = comp != null
        ? 'Component Name: ${comp.name}\nDescription: ${comp.description}\nTarget Bounding Box on Canvas: ${comp.relativeBoundingBox}'
        : 'User drawing prompt: "${context.userPrompt}"';

    return 'TARGET:\n$targetDescription\n\n'
        'Available Palette (hex colors):\n'
        '${paletteHexes.join(', ')}\n\n'
        'Current grid resolution: ${context.gridSize}x${context.gridSize}\n'
        'Recent strokes history in this sequence:$historyBuffer\n\n'
        'Propose your next stroke to build the outlines of this component.';
  }
}
