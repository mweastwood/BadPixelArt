import 'dart:typed_data';
import 'canvas_state.dart';
import 'package:local_agent/local_agent.dart';
import 'prompts.dart';

class PixelArtAgentDelegate implements AgentDelegate {
  final AgentCanvas canvas;
  final Uint8List? referenceImageBmp;
  final Uint8List? previousCanvasBmp;

  late final List<String> paletteHexes;
  String? quantizedReferenceTextGrid;

  PixelArtAgentDelegate({
    required this.canvas,
    required this.referenceImageBmp,
    required this.previousCanvasBmp,
  }) {
    paletteHexes = canvas.palette.map((c) {
      return '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    }).toList();

    if (referenceImageBmp != null) {
      final quantizedGrid = getQuantizedIndexGrid(
        referenceImageBmp!,
        canvas.palette,
      );
      quantizedReferenceTextGrid = canvasToTextGrid(quantizedGrid);
    }
  }

  @override
  String formatPrompt(String userPrompt, List<AgentStepResult> history) {
    final currentCanvasTextGrid = canvasToTextGrid(canvas.grid);

    final historyBuffer = StringBuffer();
    for (int i = 0; i < history.length; i++) {
      final res = history[i];
      historyBuffer.write('\n[Step ${i + 1}] Thoughts: "${res.thought}"\n');
      historyBuffer.write(
        'Action: ${res.tool} with params ${res.params} and color index ${res.colorIndex}\n',
      );
      historyBuffer.write('Result: ${res.feedback}\n');
    }

    final systemInstruction = formatSystemInstruction();
    final canvasBmp = getVisualInput() ?? Uint8List(0);
    final userTextPrompt = formatUserPrompt(
      canvasImage: canvasBmp,
      prompt: userPrompt,
      paletteColors: paletteHexes,
      isMultimodal: true,
      hasPreviousImage: previousCanvasBmp != null,
      currentCanvasTextGrid: currentCanvasTextGrid,
      loopHistory: historyBuffer.toString(),
    );

    return '$systemInstruction\n\n$userTextPrompt';
  }

  @override
  Uint8List? getVisualInput() {
    return canvas.generateCombinedVisualInput(
      referenceImageBmp,
      previousCanvasBmp,
    );
  }

  @override
  Future<String> applyAction(Map<String, dynamic> actionMap) async {
    final tool = actionMap['tool'] as String? ?? '';
    final paramsRaw = actionMap['params'];
    final List<int> params = paramsRaw is List
        ? List<int>.from(paramsRaw.map((x) => x as int))
        : [];
    final colorIndex = actionMap['color'] as int? ?? 0;

    canvas.applyCommand(tool, params, colorIndex);

    return 'Executed $tool with params $params and color index $colorIndex.';
  }

  @override
  bool isFinishAction(Map<String, dynamic> actionMap) {
    final tool = actionMap['tool'] as String?;
    return tool == null || tool == 'finish';
  }
}
