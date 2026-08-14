import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bad_pixel_art/logic/repositories/canvas_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CanvasRepository Unit Tests', () {
    late CanvasRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = CanvasRepository();
    });

    test('CanvasRepository can be instantiated', () {
      expect(repository, isNotNull);
    });
  });
}
