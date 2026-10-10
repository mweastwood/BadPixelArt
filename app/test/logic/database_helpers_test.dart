import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/models/color_palette.dart';
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

      // Valid JSON with mismatched dimensions (e.g. 2x2 grid with gridSize: 16)
      expect(
        deserializeGrid('[[1, 2], [3, 4]]', gridSize: 16),
        equals(blank16),
      );

      // Ragged-row case
      final ragged = '[[1, 2], [3]]';
      expect(
        deserializeGrid(ragged, gridSize: 2),
        equals([
          [0, 0],
          [0, 0],
        ]),
      );
      expect(deserializeGrid(ragged), isEmpty);

      // Non-integer strings safely parsed to int
      expect(
        deserializeGrid('[[1, "2"], [3, 4]]'),
        equals([
          [1, 2],
          [3, 4],
        ]),
      );
    });

    test('deserializeGrid clamps out-of-range cells and logs bad rows', () {
      expect(deserializeGrid('[[0, 5], [-1, 1]]', paletteLength: 2), [
        [0, 0],
        [0, 1],
      ]);
      expect(deserializeGrid('[[1, 2]]'), [
        [1, 2],
      ]);
      // Non-list rows invalidate the grid instead of being silently dropped.
      expect(deserializeGrid('[[1, 1], 5, [1, 1]]'), isEmpty);
      expect(
        deserializeGrid('[[1, 1], "x"]', gridSize: 2),
        equals(createBlankGrid(2)),
      );
      expect(deserializeGrid('[[1, 1], [1]]'), isEmpty);
    });

    test('clampColorIndex bounds indices to the palette', () {
      expect(clampColorIndex(1, 2), 1);
      expect(clampColorIndex(2, 2), 0);
      expect(clampColorIndex(-1, 2), 0);
      expect(clampColorIndex(3, 0), 0);
    });

    test(
      'deserializePalette handles valid and corrupted inputs gracefully',
      () {
        final valid = serializePalette([Colors.red, Colors.blue]);
        expect(deserializePalette(valid).length, 2);
        expect(deserializePalette(''), isEmpty);
        expect(deserializePalette('invalid json'), isEmpty);

        // Non-list JSON palette (e.g. {})
        expect(deserializePalette('{}'), isEmpty);
        expect(resolvePalette('{}'), equals(PaletteRegistry.primaryPalette));
        expect(
          resolvePalette('{}', fallback: [Colors.green]),
          equals([Colors.green]),
        );

        // Single bad hex entry does not discard remaining valid entries
        final partiallyCorrupt =
            '["#ffff0000", "not-a-hex-color", "#ff0000ff"]';
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
