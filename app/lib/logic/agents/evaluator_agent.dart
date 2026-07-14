import 'base_agent.dart';

class EvaluatorAgent implements PixelArtAgent {
  @override
  String get name => 'Evaluator';

  @override
  List<String> get availableTools => const [];

  @override
  String getSystemInstruction(AgentContext context) {
    final comp = context.targetComponent;
    final compInfo = comp != null
        ? 'You are currently evaluating the outline for the component "${comp.name}" (${comp.description}) which should fit within the bounding box (normalized coordinates: x=${comp.relativeBoundingBox.left.toStringAsFixed(2)}, y=${comp.relativeBoundingBox.top.toStringAsFixed(2)}, w=${comp.relativeBoundingBox.width.toStringAsFixed(2)}, h=${comp.relativeBoundingBox.height.toStringAsFixed(2)}).\n'
        : 'You are evaluating the overall drawing outlines.\n';

    return 'You are an AI pixel art evaluator/critic agent. Your job is to inspect the current canvas grid and determine if the outlines are correct, clean, and match the target component description.\n'
        '$compInfo'
        'Look at the grid layout and verify that:\n'
        '1. The shape represents the target component.\n'
        '2. The line art is clean, not bloated with double-pixels or broken segments.\n'
        '3. It resides within or close to the target bounding box region.\n\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON block containing: "score", "critique", and "isSatisfied".\n'
        '- "score": An integer from 0 to 10 (10 being perfect outline).\n'
        '- "critique": A very concise explanation (max 1 sentence) of what is wrong or needs refinement.\n'
        '- "isSatisfied": A boolean (true if score is 8 or higher, meaning the outline is good and can be merged; false otherwise).\n'
        '- Do not write markdown blocks (e.g. ```json) or explanations outside the JSON.';
  }

  @override
  String getFormattedUserPrompt(AgentContext context, List<dynamic> history) {
    // Generate text representation of the grid for the evaluator to inspect
    final gridRepresentation = StringBuffer();
    for (int y = 0; y < context.gridSize; y++) {
      for (int x = 0; x < context.gridSize; x++) {
        final val = context.currentGrid[y][x];
        gridRepresentation.write(val == 0 ? '.' : '#');
      }
      gridRepresentation.write('\n');
    }

    return 'Please evaluate the current outlines on the canvas grid:\n'
        '${gridRepresentation.toString()}\n'
        'Evaluate this canvas against the target component details:\n'
        'Name: ${context.targetComponent?.name ?? "General"}\n'
        'Description: ${context.targetComponent?.description ?? context.userPrompt}\n'
        'Bounding Box: ${context.targetComponent?.relativeBoundingBox ?? "Whole canvas"}\n\n'
        'Provide your score, critique, and satisfaction status in the required JSON format.';
  }
}
