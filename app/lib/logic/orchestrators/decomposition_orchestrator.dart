import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import '../agents/base_agent.dart';
import '../agents/decomposer_agent.dart';

/// Orchestrates decomposition agent operations for [CanvasNotifier].
class DecompositionOrchestrator {
  final AiService _aiService;

  DecompositionOrchestrator(this._aiService);

  /// Executes decomposition on the provided canvas context.
  Future<DecomposerResult> decompose({
    required int gridSize,
    required List<Color> activePalette,
    required String userPrompt,
    required List<List<int>> currentGrid,
    required Uint8List? referenceImage,
  }) async {
    final agent = DecomposerAgent();
    final context = AgentContext(
      gridSize: gridSize,
      activePalette: activePalette,
      userPrompt: userPrompt,
      currentGrid: currentGrid,
      referenceImage: referenceImage,
    );

    return await agent.decompose(_aiService, context);
  }
}
