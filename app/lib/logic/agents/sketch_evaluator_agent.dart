import 'base_agent.dart';

class SketchEvaluatorResult {
  final bool isComplete;
  final String feedback;
  final String suggestions;

  SketchEvaluatorResult({
    required this.isComplete,
    required this.feedback,
    required this.suggestions,
  });
}

class SketchEvaluatorAgent implements PixelArtAgent {
  @override
  String get name => 'sketch_evaluator';

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

    return 'You are an AI pixel art evaluator agent named "sketch_evaluator". Your job is to inspect the current grid of a component: "${comp.name}" (${comp.description}) and decide if it is finished and represents the shape volume well.\n'
        'The drawing is restricted to the bounding box: X: $minX to $maxX, Y: $minY to $maxY.\n\n'
        'Output rules:\n'
        '- You must output EXACTLY a valid JSON object. Do not wrap in markdown blocks.\n'
        '- The format must be:\n'
        '  {\n'
        '    "isComplete": true/false,\n'
        '    "feedback": "summary of the evaluation",\n'
        '    "suggestions": "what the painter/eraser should do next (empty if complete)"\n'
        '  }\n'
        '- If the drawing resembles the component description well (taking into account the low resolution of $gridSize x $gridSize grid), set "isComplete" to true.\n'
        '- If it is incomplete, or needs adjustment (e.g. too skinny, misaligned, has stray pixels), set "isComplete" to false and write concrete suggestions (specifying coords if needed).';
  }

  @override
  String getFormattedUserPrompt(
    AgentContext context,
    List<PixelArtStepResult> history,
  ) {
    final comp = context.targetComponent!;
    final sb = StringBuffer();
    sb.writeln('Evaluating sketch for component: "${comp.name}"');
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
        sb.writeln('- Action: ${step.tool} with params ${step.params}');
        sb.writeln('  Feedback/Result: ${step.feedback}');
      }
    }

    sb.writeln(
      '\nEvaluate the drawing and return JSON (isComplete, feedback, suggestions):',
    );
    return sb.toString();
  }
}
