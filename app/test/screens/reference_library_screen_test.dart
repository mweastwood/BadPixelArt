import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bad_pixel_art/screens/reference_library_screen.dart';
import 'package:bad_pixel_art/logic/repositories/reference_library_repository.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';

import '../test_helper.dart';

class FakeFilePickerPlatform extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  final FilePickerResult? pickFilesResult;
  final bool shouldThrow;

  FakeFilePickerPlatform({this.pickFilesResult, this.shouldThrow = false});

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    if (shouldThrow) {
      throw Exception('FilePicker picking failed');
    }
    return pickFilesResult;
  }
}

class TrackingCanvasNotifier extends CanvasNotifier {
  TrackingCanvasNotifier({
    String initialPrompt = '',
    super.repository,
    super.wizardNotifier,
  }) : super(TestMockAiService()) {
    if (initialPrompt.isNotEmpty) {
      state = state.copyWith(userPrompt: initialPrompt);
    }
  }

  Uint8List? lastSetReferenceBmp;
  Uint8List? lastSetReferenceOriginal;
  Uint8List? lastSetUploadedRawBytes;
  String? lastUpdatedPrompt;
  int setReferenceImageCallCount = 0;
  int setUploadedReferenceImageCallCount = 0;
  int updatePromptCallCount = 0;

  @override
  void setReferenceImage(Uint8List? bytes, {Uint8List? originalBytes}) {
    setReferenceImageCallCount++;
    lastSetReferenceBmp = bytes;
    lastSetReferenceOriginal = originalBytes;
    super.setReferenceImage(bytes, originalBytes: originalBytes);
  }

  @override
  Future<void> setUploadedReferenceImage(Uint8List rawBytes) async {
    setUploadedReferenceImageCallCount++;
    lastSetUploadedRawBytes = rawBytes;
    await super.setUploadedReferenceImage(rawBytes);
  }

  @override
  void updatePrompt(String prompt) {
    updatePromptCallCount++;
    lastUpdatedPrompt = prompt;
    super.updatePrompt(prompt);
  }
}

class TestReferenceLibraryRepository extends ReferenceLibraryRepository {
  TestReferenceLibraryRepository({required super.dbGetter});

  Future<void> Function(int id, String title, String? prompt)? onUpdateDetails;

  @override
  Future<void> updateReferenceImageDetails({
    required int id,
    required String title,
    String? prompt,
  }) async {
    if (onUpdateDetails != null) {
      await onUpdateDetails!(id, title, prompt);
      return;
    }
    await super.updateReferenceImageDetails(
      id: id,
      title: title,
      prompt: prompt,
    );
  }

