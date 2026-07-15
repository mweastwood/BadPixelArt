import 'package:flutter/material.dart';

abstract class PixelArtAgent {
  String get name;

  /// Supported tools (e.g. ['line', 'circle', 'fill'] for painter, or ['erase'] for eraser).
  List<String> get availableTools;

  /// Builds the system instructions dynamically using state metadata.
  String getSystemInstruction(AgentContext context);

  /// Standard user prompt construction for this agent.
  String getFormattedUserPrompt(
    AgentContext context,
    List<PixelArtStepResult> history,
  );
}

class PixelArtComponent {
  final String name;
  final String description;
  final Rect relativeBoundingBox; // Normalized bounding box (0.0 to 1.0)

  PixelArtComponent({
    required this.name,
    required this.description,
    required this.relativeBoundingBox,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'relativeBoundingBox': {
        'left': relativeBoundingBox.left,
        'top': relativeBoundingBox.top,
        'width': relativeBoundingBox.width,
        'height': relativeBoundingBox.height,
      },
    };
  }

  factory PixelArtComponent.fromJson(Map<String, dynamic> json) {
    final bbox = json['relativeBoundingBox'] as Map<String, dynamic>;
    return PixelArtComponent(
      name: json['name'] as String,
      description: json['description'] as String,
      relativeBoundingBox: Rect.fromLTWH(
        (bbox['left'] as num).toDouble(),
        (bbox['top'] as num).toDouble(),
        (bbox['width'] as num).toDouble(),
        (bbox['height'] as num).toDouble(),
      ),
    );
  }
}

class AgentContext {
  final int gridSize;
  final List<Color> activePalette;
  final String userPrompt;
  final PixelArtComponent? targetComponent; // Bounding box and sub-description
  final List<List<int>> currentGrid;

  AgentContext({
    required this.gridSize,
    required this.activePalette,
    required this.userPrompt,
    this.targetComponent,
    required this.currentGrid,
  });
}

class PixelArtStepResult {
  final String thought;
  final String tool;
  final List<int> params;
  final int colorIndex;
  final String feedback;

  PixelArtStepResult({
    required this.thought,
    required this.tool,
    required this.params,
    required this.colorIndex,
    required this.feedback,
  });

  Map<String, dynamic> toJson() {
    return {
      'thought': thought,
      'tool': tool,
      'params': params,
      'colorIndex': colorIndex,
      'feedback': feedback,
    };
  }

  factory PixelArtStepResult.fromJson(Map<String, dynamic> json) {
    return PixelArtStepResult(
      thought: json['thought'] as String? ?? '',
      tool: json['tool'] as String? ?? '',
      params: List<int>.from(json['params'] as List? ?? []),
      colorIndex: json['colorIndex'] as int? ?? 0,
      feedback: json['feedback'] as String? ?? '',
    );
  }
}
