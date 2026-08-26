import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bad_pixel_art/logic/repositories/reference_library_repository.dart';
import 'package:bad_pixel_art/logic/services/share_receiver_service.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';

import '../../test_helper.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareReceiverService Unit Tests', () {
    late AppDatabase db;
    late ReferenceLibraryRepository repository;
    late CanvasNotifier canvasNotifier;
    late ShareReceiverService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      repository = ReferenceLibraryRepository(dbGetter: () => db);
      final aiService = TestMockAiService();
      canvasNotifier = CanvasNotifier(aiService);
      service = ShareReceiverService(repository, () => canvasNotifier);
    });

    tearDown(() async {
      service.dispose();
      await db.close();
    });

    test('SharedMediaItem parses correctly from map', () {
      final sampleBytes = Uint8List.fromList([1, 2, 3]);
      final map = {
        'bytes': sampleBytes,
        'text': 'A fantasy crystal dagger',
        'subject': 'Gemini Generation',
        'mimeType': 'image/png',
      };
      final item = SharedMediaItem.fromMap(map);
      expect(item.bytes, equals(sampleBytes));
      expect(item.text, equals('A fantasy crystal dagger'));
      expect(item.subject, equals('Gemini Generation'));
      expect(item.mimeType, equals('image/png'));
    });

    test(
      'handleSharedItem saves reference image, sets active canvas image, and sets prompt',
      () async {
        final sampleBmp = generateBmpFromRgba(
          Uint8List.fromList([255, 0, 0, 255]),
          1,
          1,
        );
        final item = SharedMediaItem(
          bytes: sampleBmp,
          text: 'A red ruby pixel shield',
          subject: 'Ruby Shield',
          mimeType: 'image/png',
        );

        final saved = await service.handleSharedItem(item);
        expect(saved, isNotNull);
        expect(saved?.title, equals('Ruby Shield'));
        expect(saved?.prompt, equals('A red ruby pixel shield'));
        expect(saved?.source, equals('gemini'));

        // Check CanvasNotifier state was updated
        expect(canvasNotifier.state.referenceImage, isNotNull);
        expect(canvasNotifier.state.originalReferenceImage, equals(sampleBmp));
        expect(
          canvasNotifier.state.userPrompt,
          equals('A red ruby pixel shield'),
        );

        // Check DB contains the image
        final inDb = await repository.getAllReferenceImages();
        expect(inDb.length, equals(1));
        expect(inDb.first.title, equals('Ruby Shield'));
      },
    );

    test('handleSharedItem returns null on empty bytes', () async {
      final item = SharedMediaItem(bytes: Uint8List(0), text: 'Nothing');
      final result = await service.handleSharedItem(item);
      expect(result, isNull);
      expect(await repository.getAllReferenceImages(), isEmpty);
    });
  });
}
