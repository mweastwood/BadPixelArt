// ignore_for_file: deprecated_member_use
import 'base_agent.dart';

class DecomposerAgent implements PixelArtAgent {
  @override
  String get name => 'Decomposer';

  @override
  List<String> get availableTools => const [];

  @override
  String getSystemInstruction(AgentContext context) {
    return 'You are a master pixel art director. Your job is to analyze a user prompt and decompose the target drawing into a set of 1 to 4 logical visual components.\n'
        'For each component, you must provide:\n'
        '- "name": A unique, short name (e.g. "blade", "hilt", "guard" for a sword).\n'
        '- "description": A descriptive note of its shape, outlines, and features.\n'
        '- "boundingBox": A dictionary with keys "x", "y", "w", "h" as normalized floating point values (from 0.0 to 1.0) defining the region it occupies on the canvas.\n'
        '- "color": A suggested hex color string for this component chosen to match the palette.\n\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON list containing these objects.\n'
        '- Do not write markdown blocks (e.g. ```json) or explanations outside the JSON list.';
  }

  @override
  String getFormattedUserPrompt(AgentContext context, List<dynamic> history) {
    final paletteHexes = context.activePalette
        .map(
          (c) => '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        )
        .toList();

    return 'Please decompose the following pixel art drawing prompt:\n'
        'Drawing prompt: "${context.userPrompt}"\n'
        'Target grid resolution: ${context.gridSize}x${context.gridSize}\n\n'
        'Choose the closest matching hex colors from this available palette:\n'
        '${paletteHexes.join(', ')}';
  }
}
