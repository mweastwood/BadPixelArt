import 'package:flutter/foundation.dart';

/// Represents a pixel art template with ASCII / numeric grid definitions.
@immutable
class SpriteTemplate {
  final String id;
  final String name;
  final String description;
  final int width;
  final int height;
  final String rawTemplate;
  final String defaultPrompt;
  final Map<String, int>? symbolMapping;

  const SpriteTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.rawTemplate,
    this.defaultPrompt = '',
    this.symbolMapping,
  });

  /// Parses the raw template string into a 2D integer grid of size [height] x [width].
  ///
  /// '.' and '0' and whitespace denote empty / transparent pixels (value 0).
  /// Characters '1'..'9' map directly to palette color indices 1..9.
  /// Letters 'A'..'Z' map to color indices 10..35.
  /// Symbols like '#', 'o', 'X' map via [customMapping] or [symbolMapping].
  List<List<int>> parseToGrid([Map<String, int>? customMapping]) {
    final mapping =
        customMapping ??
        symbolMapping ??
        const {'#': 1, 'o': 2, 'O': 2, 'x': 3, 'X': 3};

    final lines = rawTemplate
        .replaceAll('\r', '')
        .split('\n')
        .where((l) => l.isNotEmpty)
        .toList();

    return List.generate(height, (y) {
      return List.generate(width, (x) {
        if (y >= lines.length || x >= lines[y].length) return 0;
        final char = lines[y][x];
        if (char == '.' || char == ' ' || char == '0') return 0;

        // Custom symbol mapping (e.g. # -> 1, o -> 2, X -> 3)
        if (mapping.containsKey(char)) {
          return mapping[char]!;
        }

        // Single digit 1..9
        final digit = int.tryParse(char);
        if (digit != null) {
          return digit;
        }

        // Alphanumeric A..Z -> 10..35
        final code = char.toUpperCase().codeUnitAt(0);
        if (code >= 65 && code <= 90) {
          return code - 65 + 10;
        }

        return 1;
      });
    });
  }

  /// Preset 1: 16x16 Sprite Character Base
  static const characterPreset = SpriteTemplate(
    id: 'sprite_character',
    name: 'Sprite Character',
    description:
        '16x16 humanoid character sprite with outline, body fill, and eyes',
    width: 16,
    height: 16,
    defaultPrompt: 'pixel art 16x16 character sprite hero, detailed shading',
    symbolMapping: {'#': 1, 'o': 2, 'X': 3, '.': 0},
    rawTemplate: '''
....111111......
...122222221....
..12222222221...
.1222222222221..
.1222222222221..
.1223222223221..
.1223222223221..
.1222222222221..
..12222222221...
...112222211....
...122222221....
..12122222121...
..12122222121...
...112222211....
....1221221.....
....111.111.....
''',
  );

  /// List of all built-in template presets.
  static const List<SpriteTemplate> presets = [characterPreset];

  /// Find a preset by its unique ID.
  static SpriteTemplate? getById(String id) {
    try {
      return presets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  SpriteTemplate copyWith({
    String? id,
    String? name,
    String? description,
    int? width,
    int? height,
    String? rawTemplate,
    String? defaultPrompt,
    Map<String, int>? symbolMapping,
  }) {
    return SpriteTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      width: width ?? this.width,
      height: height ?? this.height,
      rawTemplate: rawTemplate ?? this.rawTemplate,
      defaultPrompt: defaultPrompt ?? this.defaultPrompt,
      symbolMapping: symbolMapping ?? this.symbolMapping,
    );
  }
}
