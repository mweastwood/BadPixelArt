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

  group('json_utils - repairTruncatedJson tests', () {
    test(
      'handles escaped quotes inside string values without inverting state',
      () {
        final input =
            r'{"desc": "a \"quote\" here", "items": [{"id": 1, "meta": {}}';
        expect(
          repairTruncatedJson(input),
          equals(
            r'{"desc": "a \"quote\" here", "items": [{"id": 1, "meta": {}}]}',
          ),
        );

        final simpleInput =
            r'{"desc": "a \"quote\" here", "items": [{"id": 1}]';
        expect(
          repairTruncatedJson(simpleInput),
          equals(r'{"desc": "a \"quote\" here", "items": [{"id": 1}]}'),
        );
      },
    );

    test(
      'returns input unchanged when no closing tokens are found (cutIdx == -1)',
      () {
        expect(
          repairTruncatedJson('invalid text without braces'),
          equals('invalid text without braces'),
        );
        expect(
          repairTruncatedJson('{"incomplete": 123'),
          equals('{"incomplete": 123'),
        );
        expect(
          repairTruncatedJson('{"incomplete\': 123'),
          equals('{"incomplete\': 123'),
        );
        expect(
          repairTruncatedJson('{"data": [{"item": {"x": 10, "y": 20'),
          equals('{"data": [{"item": {"x": 10, "y": 20'),
        );
      },
    );

    test('handles empty input', () {
      expect(repairTruncatedJson(''), equals(''));
    });

    test('reconstructs nested mixed tokens and stack reversal correctly', () {
      final input1 = '[{"items": [{"val": 1}, {"val": 2';
      expect(
        repairTruncatedJson(input1),
        equals('[{"items": [{"val": 1}]}]'),
      );

      final input2 = '{"data": [{"item": {"x": 10, "y": 20}}';
      expect(
        repairTruncatedJson(input2),
        equals('{"data": [{"item": {"x": 10, "y": 20}}]}'),
      );

      final input3 = '{"a": {"b": [1, 2]';
      expect(
        repairTruncatedJson(input3),
        equals('{"a": {"b": [1, 2]}}'),
      );

      final input4 = '{"records": [{"tags": ["dart", "flutter"]';
      expect(
        repairTruncatedJson(input4),
        equals('{"records": [{"tags": ["dart", "flutter"]}]}'),
      );
    });

    test('returns fully balanced JSON inputs intact', () {
      expect(
        repairTruncatedJson('{"a": 1, "b": [2, 3]}'),
        equals('{"a": 1, "b": [2, 3]}'),
      );
      expect(
        repairTruncatedJson('[{"a": 1}, {"b": 2}]'),
        equals('[{"a": 1}, {"b": 2}]'),
      );
      expect(
        repairTruncatedJson('  {"a": 1}  '),
        equals('{"a": 1}'),
      );
    });
  });

  group('json_utils - parseNumValue tests', () {
    test('parses direct numeric types (num, int, double)', () {
      expect(parseNumValue(10), equals(10));
      expect(parseNumValue(3.14), equals(3.14));
      expect(parseNumValue(-5.5), equals(-5.5));
      expect(parseNumValue(0), equals(0));
      expect(parseNumValue(0.0), equals(0.0));
    });

    test('parses numeric strings (integers, floats, scientific notation)', () {
      expect(parseNumValue('10'), equals(10));
      expect(parseNumValue('0'), equals(0));
      expect(parseNumValue('-5'), equals(-5));
      expect(parseNumValue('3.14'), equals(3.14));
      expect(parseNumValue('-5.5'), equals(-5.5));
      expect(parseNumValue('0.0'), equals(0.0));
      expect(parseNumValue('1e3'), equals(1000.0));
      expect(parseNumValue('2.5e-2'), equals(0.025));
    });

    test('returns null for null, non-numeric strings, or incompatible types', () {
      expect(parseNumValue(null), isNull);
      expect(parseNumValue(''), isNull);
      expect(parseNumValue('   '), isNull);
      expect(parseNumValue('abc'), isNull);
      expect(parseNumValue('12abc'), isNull);
      expect(parseNumValue('--1'), isNull);
      expect(parseNumValue(true), isNull);
      expect(parseNumValue(false), isNull);
      expect(parseNumValue([1, 2]), isNull);
      expect(parseNumValue({'x': 1}), isNull);
    });
  });
}
