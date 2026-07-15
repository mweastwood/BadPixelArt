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
  final List<List<int>>?
  grid; // Component specific sketch grid (0 = empty, 1 = filled volume)

  PixelArtComponent({
    required this.name,
    required this.description,
    required this.relativeBoundingBox,
    this.grid,
  });

  List<List<int>>? getOutlineGrid() {
    if (grid == null) return null;
    final size = grid!.length;
    final outline = List.generate(size, (_) => List.filled(size, 0));
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (grid![y][x] > 0) {
          bool hasBackgroundNeighbor = false;
          if (y == 0 || y == size - 1 || x == 0 || x == size - 1) {
            hasBackgroundNeighbor = true;
          } else {
            if (grid![y - 1][x] == 0 ||
                grid![y + 1][x] == 0 ||
                grid![y][x - 1] == 0 ||
                grid![y][x + 1] == 0) {
              hasBackgroundNeighbor = true;
            }
          }
          if (hasBackgroundNeighbor) {
            outline[y][x] = 1;
          }
        }
      }
    }
    return outline;
  }

  PixelArtComponent copyWith({
    String? name,
    String? description,
    Rect? relativeBoundingBox,
    List<List<int>>? grid,
  }) {
    return PixelArtComponent(
      name: name ?? this.name,
      description: description ?? this.description,
      relativeBoundingBox: relativeBoundingBox ?? this.relativeBoundingBox,
      grid: grid ?? this.grid,
    );
  }

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
      if (grid != null) 'grid': grid,
    };
  }

  factory PixelArtComponent.fromJson(Map<String, dynamic> json) {
    final bbox = json['relativeBoundingBox'] as Map<String, dynamic>;
    final gridRaw = json['grid'] as List?;
    List<List<int>>? parsedGrid;
    if (gridRaw != null) {
      parsedGrid = gridRaw.map((row) => List<int>.from(row as List)).toList();
    }
    return PixelArtComponent(
      name: json['name'] as String,
      description: json['description'] as String,
      relativeBoundingBox: Rect.fromLTWH(
        (bbox['left'] as num).toDouble(),
        (bbox['top'] as num).toDouble(),
        (bbox['width'] as num).toDouble(),
        (bbox['height'] as num).toDouble(),
      ),
      grid: parsedGrid,
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
