import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/utils/json_utils.dart';

void main() {
  group('json_utils - cleanJsonString tests', () {
    test('passes through clean JSON object', () {
      final input = '{"remove": [1, 2], "add": [3]}';
      expect(cleanJsonString(input), equals('{"remove": [1, 2], "add": [3]}'));
    });

    test('strips standard markdown code block', () {
      final input = '''
```json
{
  "remove": [1, 2],
  "add": [3]
}
```''';
      expect(
        cleanJsonString(input),
        equals('{\n  "remove": [1, 2],\n  "add": [3]\n}'),
      );
    });

    test('extracts JSON object out of conversational wrapper', () {
      final input = '''
Sure! Here is the JSON output to refine the steel blade:
```json
{
  "remove": [{"x": 8, "y": 9}],
  "add": [{"x": 8, "y": 7}]
}
```
Hope this helps!
''';
      expect(
        cleanJsonString(input),
        equals(
          '{\n  "remove": [{"x": 8, "y": 9}],\n  "add": [{"x": 8, "y": 7}]\n}',
        ),
      );
    });

    test('extracts JSON array out of conversational wrapper', () {
      final input = '''
Based on your prompt, here is the list of components:
[
  {"name": "blade"},
  {"name": "hilt"}
]
Let me know if you need anything else!
''';
      expect(
        cleanJsonString(input),
        equals('[\n  {"name": "blade"},\n  {"name": "hilt"}\n]'),
      );
    });

    test('extracts and repairs truncated JSON object', () {
      final input = '{"remove": [{"x":3,"y":1},{"x":4,"y":1},{"x":12,';
      expect(
        cleanJsonString(input),
        equals('{"remove": [{"x":3,"y":1},{"x":4,"y":1}]}'),
      );
    });

    test('extracts and repairs truncated JSON array', () {
      final input = '[{"name": "blade"},{"name": "hilt"},{"name": "guard';
      expect(
        cleanJsonString(input),
        equals('[{"name": "blade"},{"name": "hilt"}]'),
      );
    });
  });

  group('json_utils - parseCoordinateValue tests', () {
    test('parses int and num values', () {
      expect(parseCoordinateValue(0), equals(0));
      expect(parseCoordinateValue(12), equals(12));
      expect(parseCoordinateValue(-5), equals(-5));
      expect(parseCoordinateValue(8.0), equals(8));
      expect(parseCoordinateValue(4.7), equals(4));
    });

    test('parses integer strings correctly', () {
      expect(parseCoordinateValue('0'), equals(0));
      expect(parseCoordinateValue('12'), equals(12));
      expect(parseCoordinateValue('-5'), equals(-5));
    });

    test(
      'returns null for null, non-numeric strings, or incompatible types',
      () {
        expect(parseCoordinateValue(null), isNull);
        expect(parseCoordinateValue('abc'), isNull);
        expect(parseCoordinateValue(''), isNull);
        expect(parseCoordinateValue('12.5'), isNull);
        expect(parseCoordinateValue(true), isNull);
        expect(parseCoordinateValue([1, 2]), isNull);
        expect(parseCoordinateValue({'x': 1}), isNull);
      },
    );
  });
}
