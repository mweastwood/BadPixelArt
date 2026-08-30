import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bad_pixel_art/screens/reference_library_screen.dart';
import 'package:bad_pixel_art/logic/repositories/reference_library_repository.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';
import 'package:bad_pixel_art/logic/utils/bmp_utils.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';

import '../test_helper.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReferenceLibraryScreen Widget Tests', () {
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

    testWidgets('renders empty state when no reference images exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            referenceLibraryRepositoryProvider.overrideWithValue(repository),
          ],
          child: const ReferenceLibraryScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Reference Image Library'), findsOneWidget);
      expect(
        find.text('No reference images in your library yet'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('empty_state_import_button')),
        findsOneWidget,
      );
    });

    testWidgets('renders cards with source badges when images exist', (
      tester,
    ) async {
      final sampleBmp = generateBmpFromRgba(
        Uint8List.fromList([255, 0, 0, 255]),
        1,
        1,
      );
      await repository.addReferenceImage(
        imageBytes: sampleBmp,
        bmpBytes: sampleBmp,
        title: 'Gemini Dragon',
        prompt: 'Pixel dragon breathing fire',
        source: 'gemini',
      );
      await repository.addReferenceImage(
        imageBytes: sampleBmp,
        bmpBytes: sampleBmp,
        title: 'Uploaded Castle',
        source: 'upload',
      );

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            referenceLibraryRepositoryProvider.overrideWithValue(repository),
          ],
          child: const ReferenceLibraryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gemini Dragon'), findsOneWidget);
      expect(find.text('Uploaded Castle'), findsOneWidget);
      expect(find.text('Gemini'), findsNWidgets(2)); // Chip and Badge
      expect(find.text('Upload'), findsOneWidget);
    });

    testWidgets('filter chips filter library by source', (tester) async {
      final sampleBmp = generateBmpFromRgba(
        Uint8List.fromList([0, 255, 0, 255]),
        1,
        1,
      );
      await repository.addReferenceImage(
        imageBytes: sampleBmp,
        bmpBytes: sampleBmp,
        title: 'Gemini Sword',
        source: 'gemini',
      );
      await repository.addReferenceImage(
        imageBytes: sampleBmp,
        bmpBytes: sampleBmp,
        title: 'Uploaded Shield',
        source: 'upload',
      );

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            referenceLibraryRepositoryProvider.overrideWithValue(repository),
          ],
          child: const ReferenceLibraryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gemini Sword'), findsOneWidget);
      expect(find.text('Uploaded Shield'), findsOneWidget);

      // Tap Gemini filter
      await tester.tap(find.byKey(const ValueKey('filter_chip_gemini')));
      await tester.pumpAndSettle();

      expect(find.text('Gemini Sword'), findsOneWidget);
      expect(find.text('Uploaded Shield'), findsNothing);

      // Tap Uploaded filter
      await tester.tap(find.byKey(const ValueKey('filter_chip_upload')));
      await tester.pumpAndSettle();

      expect(find.text('Gemini Sword'), findsNothing);
      expect(find.text('Uploaded Shield'), findsOneWidget);
    });

    testWidgets('search query filters cards by title and prompt', (
      tester,
    ) async {
      final sampleBmp = generateBmpFromRgba(
        Uint8List.fromList([0, 0, 255, 255]),
        1,
        1,
      );
      await repository.addReferenceImage(
        imageBytes: sampleBmp,
        bmpBytes: sampleBmp,
        title: 'Hero Knight',
        prompt: 'Knight with silver armor',
      );
      await repository.addReferenceImage(
        imageBytes: sampleBmp,
        bmpBytes: sampleBmp,
        title: 'Magic Staff',
        prompt: 'Wooden staff with orb',
      );

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            referenceLibraryRepositoryProvider.overrideWithValue(repository),
          ],
          child: const ReferenceLibraryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hero Knight'), findsOneWidget);
      expect(find.text('Magic Staff'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('reference_library_search_field')),
        'silver',
      );
      await tester.pumpAndSettle();

      expect(find.text('Hero Knight'), findsOneWidget);
      expect(find.text('Magic Staff'), findsNothing);
    });

    testWidgets('picker mode selects image and triggers callback', (
      tester,
    ) async {
      final sampleBmp = generateBmpFromRgba(
        Uint8List.fromList([255, 255, 0, 255]),
        1,
        1,
      );
      final item = await repository.addReferenceImage(
        imageBytes: sampleBmp,
        bmpBytes: sampleBmp,
        title: 'Selected Item',
        prompt: 'My prompt',
        source: 'gemini',
      );

      ReferenceImage? selected;

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            referenceLibraryRepositoryProvider.overrideWithValue(repository),
          ],
          child: ReferenceLibraryScreen(
            isPickerMode: true,
            onImageSelected: (img) {
              selected = img;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Reference Image'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('reference_card_${item.id}')));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected?.title, equals('Selected Item'));
    });

    testWidgets(
      'renders thumbnail using bmpData when available with cache constraints',
      (tester) async {
        final originalBytes = generateBmpFromRgba(
          Uint8List.fromList([255, 0, 0, 255]),
          1,
          1,
        );
        final downscaledBmpBytes = generateBmpFromRgba(
          Uint8List.fromList([0, 255, 0, 255]),
          1,
          1,
        );
        final item = await repository.addReferenceImage(
          imageBytes: originalBytes,
          bmpBytes: downscaledBmpBytes,
          title: 'Thumbnail Test',
          source: 'upload',
        );

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              referenceLibraryRepositoryProvider.overrideWithValue(repository),
            ],
            child: const ReferenceLibraryScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final cardFinder = find.byKey(ValueKey('reference_card_${item.id}'));
        expect(cardFinder, findsOneWidget);

        final imageFinder = find.descendant(
          of: cardFinder,
          matching: find.byType(Image),
        );
        expect(imageFinder, findsOneWidget);

        final imageWidget = tester.widget<Image>(imageFinder);
        final imageProvider = imageWidget.image;
        expect(imageProvider, isA<ResizeImage>());

        final resizeImage = imageProvider as ResizeImage;
        expect(resizeImage.width, equals(300));
        expect(resizeImage.height, equals(300));
        expect(resizeImage.imageProvider, isA<MemoryImage>());

        final memoryImage = resizeImage.imageProvider as MemoryImage;
        expect(memoryImage.bytes, equals(downscaledBmpBytes));
      },
    );

    testWidgets(
      'falls back to imageData when bmpData is null with cache constraints',
      (tester) async {
        final originalBytes = generateBmpFromRgba(
          Uint8List.fromList([0, 0, 255, 255]),
          1,
          1,
        );
        final now = DateTime.now();
        final id = await db.createReferenceImage(
          ReferenceImagesCompanion(
            title: const drift.Value('Null Bmp Test'),
            imageData: drift.Value(originalBytes),
            bmpData: const drift.Value(null),
            source: const drift.Value('upload'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        final item = await db.getReferenceImageById(id);
        expect(item, isNotNull);

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              referenceLibraryRepositoryProvider.overrideWithValue(repository),
            ],
            child: const ReferenceLibraryScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final cardFinder = find.byKey(ValueKey('reference_card_${item!.id}'));
        expect(cardFinder, findsOneWidget);

        final imageFinder = find.descendant(
          of: cardFinder,
          matching: find.byType(Image),
        );
        expect(imageFinder, findsOneWidget);

        final imageWidget = tester.widget<Image>(imageFinder);
        final imageProvider = imageWidget.image;
        expect(imageProvider, isA<ResizeImage>());

        final resizeImage = imageProvider as ResizeImage;
        expect(resizeImage.width, equals(300));
        expect(resizeImage.height, equals(300));
        expect(resizeImage.imageProvider, isA<MemoryImage>());

        final memoryImage = resizeImage.imageProvider as MemoryImage;
        expect(memoryImage.bytes, equals(originalBytes));
      },
    );
  });
}