  @override
  Future<ReferenceImage> addReferenceImage({
    required Uint8List imageBytes,
    Uint8List? bmpBytes,
    String? title,
    String? prompt,
    String source = 'upload',
  }) {
    return super.addReferenceImage(
      imageBytes: imageBytes,
      bmpBytes: bmpBytes ?? imageBytes,
      title: title,
      prompt: prompt,
      source: source,
    );
  }
}

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReferenceLibraryScreen Widget Tests', () {
    late AppDatabase db;
    late ReferenceLibraryRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      repository = TestReferenceLibraryRepository(dbGetter: () => db);
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

    group('Details Dialog (_showDetailsDialog)', () {
      late Uint8List sampleBmp;

      setUp(() {
        sampleBmp = generateBmpFromRgba(
          Uint8List.fromList([255, 0, 0, 255]),
          1,
          1,
        );
      });

      testWidgets(
        'tapping reference card opens dialog with title, preview, prompt, and metadata',
        (tester) async {
          final now = DateTime(2026, 9, 14, 12, 30);
          final id = await db.createReferenceImage(
            ReferenceImagesCompanion(
              title: const drift.Value('Detailed Dragon'),
              imageData: drift.Value(sampleBmp),
              bmpData: drift.Value(sampleBmp),
              prompt: const drift.Value('Majestic red dragon'),
              source: const drift.Value('gemini'),
              createdAt: drift.Value(now),
              updatedAt: drift.Value(now),
            ),
          );
          final item = (await db.getReferenceImageById(id))!;

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          // Tap card to open details dialog
          await tester.tap(find.byKey(ValueKey('reference_card_${item.id}')));
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            find.text('Detailed Dragon'),
            findsNWidgets(2),
          ); // Card and dialog header
          expect(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Image),
            ),
            findsOneWidget,
          );
          expect(find.text('Prompt / Description:'), findsOneWidget);
          expect(find.text('Majestic red dragon'), findsOneWidget);
          expect(find.text('Source: GEMINI'), findsOneWidget);
          expect(
            find.text('2026-09-14 12:30'),
            findsNWidgets(2),
          ); // Card and dialog
          expect(find.text('Close'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('details_use_button')),
            findsOneWidget,
          );

          // Tap Close to dismiss
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
        },
      );

      testWidgets(
        'tapping popup menu item View Details opens details dialog without prompt container when prompt is empty',
        (tester) async {
          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            title: 'Simple Upload',
            source: 'upload',
          );

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          // Open popup menu and select View Details
          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('View Details'));
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text('Simple Upload'), findsNWidgets(2));
          expect(find.text('Source: UPLOAD'), findsOneWidget);
          expect(find.text('Prompt / Description:'), findsNothing);

          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
        },
      );

      testWidgets(
        'tapping Use in Canvas in details dialog sets reference on notifier and dismisses dialog',
        (tester) async {
          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            bmpBytes: sampleBmp,
            title: 'Canvas Target',
            prompt: 'Target prompt',
            source: 'gemini',
          );

          final notifier = TrackingCanvasNotifier();

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
                canvasStateProvider.overrideWith((ref) => notifier),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_card_${item.id}')));
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsOneWidget);

          await tester.tap(find.byKey(const ValueKey('details_use_button')));
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsNothing);
          expect(notifier.setReferenceImageCallCount, equals(1));
          expect(notifier.lastSetReferenceBmp, equals(sampleBmp));
          expect(notifier.lastSetReferenceOriginal, equals(sampleBmp));
          expect(notifier.updatePromptCallCount, equals(1));
          expect(notifier.lastUpdatedPrompt, equals('Target prompt'));
          expect(
            find.text('Applied "Canvas Target" as active reference'),
            findsOneWidget,
          );
        },
      );
    });

    group('Edit Dialog (_showEditDialog)', () {
      late Uint8List sampleBmp;

      setUp(() {
        sampleBmp = generateBmpFromRgba(
          Uint8List.fromList([0, 255, 0, 255]),
          1,
          1,
        );
      });

      testWidgets('opens edit dialog pre-filled with title and prompt', (
        tester,
      ) async {
        final item = await repository.addReferenceImage(
          imageBytes: sampleBmp,
          bmpBytes: sampleBmp,
          title: 'Original Title',
          prompt: 'Original Prompt',
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

        await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit Title & Prompt'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Edit Reference Details'), findsOneWidget);

        final textFields = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        expect(textFields, findsNWidgets(2));
        final titleField = tester.widget<TextField>(textFields.at(0));
        expect(titleField.controller?.text, equals('Original Title'));
        final promptField = tester.widget<TextField>(textFields.at(1));
        expect(promptField.controller?.text, equals('Original Prompt'));

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
      });

      testWidgets(
        'cancelling edit dialog dismisses without persisting changes',
        (tester) async {
          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            title: 'Untouched Title',
            prompt: 'Untouched Prompt',
          );

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Edit Title & Prompt'));
          await tester.pumpAndSettle();

          final textFields = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          );
          final titleController = tester
              .widget<TextField>(textFields.at(0))
              .controller!;
          final promptController = tester
              .widget<TextField>(textFields.at(1))
              .controller!;

          await tester.enterText(textFields.at(0), 'Discarded Title');
          await tester.enterText(textFields.at(1), 'Discarded Prompt');

          await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text('Untouched Title'), findsOneWidget);

          expect(() => titleController.addListener(() {}), throwsFlutterError);
          expect(() => promptController.addListener(() {}), throwsFlutterError);

          final fromDb = await db.getReferenceImageById(item.id);
          expect(fromDb?.title, equals('Untouched Title'));
          expect(fromDb?.prompt, equals('Untouched Prompt'));
        },
      );

      testWidgets(
        'submitting edits updates repository, refreshes grid, and closes dialog',
        (tester) async {
          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            title: 'Initial Title',
            prompt: 'Initial Prompt',
          );

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Edit Title & Prompt'));
          await tester.pumpAndSettle();

          final textFields = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          );
          final titleController = tester
              .widget<TextField>(textFields.at(0))
              .controller!;
          final promptController = tester
              .widget<TextField>(textFields.at(1))
              .controller!;

          await tester.enterText(textFields.at(0), 'Saved Title');
          await tester.enterText(textFields.at(1), 'Saved Prompt');

          await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text('Saved Title'), findsOneWidget);
          expect(find.text('Initial Title'), findsNothing);

          expect(() => titleController.addListener(() {}), throwsFlutterError);
          expect(() => promptController.addListener(() {}), throwsFlutterError);

          final fromDb = await db.getReferenceImageById(item.id);
          expect(fromDb?.title, equals('Saved Title'));
          expect(fromDb?.prompt, equals('Saved Prompt'));
        },
      );

      testWidgets(
        'dismissing edit dialog by tapping barrier disposes controllers',
        (tester) async {
          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            title: 'Barrier Title',
            prompt: 'Barrier Prompt',
          );

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Edit Title & Prompt'));
          await tester.pumpAndSettle();

          final textFields = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          );
          final titleController = tester
              .widget<TextField>(textFields.at(0))
              .controller!;
          final promptController = tester
              .widget<TextField>(textFields.at(1))
              .controller!;

          // Tap outside the dialog on the modal barrier
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsNothing);
          expect(() => titleController.addListener(() {}), throwsFlutterError);
          expect(() => promptController.addListener(() {}), throwsFlutterError);
        },
      );

      testWidgets(
        'disables Save and Cancel buttons while saving is in progress',
        (tester) async {
          final completer = Completer<void>();
          final testRepo = repository as TestReferenceLibraryRepository;
          testRepo.onUpdateDetails = (id, title, prompt) => completer.future;

          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            title: 'In Flight Title',
            prompt: 'In Flight Prompt',
          );

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Edit Title & Prompt'));
          await tester.pumpAndSettle();

          final saveButtonFinder = find.widgetWithText(ElevatedButton, 'Save');
          final cancelButtonFinder = find.widgetWithText(TextButton, 'Cancel');

          // Verify buttons initially enabled
          expect(
            tester.widget<ElevatedButton>(saveButtonFinder).onPressed,
            isNotNull,
          );
          expect(
            tester.widget<TextButton>(cancelButtonFinder).onPressed,
            isNotNull,
          );

          // Tap Save button to initiate saving
          await tester.tap(saveButtonFinder);
          await tester.pump();

          // While async call is in flight, buttons must be disabled
          expect(
            tester.widget<ElevatedButton>(saveButtonFinder).onPressed,
            isNull,
          );
          expect(
            tester.widget<TextButton>(cancelButtonFinder).onPressed,
            isNull,
          );

          // Complete save
          completer.complete();
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsNothing);
          testRepo.onUpdateDetails = null;
        },
      );

      testWidgets(
        'shows error SnackBar and re-enables buttons when saving fails',
        (tester) async {
          final testRepo = repository as TestReferenceLibraryRepository;
          testRepo.onUpdateDetails = (id, title, prompt) async {
            throw Exception('Disk write failed');
          };

          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            title: 'Error Title',
            prompt: 'Error Prompt',
          );

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Edit Title & Prompt'));
          await tester.pumpAndSettle();

          final saveButtonFinder = find.widgetWithText(ElevatedButton, 'Save');
          await tester.tap(saveButtonFinder);
          await tester.pumpAndSettle();

          // Dialog remains open, SnackBar is shown
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            find.text(
              'Failed to update reference details: Exception: Disk write failed',
            ),
            findsOneWidget,
          );
          // Save button is re-enabled
          expect(
            tester.widget<ElevatedButton>(saveButtonFinder).onPressed,
            isNotNull,
          );

          // Cancel to close dialog
          await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          testRepo.onUpdateDetails = null;
        },
      );

      testWidgets(
        'does not call onSaved or pop if dialog unmounts while save is in flight',
        (tester) async {
          final completer = Completer<void>();
          final testRepo = repository as TestReferenceLibraryRepository;
          testRepo.onUpdateDetails = (id, title, prompt) => completer.future;

          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            title: 'Unmount Title',
            prompt: 'Unmount Prompt',
          );

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Edit Title & Prompt'));
          await tester.pumpAndSettle();

          await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
          await tester.pump();

          // Force dismiss dialog while save is still awaiting
          Navigator.of(tester.element(find.byType(AlertDialog))).pop();
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsNothing);

          // Now complete the save - mounted check should prevent errors
          completer.complete();
          await tester.pumpAndSettle();

          testRepo.onUpdateDetails = null;
        },
      );
    });

    group('Delete Dialog (_showDeleteDialog)', () {
      late Uint8List sampleBmp;

      setUp(() {
        sampleBmp = generateBmpFromRgba(
          Uint8List.fromList([0, 0, 255, 255]),
          1,
          1,
        );
      });

      testWidgets(
        'opens confirmation dialog and cancelling preserves item in repository',
        (tester) async {
          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            title: 'Do Not Delete',
          );

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Delete'));
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text('Delete Reference Image'), findsOneWidget);
          expect(
            find.text(
              'Are you sure you want to delete "Do Not Delete" from your library?',
            ),
            findsOneWidget,
          );

          await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text('Do Not Delete'), findsOneWidget);
          expect(await db.getReferenceImageById(item.id), isNotNull);
        },
      );

      testWidgets('confirming delete removes item from repository and UI', (
        tester,
      ) async {
        final item = await repository.addReferenceImage(
          imageBytes: sampleBmp,
          title: 'Delete Me',
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

        await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Delete Me'), findsNothing);
        expect(await db.getReferenceImageById(item.id), isNull);
        // Empty state is shown
        expect(
          find.text('No reference images in your library yet'),
          findsOneWidget,
        );
      });
    });

    group('File Import Workflow (_importImageFromFile)', () {
      late Uint8List sampleBmp;
      late FilePickerPlatform initialPicker;

      setUp(() {
        initialPicker = FilePickerPlatform.instance;
        sampleBmp = generateBmpFromRgba(
          Uint8List.fromList([255, 255, 0, 255]),
          1,
          1,
        );
      });

      tearDown(() {
        FilePickerPlatform.instance = initialPicker;
      });

      testWidgets(
        'empty state import button imports single image successfully and updates grid',
        (tester) async {
          final fakePicker = FakeFilePickerPlatform(
            pickFilesResult: FilePickerResult([
              PlatformFile(
                name: 'pixel_potion.png',
                size: sampleBmp.length,
                bytes: sampleBmp,
              ),
            ]),
          );
          FilePickerPlatform.instance = fakePicker;

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('empty_state_import_button')),
            findsOneWidget,
          );

          await tester.tap(
            find.byKey(const ValueKey('empty_state_import_button')),
          );
          await tester.pumpAndSettle();

          expect(find.text('Imported 1 image into library'), findsOneWidget);
          expect(find.text('pixel_potion'), findsOneWidget);

          final images = await repository.getAllReferenceImages();
          expect(images.length, equals(1));
          expect(images.first.title, equals('pixel_potion'));
          expect(images.first.source, equals('upload'));
        },
      );

      testWidgets(
        'appbar import button imports multiple images successfully and pluralizes snackbar',
        (tester) async {
          final fakePicker = FakeFilePickerPlatform(
            pickFilesResult: FilePickerResult([
              PlatformFile(
                name: 'item_sword.png',
                size: sampleBmp.length,
                bytes: sampleBmp,
              ),
              PlatformFile(
                name: 'item_shield.bmp',
                size: sampleBmp.length,
                bytes: sampleBmp,
              ),
            ]),
          );
          FilePickerPlatform.instance = fakePicker;

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('add_reference_image_button')),
            findsOneWidget,
          );

          await tester.tap(
            find.byKey(const ValueKey('add_reference_image_button')),
          );
          await tester.pumpAndSettle();

          expect(find.text('Imported 2 images into library'), findsOneWidget);
          expect(find.text('item_sword'), findsOneWidget);
          expect(find.text('item_shield'), findsOneWidget);

          final images = await repository.getAllReferenceImages();
          expect(images.length, equals(2));
        },
      );

      testWidgets(
        'skips files with null bytes and uses default title when filename has no extension prefix',
        (tester) async {
          final fakePicker = FakeFilePickerPlatform(
            pickFilesResult: FilePickerResult([
              PlatformFile(name: 'null_bytes.png', size: 0, bytes: null),
              PlatformFile(
                name: '.png',
                size: sampleBmp.length,
                bytes: sampleBmp,
              ),
            ]),
          );
          FilePickerPlatform.instance = fakePicker;

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(
            find.byKey(const ValueKey('empty_state_import_button')),
          );
          await tester.pumpAndSettle();

          expect(find.text('Imported 1 image into library'), findsOneWidget);
          final images = await repository.getAllReferenceImages();
          expect(images.length, equals(1));
          // When filename is empty string (split on dot is empty), repository defaults title to 'Reference (M/D H:mm)'
          expect(images.first.title, startsWith('Reference ('));
        },
      );

      testWidgets(
        'file picker cancellation does not modify repository or display snackbar',
        (tester) async {
          final fakePicker = FakeFilePickerPlatform(pickFilesResult: null);
          FilePickerPlatform.instance = fakePicker;

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(
            find.byKey(const ValueKey('empty_state_import_button')),
          );
          await tester.pumpAndSettle();

          expect(find.byType(SnackBar), findsNothing);
          expect(await repository.getAllReferenceImages(), isEmpty);
        },
      );

      testWidgets('file picker exception displays error SnackBar gracefully', (
        tester,
      ) async {
        final fakePicker = FakeFilePickerPlatform(shouldThrow: true);
        FilePickerPlatform.instance = fakePicker;

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              referenceLibraryRepositoryProvider.overrideWithValue(repository),
            ],
            child: const ReferenceLibraryScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('empty_state_import_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Failed to import images: Exception: FilePicker picking failed',
          ),
          findsOneWidget,
        );
        expect(await repository.getAllReferenceImages(), isEmpty);
      });
    });

    group('Direct Canvas Selection (_selectImage)', () {
      late Uint8List sampleBmp;

      setUp(() {
        sampleBmp = generateBmpFromRgba(
          Uint8List.fromList([128, 64, 32, 255]),
          1,
          1,
        );
      });

      testWidgets(
        'selection with bmpData sets referenceImage with originalBytes and shows SnackBar',
        (tester) async {
          final rawImageBytes = generateBmpFromRgba(
            Uint8List.fromList([200, 100, 50, 255]),
            1,
            1,
          );
          final item = await repository.addReferenceImage(
            imageBytes: rawImageBytes,
            bmpBytes: sampleBmp,
            title: 'Bmp Selection',
            prompt: 'Prompt for selection',
            source: 'gemini',
          );

          final notifier = TrackingCanvasNotifier();

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
                canvasStateProvider.overrideWith((ref) => notifier),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Use as Reference'));
          await tester.pumpAndSettle();

          expect(notifier.setReferenceImageCallCount, equals(1));
          expect(notifier.lastSetReferenceBmp, equals(sampleBmp));
          expect(notifier.lastSetReferenceOriginal, equals(rawImageBytes));
          expect(
            find.text('Applied "Bmp Selection" as active reference'),
            findsOneWidget,
          );
          // Navigator is not popped in non-picker mode
          expect(find.byType(ReferenceLibraryScreen), findsOneWidget);
        },
      );

      testWidgets('selection without bmpData calls setUploadedReferenceImage', (
        tester,
      ) async {
        final now = DateTime.now();
        final id = await db.createReferenceImage(
          ReferenceImagesCompanion(
            title: const drift.Value('Raw Only Item'),
            imageData: drift.Value(sampleBmp),
            bmpData: const drift.Value(null),
            source: const drift.Value('upload'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        final item = (await db.getReferenceImageById(id))!;

        final notifier = TrackingCanvasNotifier();

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              referenceLibraryRepositoryProvider.overrideWithValue(repository),
              canvasStateProvider.overrideWith((ref) => notifier),
            ],
            child: const ReferenceLibraryScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Use as Reference'));
        await tester.pumpAndSettle();

        expect(notifier.setUploadedReferenceImageCallCount, equals(1));
        expect(notifier.lastSetUploadedRawBytes, equals(sampleBmp));
        expect(
          find.text('Applied "Raw Only Item" as active reference'),
          findsOneWidget,
        );
      });

      testWidgets(
        'auto-populates prompt when canvas userPrompt is currently empty',
        (tester) async {
          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            bmpBytes: sampleBmp,
            title: 'Prompt Auto Fill',
            prompt: 'New generated prompt',
          );

          final notifier = TrackingCanvasNotifier(initialPrompt: '');

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
                canvasStateProvider.overrideWith((ref) => notifier),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Use as Reference'));
          await tester.pumpAndSettle();

          expect(notifier.updatePromptCallCount, equals(1));
          expect(notifier.lastUpdatedPrompt, equals('New generated prompt'));
        },
      );

      testWidgets(
        'preserves existing canvas prompt when userPrompt is already populated',
        (tester) async {
          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            bmpBytes: sampleBmp,
            title: 'Keep Prompt',
            prompt: 'Ignored item prompt',
          );

          final notifier = TrackingCanvasNotifier(
            initialPrompt: 'Existing canvas prompt',
          );

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
                canvasStateProvider.overrideWith((ref) => notifier),
              ],
              child: const ReferenceLibraryScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Use as Reference'));
          await tester.pumpAndSettle();

          expect(notifier.updatePromptCallCount, equals(0));
          expect(notifier.state.userPrompt, equals('Existing canvas prompt'));
        },
      );

      testWidgets(
        'invokes onImageSelected callback in non-picker mode if provided',
        (tester) async {
          final item = await repository.addReferenceImage(
            imageBytes: sampleBmp,
            bmpBytes: sampleBmp,
            title: 'Callback Target',
          );

          ReferenceImage? callbackResult;

          await tester.pumpWidget(
            buildTestableWidget(
              overrides: [
                referenceLibraryRepositoryProvider.overrideWithValue(
                  repository,
                ),
              ],
              child: ReferenceLibraryScreen(
                onImageSelected: (selected) {
                  callbackResult = selected;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(ValueKey('reference_menu_${item.id}')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Use as Reference'));
          await tester.pumpAndSettle();

          expect(callbackResult, isNotNull);
          expect(callbackResult?.id, equals(item.id));
          expect(callbackResult?.title, equals('Callback Target'));
        },
      );
    });
  });
}
