import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/pixel_art_component.dart';

export '../models/pixel_art_component.dart';

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

class AgentContext {
  final int gridSize;
  final List<Color> activePalette;
  final String userPrompt;
  final PixelArtComponent? targetComponent; // Bounding box and sub-description
  final List<List<int>> currentGrid;
  final Uint8List? referenceImage;
  final List<PixelArtComponent>? allComponents;

  AgentContext({
    required this.gridSize,
    required this.activePalette,
    required this.userPrompt,
    this.targetComponent,
    required this.currentGrid,
    this.referenceImage,
    this.allComponents,
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
