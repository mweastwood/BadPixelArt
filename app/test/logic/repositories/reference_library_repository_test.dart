import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bad_pixel_art/logic/repositories/reference_library_repository.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';
import 'package:bad_pixel_art/logic/utils/bmp_utils.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReferenceLibraryRepository Unit Tests', () {
    late AppDatabase db;
    late ReferenceLibraryRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      repository = ReferenceLibraryRepository(dbGetter: () => db);
    });

    tearDown(() async {
      await db.close();
    });

    test('ReferenceLibraryRepository provider resolves correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(referenceLibraryRepositoryProvider);
      expect(repo, isA<ReferenceLibraryRepository>());
    });

    test(
      'addReferenceImage creates and persists image in DB with custom title and prompt',
      () async {
        final sampleBmp = generateBmpFromRgba(
          Uint8List.fromList([255, 0, 0, 255]),
          1,
          1,
        );
        final item = await repository.addReferenceImage(
          imageBytes: sampleBmp,
          title: 'My Custom Sword',
          prompt: 'Pixel sword with glowing aura',
          source: 'gemini',
        );

        expect(item.id, isNotNull);
        expect(item.title, equals('My Custom Sword'));
        expect(item.prompt, equals('Pixel sword with glowing aura'));
        expect(item.source, equals('gemini'));
        expect(item.imageData, equals(sampleBmp));
        expect(item.bmpData, isNotNull);

        final fetched = await repository.getReferenceImageById(item.id);
        expect(fetched, isNotNull);
        expect(fetched?.title, equals('My Custom Sword'));
      },
    );

    test('addReferenceImage generates default title based on source', () async {
      final sampleBmp = generateBmpFromRgba(
        Uint8List.fromList([0, 255, 0, 255]),
        1,
        1,
      );

      final geminiItem = await repository.addReferenceImage(
        imageBytes: sampleBmp,
        source: 'gemini',
      );
      expect(geminiItem.title, startsWith('Gemini Reference'));

      final uploadItem = await repository.addReferenceImage(
        imageBytes: sampleBmp,
        source: 'upload',
      );
      expect(uploadItem.title, startsWith('Reference'));
    });

    test(
      'getAllReferenceImages and watchAllReferenceImages return images in order',
      () async {
        final sampleBmp = generateBmpFromRgba(
          Uint8List.fromList([0, 0, 255, 255]),
          1,
          1,
        );

        expect(await repository.getAllReferenceImages(), isEmpty);

        final item1 = await repository.addReferenceImage(
          imageBytes: sampleBmp,
          title: 'First Image',
        );
        final item2 = await repository.addReferenceImage(
          imageBytes: sampleBmp,
          title: 'Second Image',
        );

        final allImages = await repository.getAllReferenceImages();
        expect(allImages.length, equals(2));
        expect(allImages.first.id, equals(item2.id));
        expect(allImages.last.id, equals(item1.id));

        final streamFirst = await repository.watchAllReferenceImages().first;
        expect(streamFirst.length, equals(2));
      },
    );

    test('updateReferenceImageDetails updates title and prompt', () async {
      final sampleBmp = generateBmpFromRgba(
        Uint8List.fromList([255, 255, 0, 255]),
        1,
        1,
      );
      final item = await repository.addReferenceImage(
        imageBytes: sampleBmp,
        title: 'Old Title',
        prompt: 'Old Prompt',
      );

      await repository.updateReferenceImageDetails(
        id: item.id,
        title: 'New Title',
        prompt: 'New Prompt',
      );

      final updated = await repository.getReferenceImageById(item.id);
      expect(updated?.title, equals('New Title'));
      expect(updated?.prompt, equals('New Prompt'));
    });

    test('deleteReferenceImage removes item from DB', () async {
      final sampleBmp = generateBmpFromRgba(
        Uint8List.fromList([255, 0, 255, 255]),
        1,
        1,
      );
      final item = await repository.addReferenceImage(
        imageBytes: sampleBmp,
        title: 'To Delete',
      );

      expect(await repository.getReferenceImageById(item.id), isNotNull);

      await repository.deleteReferenceImage(item.id);
      expect(await repository.getReferenceImageById(item.id), isNull);
      expect(await repository.getAllReferenceImages(), isEmpty);
    });
  });
}
