import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/models/sculpting_candidates.dart';

void main() {
  group('SculptingCandidates Model Tests', () {
    test('default constructor creates empty candidate lists', () {
      const candidates = SculptingCandidates();
      expect(candidates.remove, isEmpty);
      expect(candidates.add, isEmpty);
      expect(candidates, equals(SculptingCandidates.empty));
    });

    test('identical instances evaluate to equal and same hashCode', () {
      const candidates = SculptingCandidates(
        remove: [Point(1, 2), Point(3, 4)],
        add: [Point(5, 6)],
      );

      expect(candidates == candidates, isTrue);
      expect(candidates.hashCode, equals(candidates.hashCode));
    });

    test(
      'instances with identical coordinates have value equality and equal hashCodes',
      () {
        final candidates1 = SculptingCandidates(
          remove: [const Point(1, 2), const Point(3, 4)],
          add: [const Point(5, 6)],
        );
        final candidates2 = SculptingCandidates(
          remove: [const Point(1, 2), const Point(3, 4)],
          add: [const Point(5, 6)],
        );

        expect(candidates1, equals(candidates2));
        expect(candidates1 == candidates2, isTrue);
        expect(candidates1.hashCode, equals(candidates2.hashCode));
      },
    );

    test('instances with differing coordinates are not equal', () {
      const base = SculptingCandidates(
        remove: [Point(1, 2)],
        add: [Point(3, 4)],
      );
      const diffRemove = SculptingCandidates(
        remove: [Point(1, 3)],
        add: [Point(3, 4)],
      );
      const diffAdd = SculptingCandidates(
        remove: [Point(1, 2)],
        add: [Point(3, 5)],
      );
      const diffLength = SculptingCandidates(
        remove: [Point(1, 2), Point(2, 2)],
        add: [Point(3, 4)],
      );

      expect(base == diffRemove, isFalse);
      expect(base == diffAdd, isFalse);
      expect(base == diffLength, isFalse);
      expect(base == Object(), isFalse);
    });
  });
}
