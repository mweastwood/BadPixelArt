import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/models/sprite_template.dart';

void main() {
  group('SpriteTemplate Unit Tests', () {
    test('characterPreset contains expected 16x16 dimensions and metadata', () {
      final character = SpriteTemplate.characterPreset;
      expect(character.id, equals('sprite_character'));
      expect(character.name, equals('Sprite Character'));
      expect(character.width, equals(16));
      expect(character.height, equals(16));
      expect(character.defaultPrompt, contains('character sprite hero'));
    });

    test('parseToGrid parses numeric palette indices properly', () {
      const template = SpriteTemplate(
        id: 'test_numeric',
        name: 'Test Numeric',
        description: 'Test template with numeric indices',
        width: 4,
        height: 4,
        rawTemplate: '''
.123
0123
.0..
3210
''',
      );

      final grid = template.parseToGrid();
      expect(grid.length, equals(4));
      expect(grid[0], equals([0, 1, 2, 3]));
      expect(grid[1], equals([0, 1, 2, 3]));
      expect(grid[2], equals([0, 0, 0, 0]));
      expect(grid[3], equals([3, 2, 1, 0]));
    });

    test('parseToGrid parses ASCII symbols with default symbol mapping', () {
      const template = SpriteTemplate(
        id: 'test_ascii',
        name: 'Test ASCII',
        description: 'Test template with ASCII symbols',
        width: 4,
        height: 4,
        rawTemplate: '''
.#oX
.##.
.oo.
.XX.
''',
      );

      final grid = template.parseToGrid();
      expect(grid[0], equals([0, 1, 2, 3]));
      expect(grid[1], equals([0, 1, 1, 0]));
      expect(grid[2], equals([0, 2, 2, 0]));
      expect(grid[3], equals([0, 3, 3, 0]));
    });

    test('parseToGrid parses alphanumeric letters A-Z to indices 10-35', () {
      const template = SpriteTemplate(
        id: 'test_alpha',
        name: 'Test Alpha',
        description: 'Test letters A-Z',
        width: 3,
        height: 2,
        rawTemplate: '''
ABC
DEF
''',
      );

      final grid = template.parseToGrid();
      expect(grid[0], equals([10, 11, 12]));
      expect(grid[1], equals([13, 14, 15]));
    });

    test('characterPreset parseToGrid produces non-empty 16x16 grid', () {
      final grid = SpriteTemplate.characterPreset.parseToGrid();
      expect(grid.length, equals(16));
      for (final row in grid) {
        expect(row.length, equals(16));
      }

      // Check specific features
      // Row 0 has 1s in columns 4..9
      expect(grid[0].sublist(4, 10), equals([1, 1, 1, 1, 1, 1]));
      // Row 5 has eye accents (3)
      expect(grid[5][4], equals(3));
      expect(grid[5][10], equals(3));
    });

    test('getById returns presets or null for non-existent', () {
      expect(
        SpriteTemplate.getById('sprite_character'),
        equals(SpriteTemplate.characterPreset),
      );
      expect(
        SpriteTemplate.getById('sword'),
        equals(SpriteTemplate.swordPreset),
      );
      expect(
        SpriteTemplate.getById('potion'),
        equals(SpriteTemplate.potionPreset),
      );
      expect(
        SpriteTemplate.getById('heart'),
        equals(SpriteTemplate.heartPreset),
      );
      expect(SpriteTemplate.getById('invalid_id'), isNull);
    });

    test('parseToGrid preserves leading whitespace and space indentation', () {
      const template = SpriteTemplate(
        id: 'test_whitespace',
        name: 'Test Whitespace',
        description: 'Test whitespace indentation preservation',
        width: 6,
        height: 3,
        rawTemplate: '''
  11  
 1221 
122221
''',
      );

      final grid = template.parseToGrid();
      expect(grid.length, equals(3));
      // Row 0: 2 leading spaces, two 1s, 2 trailing spaces
      expect(grid[0], equals([0, 0, 1, 1, 0, 0]));
      // Row 1: 1 leading space, 1, 2, 2, 1, 1 trailing space
      expect(grid[1], equals([0, 1, 2, 2, 1, 0]));
      // Row 2: 0 leading spaces, 1, 2, 2, 2, 2, 1
      expect(grid[2], equals([1, 2, 2, 2, 2, 1]));
    });

    test('parseToGrid handles irregular line lengths with zero padding', () {
      const template = SpriteTemplate(
        id: 'test_irregular',
        name: 'Test Irregular',
        description: 'Test template with irregular row lengths',
        width: 6,
        height: 3,
        rawTemplate: '''
12
123456
1234
''',
      );

      final grid = template.parseToGrid();
      expect(grid.length, equals(3));
      expect(grid[0], equals([1, 2, 0, 0, 0, 0]));
      expect(grid[1], equals([1, 2, 3, 4, 5, 6]));
      expect(grid[2], equals([1, 2, 3, 4, 0, 0]));
    });

    test('parseToGrid sanitizes Windows carriage returns (CRLF)', () {
      const template = SpriteTemplate(
        id: 'test_crlf',
        name: 'Test CRLF',
        description: 'Test CRLF line endings',
        width: 4,
        height: 2,
        rawTemplate: "1234\r\n5678\r\n",
      );

      final grid = template.parseToGrid();
      expect(grid[0], equals([1, 2, 3, 4]));
      expect(grid[1], equals([5, 6, 7, 8]));
    });

    test('copyWith updates properties properly', () {
      final modified = SpriteTemplate.characterPreset.copyWith(
        name: 'Custom Hero',
        defaultPrompt: 'new prompt',
      );
      expect(modified.name, equals('Custom Hero'));
      expect(modified.defaultPrompt, equals('new prompt'));
      expect(modified.id, equals('sprite_character'));
    });
  });
}
