import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/utils/noise_utils.dart';

void main() {
  group('noise_utils - hashNoise tests', () {
    test('returns deterministic float in [0.0, 1.0]', () {
      final val1 = hashNoise(5, 10, 42);
      final val2 = hashNoise(5, 10, 42);

      expect(val1, equals(val2));
      expect(val1, greaterThanOrEqualTo(0.0));
      expect(val1, lessThanOrEqualTo(1.0));
    });

    test('produces varying values across coordinates and seeds', () {
      final v1 = hashNoise(0, 0, 1);
      final v2 = hashNoise(1, 0, 1);
      final v3 = hashNoise(0, 1, 1);
      final v4 = hashNoise(0, 0, 2);

      // Verify that changing inputs changes output
      expect(v1, isNot(equals(v2)));
      expect(v1, isNot(equals(v3)));
      expect(v1, isNot(equals(v4)));
    });

    test('handles negative coordinates and negative seed safely', () {
      final valNeg = hashNoise(-5, -10, -99);
      expect(valNeg, greaterThanOrEqualTo(0.0));
      expect(valNeg, lessThanOrEqualTo(1.0));
    });
  });
}
