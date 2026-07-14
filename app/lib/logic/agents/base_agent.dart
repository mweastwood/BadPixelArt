// ignore_for_file: deprecated_member_use
import 'dart:typed_data';
import 'dart:ui';

abstract class PixelArtAgent {
  String get name;
  List<String> get availableTools;
  String getSystemInstruction(AgentContext context);
  String getFormattedUserPrompt(AgentContext context, List<dynamic> history);
}

class AgentContext {
  final int gridSize;
  final List<Color> activePalette;
  final String userPrompt;
  final PixelArtComponent? targetComponent;
  final List<List<int>> currentGrid;
  final Uint8List? referenceImage;

  AgentContext({
    required this.gridSize,
    required this.activePalette,
    required this.userPrompt,
    this.targetComponent,
    required this.currentGrid,
    this.referenceImage,
  });
}

class PixelArtComponent {
  final String name;
  final String description;
  final Rect relativeBoundingBox; // Normalized bounding box (0.0 to 1.0)
  final Color proposedBaseColor;

  PixelArtComponent({
    required this.name,
    required this.description,
    required this.relativeBoundingBox,
    required this.proposedBaseColor,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'boundingBox': {
        'x': relativeBoundingBox.left,
        'y': relativeBoundingBox.top,
        'w': relativeBoundingBox.width,
        'h': relativeBoundingBox.height,
      },
      'color':
          '#${(proposedBaseColor.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
    };
  }

  factory PixelArtComponent.fromJson(Map<String, dynamic> json) {
    final bbox = json['boundingBox'] as Map<String, dynamic>? ?? {};
    final x = (bbox['x'] as num? ?? 0.0).toDouble();
    final y = (bbox['y'] as num? ?? 0.0).toDouble();
    final w = (bbox['w'] as num? ?? 1.0).toDouble();
    final h = (bbox['h'] as num? ?? 1.0).toDouble();

    // Parse color
    final colorStr = json['color'] as String? ?? '#000000';
    final cleanedColorStr = colorStr.replaceFirst('#', '');
    final colorValue = int.tryParse(cleanedColorStr, radix: 16) ?? 0;
    final parsedColor = Color(0xFF000000 | colorValue);

    return PixelArtComponent(
      name: json['name'] as String? ?? 'Unnamed',
      description: json['description'] as String? ?? '',
      relativeBoundingBox: Rect.fromLTWH(x, y, w, h),
      proposedBaseColor: parsedColor,
    );
  }
}
