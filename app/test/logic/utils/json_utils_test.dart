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
  });
}
