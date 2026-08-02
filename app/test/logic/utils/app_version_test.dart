import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/utils/app_version.dart';

void main() {
  group('AppVersion Unit Tests', () {
    test('AppVersion defaults to expected fallbacks', () {
      expect(AppVersion.current, equals('v0.0.0-dev'));
      expect(AppVersion.gitHash, equals('local'));
      expect(AppVersion.display, equals('v0.0.0-dev'));
    });
  });
}
