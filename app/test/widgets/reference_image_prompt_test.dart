import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/repositories/reference_library_repository.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';
import 'package:bad_pixel_art/widgets/reference_image_prompt.dart';

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

class ThrowingReferenceLibraryRepository extends ReferenceLibraryRepository {
  ThrowingReferenceLibraryRepository({required super.dbGetter});

  @override
  Future<ReferenceImage> addReferenceImage({
    required Uint8List imageBytes,
    Uint8List? bmpBytes,
    String? title,
    String? prompt,
    String source = 'upload',
  }) async {
    throw Exception('Database write failed');
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReferenceImagePrompt Widget & Golden Tests', () {
    late AppDatabase db;
    late ReferenceLibraryRepository repository;
    late Uint8List sampleBmp;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      repository = ReferenceLibraryRepository(dbGetter: () => db);
      sampleBmp = generateBmp(
        List.generate(16, (_) => List.filled(16, 1)),
        CanvasNotifier.primaryPalette,
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'renders initial empty state correctly with upload and library options',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        // Verify header and empty state options
        expect(find.text('Reference & Prompt'), findsOneWidget);
        expect(find.text('Reference Image'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('upload_reference_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('library_reference_button')),
          findsOneWidget,
        );
        expect(find.text('User Instructions / Prompt'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('remove_reference_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'renders active reference state with previews and action toolbar',
      (tester) async {
        final notifier = CanvasNotifier(TestMockAiService());
        notifier.setReferenceImage(sampleBmp);
        notifier.state = notifier.state.copyWith(
          originalReferenceImage: sampleBmp,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        expect(find.text('Active Reference'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('library_button_active')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('save_to_library_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('change_reference_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('remove_reference_button')),
          findsOneWidget,
        );
        expect(find.text('Original'), findsOneWidget);
        expect(find.text('Model Input (512x512)'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('auto_suggest_description_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders broken image fallback when originalReferenceImage length is under 10 bytes',
      (tester) async {
        final notifier = CanvasNotifier(TestMockAiService());
        notifier.setReferenceImage(sampleBmp);
        notifier.state = notifier.state.copyWith(
          originalReferenceImage: Uint8List.fromList([1, 2, 3, 4]),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'tapping remove_reference_button clears reference image in CanvasNotifier',
      (tester) async {
        final notifier = CanvasNotifier(TestMockAiService());
        notifier.setReferenceImage(sampleBmp);
        notifier.state = notifier.state.copyWith(
          originalReferenceImage: sampleBmp,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        expect(
          find.byKey(const ValueKey('remove_reference_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('remove_reference_button')));
        await tester.pumpAndSettle();

        expect(notifier.state.referenceImage, isNull);
        expect(
          find.byKey(const ValueKey('upload_reference_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('remove_reference_button')),
          findsNothing,
        );
      },
    );

    testWidgets('tapping library_reference_button opens picker', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: const Scaffold(body: ReferenceImagePrompt()),
        ),
      );

      final fromLibraryButton = find.byKey(
        const ValueKey('library_reference_button'),
      );
      expect(fromLibraryButton, findsOneWidget);
      await tester.tap(fromLibraryButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Select Reference Image'), findsOneWidget);
    });

    testWidgets('tapping library_button_active opens picker', (tester) async {
      final notifier = CanvasNotifier(TestMockAiService());
      notifier.setReferenceImage(sampleBmp);

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
          child: const Scaffold(body: ReferenceImagePrompt()),
        ),
      );

      final activeLibButton = find.byKey(
        const ValueKey('library_button_active'),
      );
      expect(activeLibButton, findsOneWidget);
      await tester.tap(activeLibButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Select Reference Image'), findsOneWidget);
    });

    testWidgets(
      'save to library button saves current image and displays confirmation snackbar',
      (tester) async {
        final notifier = CanvasNotifier(TestMockAiService());
        notifier.setReferenceImage(sampleBmp);
        notifier.state = notifier.state.copyWith(
          originalReferenceImage: sampleBmp,
          userPrompt: 'Legendary Sword',
        );

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              referenceLibraryRepositoryProvider.overrideWithValue(repository),
              canvasStateProvider.overrideWith((ref) => notifier),
            ],
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('save_to_library_button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('Saved "'), findsOneWidget);
        expect(find.textContaining('to Reference Library'), findsOneWidget);

        final items = await repository.getAllReferenceImages();
        expect(items.isNotEmpty, isTrue);
        expect(items.first.prompt, equals('Legendary Sword'));
      },
    );

    testWidgets(
      'save to library displays error snackbar when repository fails',
      (tester) async {
        final throwingRepo = ThrowingReferenceLibraryRepository(
          dbGetter: () => db,
        );
        final notifier = CanvasNotifier(TestMockAiService());
        notifier.setReferenceImage(sampleBmp);

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              referenceLibraryRepositoryProvider.overrideWithValue(
                throwingRepo,
              ),
              canvasStateProvider.overrideWith((ref) => notifier),
            ],
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('save_to_library_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Failed to save to library: Exception: Database write failed',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'upload_reference_button picks image, sets reference, and saves to repository',
      (tester) async {
        FilePickerPlatform.instance = FakeFilePickerPlatform(
          pickFilesResult: FilePickerResult([
            PlatformFile(
              name: 'sword_art.png',
              size: sampleBmp.length,
              bytes: sampleBmp,
            ),
          ]),
        );

        final notifier = CanvasNotifier(TestMockAiService());

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              referenceLibraryRepositoryProvider.overrideWithValue(repository),
              canvasStateProvider.overrideWith((ref) => notifier),
            ],
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        await tester.runAsync(() async {
          await tester.tap(
            find.byKey(const ValueKey('upload_reference_button')),
          );
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        expect(
          find.text('Image set as reference & added to library'),
          findsOneWidget,
        );
        expect(notifier.state.referenceImage, isNotNull);
        expect(find.text('Active Reference'), findsOneWidget);

        final items = await repository.getAllReferenceImages();
        expect(items.any((item) => item.title == 'sword_art'), isTrue);
      },
    );

    testWidgets(
      'change_reference_button picks new image and updates reference',
      (tester) async {
        final notifier = CanvasNotifier(TestMockAiService());
        notifier.setReferenceImage(sampleBmp);

        final newBmp = generateBmp(
          List.generate(16, (_) => List.filled(16, 2)),
          CanvasNotifier.primaryPalette,
        );

        FilePickerPlatform.instance = FakeFilePickerPlatform(
          pickFilesResult: FilePickerResult([
            PlatformFile(
              name: 'shield_art.png',
              size: newBmp.length,
              bytes: newBmp,
            ),
          ]),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              referenceLibraryRepositoryProvider.overrideWithValue(repository),
              canvasStateProvider.overrideWith((ref) => notifier),
            ],
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        await tester.runAsync(() async {
          await tester.tap(
            find.byKey(const ValueKey('change_reference_button')),
          );
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        expect(
          find.text('Image set as reference & added to library'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'upload cancelled when file picker returns null does not update state',
      (tester) async {
        FilePickerPlatform.instance = FakeFilePickerPlatform(
          pickFilesResult: null,
        );

        final notifier = CanvasNotifier(TestMockAiService());

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              referenceLibraryRepositoryProvider.overrideWithValue(repository),
              canvasStateProvider.overrideWith((ref) => notifier),
            ],
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('upload_reference_button')));
        await tester.pumpAndSettle();

        expect(notifier.state.referenceImage, isNull);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('upload error displays snackbar when file picker throws', (
      tester,
    ) async {
      FilePickerPlatform.instance = FakeFilePickerPlatform(shouldThrow: true);

      final notifier = CanvasNotifier(TestMockAiService());

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            referenceLibraryRepositoryProvider.overrideWithValue(repository),
            canvasStateProvider.overrideWith((ref) => notifier),
          ],
          child: const Scaffold(body: ReferenceImagePrompt()),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('upload_reference_button')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Failed to pick image: Exception: FilePicker picking failed',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'typing in prompt text field updates CanvasNotifier userPrompt',
      (tester) async {
        final notifier = CanvasNotifier(TestMockAiService());

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Draw a majestic blue dragon');
        await tester.pumpAndSettle();

        expect(
          notifier.state.userPrompt,
          equals('Draw a majestic blue dragon'),
        );
      },
    );

    testWidgets('external userPrompt update syncs with TextField controller', (
      tester,
    ) async {
      final notifier = CanvasNotifier(TestMockAiService());

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
          child: const Scaffold(body: ReferenceImagePrompt()),
        ),
      );

      notifier.updatePrompt('Prompt updated from external source');
      await tester.pumpAndSettle();

      expect(find.text('Prompt updated from external source'), findsOneWidget);
    });

    testWidgets(
      'tapping auto_suggest_description_button triggers suggestDescriptionFromReference',
      (tester) async {
        final mockAiService = TestMockAiService(
          response: 'A pixel art green potion bottle with bubbles',
        );
        final notifier = CanvasNotifier(mockAiService);
        notifier.setReferenceImage(sampleBmp);

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              aiServiceProvider.overrideWithValue(mockAiService),
              canvasStateProvider.overrideWith((ref) => notifier),
            ],
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        final suggestButton = find.byKey(
          const ValueKey('auto_suggest_description_button'),
        );
        expect(suggestButton, findsOneWidget);

        await tester.tap(suggestButton);
        await tester.pumpAndSettle();

        expect(
          notifier.state.userPrompt,
          equals('A pixel art green potion bottle with bubbles'),
        );
        expect(
          find.text('A pixel art green potion bottle with bubbles'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'auto_suggest_description_button renders loading state when isSuggestingDescription is true',
      (tester) async {
        final notifier = CanvasNotifier(TestMockAiService());
        notifier.setReferenceImage(sampleBmp);
        notifier.state = notifier.state.copyWith(isSuggestingDescription: true);

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
            child: const Scaffold(body: ReferenceImagePrompt()),
          ),
        );

        expect(find.text('Suggesting...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        final button = tester.widget<TextButton>(
          find.byKey(const ValueKey('auto_suggest_description_button')),
        );
        expect(button.onPressed, isNull);
      },
    );

    testGoldens('ReferenceImagePrompt renders correctly', (tester) async {
      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
        ..addScenario('Empty State', const ReferenceImagePrompt());

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'reference_image_prompt');
    });

    testGoldens(
      'ReferenceImagePrompt renders active reference state correctly',
      (tester) async {
        final notifier = CanvasNotifier(TestMockAiService());
        notifier.setReferenceImage(sampleBmp);
        notifier.state = notifier.state.copyWith(
          originalReferenceImage: sampleBmp,
          userPrompt: 'A glowing red ruby gem',
        );

        final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.2)
          ..addScenario('Active Reference State', const ReferenceImagePrompt());

        await tester.pumpWidgetBuilder(
          builder.build(),
          wrapper: testMaterialAppWrapper(
            overrides: [canvasStateProvider.overrideWith((ref) => notifier)],
          ),
        );
        await screenMatchesGolden(
          tester,
          'reference_image_prompt_active',
          customPump: (tester) async => tester.pump(),
        );
      },
    );
  });
}
