import 'base_agent.dart';

class EraserAgent implements PixelArtAgent {
  @override
  String get name => 'Eraser';

  @override
  List<String> get availableTools => const ['line', 'pixel', 'pixels'];

  @override
  String getSystemInstruction(AgentContext context) {
    final comp = context.targetComponent;
    final compInfo = comp != null
        ? 'You are currently sculpting the outline for the component "${comp.name}" (${comp.description}) inside the bounding box (normalized coordinates: x=${comp.relativeBoundingBox.left.toStringAsFixed(2)}, y=${comp.relativeBoundingBox.top.toStringAsFixed(2)}, w=${comp.relativeBoundingBox.width.toStringAsFixed(2)}, h=${comp.relativeBoundingBox.height.toStringAsFixed(2)}).\n'
        : 'You are erasing/sculpting outlines on the canvas.\n';

    return 'You are an AI pixel art eraser agent. Your goal is to subtract/erase pixels to carve and sculpt outlines on a ${context.gridSize}x${context.gridSize} grid (coordinates 0 to ${context.gridSize - 1}).\n'
        '$compInfo'
        'You MUST set the "color" field to 0 (eraser). Your role is to fix double-pixels, clean up messy corners, and make outlines look clean and thin.\n\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON block containing: "understanding", "reasoning", "tool", "params", and "color".\n'
        '- Always set "color" to 0.\n'
        '- Keep "understanding" and "reasoning" under 15 words.\n'
        '- Example:\n'
        '{\n'
        '  "understanding": "Remove stray pixel",\n'
        '  "reasoning": "Thinning the top curve of the outline",\n'
        '  "tool": "pixel",\n'
        '  "params": [5, 6],\n'
        '  "color": 0\n'
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

    final comp = context.targetComponent;
    final targetDescription = comp != null
        ? 'Component Name: ${comp.name}\nDescription: ${comp.description}\nTarget Bounding Box on Canvas: ${comp.relativeBoundingBox}'
        : 'User drawing prompt: "${context.userPrompt}"';

    return 'TARGET:\n$targetDescription\n\n'
        'Current grid resolution: ${context.gridSize}x${context.gridSize}\n'
        'Recent strokes history in this sequence:$historyBuffer\n\n'
        'Identify any unnecessary/bloated outline pixels on the canvas and propose an erase stroke (color index 0) to carve the outline.';
  }
}
