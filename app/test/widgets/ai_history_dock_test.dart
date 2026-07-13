import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:bad_pixel_art/widgets/ai_history_dock.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:local_agent/local_agent.dart';
import '../test_helper.dart';

class MockFilePickerPlatform extends FilePickerPlatform {
  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    return null; // Simulate user cancel to trigger fallback save logic
  }
}

class LocalMockAiService implements AiService {
  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    bool lowTemperature = false,
  }) async {
    if (lowTemperature) {
      final List<String> mockPalette = List.generate(16, (i) {
        final val = (i * 0x11).toRadixString(16).padLeft(2, '0');
        return '#$val$val$val';
      });
      return '["${mockPalette.join('", "')}"]';
    }
    return null;
  }
}

void main() {
  group('AiHistoryDock Widget & Golden Tests', () {
    testWidgets('starts collapsed, expands on tap, and shows empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: AiHistoryDock())),
      );

      // Verify starts collapsed (empty state text should not be visible yet)
      expect(find.textContaining('No AI history logs yet.'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('AI History & Debugger'));
      await tester.pumpAndSettle();

      // Verify empty state message is visible
      expect(find.textContaining('No AI history logs yet.'), findsOneWidget);
    });

    testWidgets('renders log entries and handles detail expand tap', (
      tester,
    ) async {
      final entry = AiHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 15, 30),
        prompt: 'System Instructions:\nDraw a test sword.',
        response:
            '{"understanding":"I see a basic layout.","reasoning":"Adding a structural line.","tool":"line","params":[0,0,5,5]}',
        isError: false,
        canvasImage: combineBmps([
          generateBmp(
            List.generate(64, (_) => List.filled(64, 0)),
            CanvasNotifier.primaryPalette,
          ),
        ]),
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      final widget = ProviderScope(
        overrides: [
          aiServiceProvider.overrideWithValue(mockService),
          canvasStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
        ),
      );

      await tester.pumpWidget(widget);

      // Expand history dock
      await tester.tap(find.text('AI History & Debugger'));
      await tester.pumpAndSettle();

      // Verify log summary exists
      expect(find.text('10:15:30'), findsOneWidget);
      expect(find.text('Stroke suggested successfully'), findsOneWidget);

      // Verify details are collapsed initially
      expect(find.text('PROMPT:'), findsNothing);

      // Tap log summary row to expand details
      await tester.tap(find.text('Stroke suggested successfully'));
      await tester.pumpAndSettle();

      // Verify prompt and response headers/texts are shown
      expect(find.text('PROMPT:'), findsOneWidget);
      expect(find.text('RESPONSE:'), findsOneWidget);
      expect(
        find.text('System Instructions:\nDraw a test sword.'),
        findsOneWidget,
      );
      expect(
        find.text(
          '{"understanding":"I see a basic layout.","reasoning":"Adding a structural line.","tool":"line","params":[0,0,5,5]}',
        ),
        findsOneWidget,
      );
    });

    testGoldens('AiHistoryDock renders correctly', (tester) async {
      final entry = AiHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 15, 30),
        prompt: 'System Instructions:\nDraw a test sword.',
        response:
            '{"understanding":"I see a basic layout.","reasoning":"Adding a structural line.","tool":"line","params":[0,0,5,5]}',
        isError: false,
        canvasImage: combineBmps([
          generateBmp(
            List.generate(64, (_) => List.filled(64, 0)),
            CanvasNotifier.primaryPalette,
          ),
        ]),
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      final builder = GoldenBuilder.grid(columns: 1, widthToHeightRatio: 2.5)
        ..addScenario(
          'History Dock Collapsed',
          const SingleChildScrollView(child: AiHistoryDock()),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: testMaterialAppWrapper(
          overrides: [
            aiServiceProvider.overrideWithValue(mockService),
            canvasStateProvider.overrideWith((ref) => notifier),
          ],
        ),
      );
      await screenMatchesGolden(tester, 'ai_history_dock');
    });

    testGoldens('AiHistoryDock renders expanded correctly', (tester) async {
      final entry = AiHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 15, 30),
        prompt: 'System Instructions:\nDraw a test sword.',
        response:
            '{"understanding":"I see a basic layout.","reasoning":"Adding a structural line.","tool":"line","params":[0,0,5,5]}',
        isError: false,
        canvasImage: combineBmps([
          generateBmp(
            List.generate(64, (_) => List.filled(64, 0)),
            CanvasNotifier.primaryPalette,
          ),
        ]),
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      await tester.pumpWidgetBuilder(
        const Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
        wrapper: testMaterialAppWrapper(
          overrides: [
            aiServiceProvider.overrideWithValue(mockService),
            canvasStateProvider.overrideWith((ref) => notifier),
          ],
        ),
      );

      // Expand history dock
      await tester.tap(find.text('AI History & Debugger'));
      await tester.pumpAndSettle();

      // Expand history item details so we see prompt/response in the golden
      await tester.tap(find.text('Stroke suggested successfully'));
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'ai_history_dock_expanded');
    });

    testWidgets('Export Logs button is present and exports history to file', (
      tester,
    ) async {
      // Mock FilePicker platform instance to prevent FFI / channel hang
      final originalPlatform = FilePickerPlatform.instance;
      FilePickerPlatform.instance = MockFilePickerPlatform();

      final entry = AiHistoryEntry(
        timestamp: DateTime(2026, 7, 11, 10, 15, 30),
        prompt: 'System Instructions:\nDraw a test sword.',
        response: '{"tool":"line"}',
        isError: false,
        canvasImage: combineBmps([
          generateBmp(
            List.generate(64, (_) => List.filled(64, 0)),
            CanvasNotifier.primaryPalette,
          ),
        ]),
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      final widget = ProviderScope(
        overrides: [
          aiServiceProvider.overrideWithValue(mockService),
          canvasStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AiHistoryDock())),
        ),
      );

      await tester.pumpWidget(widget);

      // Verify download button is not visible initially when collapsed
      expect(find.byIcon(Icons.file_download_outlined), findsNothing);

      // Expand history dock
      await tester.tap(find.text('AI History & Debugger'));
      await tester.pumpAndSettle();

      // Find the download button
      final exportButton = find.byIcon(Icons.file_download_outlined);
      expect(exportButton, findsOneWidget);

      bool fileFoundAndVerified = false;

      await tester.runAsync(() async {
        // Tap the download button (triggers _exportHistory)
        await tester.tap(exportButton);
        await tester.pump();

        // Wait a short moment for the file system write to complete
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify generated file in exports or current folder
        final pathsToCheck = [
          '/home/mweastwood/projects/BadPixelArt/exports',
          Directory.current.path,
        ];

        for (final dirPath in pathsToCheck) {
          final dir = Directory(dirPath);
          if (await dir.exists()) {
            final List<FileSystemEntity> entities = await dir.list().toList();
            for (final entity in entities) {
              if (entity is File &&
                  entity.path.contains('ai_drawing_history_') &&
                  entity.path.endsWith('.json')) {
                // Read and parse
                final content = await entity.readAsString();
                final decoded = jsonDecode(content);

                // Verify contents
                expect(decoded, isA<List>());
                expect(decoded.length, 1);
                expect(
                  decoded[0]['prompt'],
                  'System Instructions:\nDraw a test sword.',
                );
                expect(decoded[0]['response'], '{"tool":"line"}');
                expect(decoded[0]['isError'], false);
                expect(decoded[0]['canvasImageBase64'], isNotNull);

                // Clean up
                await entity.delete();
                fileFoundAndVerified = true;
                break;
              }
            }
          }
          if (fileFoundAndVerified) break;
        }
      });

      expect(
        fileFoundAndVerified,
        isTrue,
        reason: 'Log file should be exported and verified',
      );

      // Restore platform instance
      FilePickerPlatform.instance = originalPlatform;
    });
  });
}
