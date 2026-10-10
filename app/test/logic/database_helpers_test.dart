import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/utils/database_helpers.dart';

void main() {
  group('Database Helpers Edge Case & Recovery Unit Tests', () {
    test('deserializeGrid handles valid and corrupted inputs gracefully', () {
      final valid = serializeGrid([
        [1, 0],
        [0, 2],
      ]);
      expect(deserializeGrid(valid), [
        [1, 0],
        [0, 2],
      ]);
      expect(deserializeGrid(''), isEmpty);
      expect(deserializeGrid('invalid json'), isEmpty);

      // With gridSize specified, corrupted or mismatched input rebuilds blank gridSize x gridSize grid
      final blank16 = List.generate(16, (_) => List.filled(16, 0));
      expect(deserializeGrid('invalid json', gridSize: 16), equals(blank16));
      expect(deserializeGrid('', gridSize: 16), equals(blank16));
      expect(deserializeGrid('[[1, "a"]]', gridSize: 32).length, equals(32));
      expect(deserializeGrid('[[1, "a"]]', gridSize: 32)[0].length, equals(32));

      // Non-integer strings safely parsed to int
      expect(deserializeGrid('[[1, "2"], [3, 4]]'), equals([
        [1, 2],
        [3, 4],
      ]));
    });

    test(
      'deserializePalette handles valid and corrupted inputs gracefully',
      () {
        final valid = serializePalette([Colors.red, Colors.blue]);
        expect(deserializePalette(valid).length, 2);
        expect(deserializePalette(''), isEmpty);
        expect(deserializePalette('invalid json'), isEmpty);

        // Single bad hex entry does not discard remaining valid entries
        final partiallyCorrupt = '["#ffff0000", "not-a-hex-color", "#ff0000ff"]';
        final parsed = deserializePalette(partiallyCorrupt);
        expect(parsed.length, equals(2));
        expect(parsed[0].toARGB32(), equals(Colors.red.toARGB32()));
        expect(parsed[1].toARGB32(), equals(Colors.blue.toARGB32()));
      },
    );

    test(
      'deserializeComponents handles valid and corrupted inputs gracefully',
      () {
        expect(deserializeComponents(''), isEmpty);
        expect(deserializeComponents('not a json array'), isEmpty);
      },
    );

    test(
      'deserializeHistory handles valid and corrupted inputs gracefully',
      () {
        expect(deserializeHistory(''), isEmpty);
        expect(deserializeHistory('{corrupted: json}'), isEmpty);
      },
    );
  });
}
