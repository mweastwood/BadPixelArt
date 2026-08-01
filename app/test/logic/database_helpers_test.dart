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
    });

    test(
      'deserializePalette handles valid and corrupted inputs gracefully',
      () {
        final valid = serializePalette([Colors.red, Colors.blue]);
        expect(deserializePalette(valid).length, 2);
        expect(deserializePalette(''), isEmpty);
        expect(deserializePalette('invalid json'), isEmpty);
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
