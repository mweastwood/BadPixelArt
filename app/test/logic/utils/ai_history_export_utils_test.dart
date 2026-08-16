import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/utils/ai_history_export_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String? appDocsPath;
  final bool shouldThrow;

  FakePathProviderPlatform({this.appDocsPath, this.shouldThrow = false});

  @override
  Future<String?> getApplicationDocumentsPath() async {
    if (shouldThrow) {
      throw Exception('Path provider not available');
    }
    return appDocsPath;
  }
}

class FakeFilePickerPlatform extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  final String? saveFilePath;
  final String? directoryPath;
  final bool shouldThrow;

  FakeFilePickerPlatform({
    this.saveFilePath,
    this.directoryPath,
    this.shouldThrow = false,
  });

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
    if (shouldThrow) {
      throw Exception('FilePicker saveFile failed');
    }
    return saveFilePath;
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    if (shouldThrow) {
      throw Exception('FilePicker getDirectoryPath failed');
    }
    return directoryPath;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('osPathBasename', () {
    test('extracts basename from standard POSIX paths', () {
      expect(osPathBasename('/home/user/exports/history.json'), 'history.json');
      expect(osPathBasename('/var/log/app.log'), 'app.log');
      expect(osPathBasename('/single_level'), 'single_level');
    });

    test('extracts basename from Windows backslash paths', () {
      expect(
        osPathBasename(r'C:\Users\mweastwood\projects\exports\history.json'),
        'history.json',
      );
      expect(osPathBasename(r'D:\data\export.txt'), 'export.txt');
    });

    test('extracts basename from mixed separator paths', () {
      expect(osPathBasename(r'/home/user\mixed/file.json'), 'file.json');
      expect(osPathBasename(r'C:/nested\sub/folder\name.json'), 'name.json');
    });

    test('returns the original string if no separator is present', () {
      expect(osPathBasename('history.json'), 'history.json');
      expect(osPathBasename('simple_filename'), 'simple_filename');
      expect(osPathBasename(''), '');
    });
  });

  group('formatLogTimestamp', () {
    test('correctly zero-pads single-digit date and time components', () {
      final dt = DateTime(2026, 1, 5, 4, 3, 2);
      expect(formatLogTimestamp(dt), '2026-01-05 04:03:02');
    });

    test('correctly formats double-digit date and time components', () {
      final dt = DateTime(2026, 12, 25, 23, 59, 58);
      expect(formatLogTimestamp(dt), '2026-12-25 23:59:58');
    });

    test('handles midnight edge cases', () {
      final dt = DateTime(2026, 10, 10, 0, 0, 0);
      expect(formatLogTimestamp(dt), '2026-10-10 00:00:00');
    });
  });

  group('copyAiHistoryToClipboard', () {
    testWidgets('shows snackbar when history is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => copyAiHistoryToClipboard(context, []),
                child: const Text('Copy'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pump();

      expect(find.text('No history to copy'), findsOneWidget);
    });

    testWidgets('copies serialized json to clipboard and shows snackbar', (
      tester,
    ) async {
      final history = [
        AgentHistoryEntry(
          timestamp: DateTime(2026, 7, 26, 11, 57, 30),
          prompt: 'Draw a circle',
          response: 'Done drawing',
          isError: false,
          modelName: 'Gemini 2.0 Flash',
        ),
      ];

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => copyAiHistoryToClipboard(context, history),
                child: const Text('Copy'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pump();

      expect(find.text('AI History copied to clipboard!'), findsOneWidget);
      expect(clipboardText, isNotNull);
      expect(clipboardText, contains('Draw a circle'));
      expect(clipboardText, contains('Done drawing'));
    });
  });

  group('exportAiHistory', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ai_history_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('shows snackbar when history is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => exportAiHistory(context, []),
                child: const Text('Export'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Export'));
      await tester.pump();

      expect(find.text('No history to export'), findsOneWidget);
    });

    testWidgets('exports history to application documents directory fallback', (
      tester,
    ) async {
      FilePickerPlatform.instance = FakeFilePickerPlatform(
        saveFilePath: null,
        directoryPath: null,
      );
      PathProviderPlatform.instance = FakePathProviderPlatform(
        appDocsPath: tempDir.path,
      );

      final history = [
        AgentHistoryEntry(
          timestamp: DateTime(2026, 8, 16, 3, 0, 0),
          prompt: 'Generate spaceship',
          response: 'Rendered pixel spaceship',
          isError: false,
          modelName: 'Gemini 2.5 Flash',
        ),
      ];

      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildContext = context;
                return const Text('Ready');
              },
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await exportAiHistory(buildContext, history);
      });
      await tester.pump();

      expect(find.textContaining('Exported successfully to:'), findsOneWidget);

      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.isNotEmpty, isTrue);
      final content = files.first.readAsStringSync();
      expect(content, contains('Generate spaceship'));
      expect(content, contains('Rendered pixel spaceship'));
    });

    testWidgets(
      'falls back to systemTemp when getApplicationDocumentsDirectory throws',
      (tester) async {
        FilePickerPlatform.instance = FakeFilePickerPlatform(
          saveFilePath: null,
          directoryPath: null,
        );
        PathProviderPlatform.instance = FakePathProviderPlatform(
          shouldThrow: true,
        );

        final history = [
          AgentHistoryEntry(
            timestamp: DateTime(2026, 8, 16, 3, 0, 0),
            prompt: 'Fallback prompt test',
            response: 'Fallback response test',
            isError: false,
            modelName: 'Gemini 2.5 Flash',
          ),
        ];

        late BuildContext buildContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  buildContext = context;
                  return const Text('Ready');
                },
              ),
            ),
          ),
        );

        await tester.runAsync(() async {
          await exportAiHistory(buildContext, history);
        });
        await tester.pump();

        expect(
          find.textContaining('Exported successfully to:'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'uses selected directory path when getDirectoryPath returns a path',
      (tester) async {
        FilePickerPlatform.instance = FakeFilePickerPlatform(
          saveFilePath: null,
          directoryPath: tempDir.path,
        );

        final history = [
          AgentHistoryEntry(
            timestamp: DateTime(2026, 8, 16, 3, 0, 0),
            prompt: 'Selected directory test',
            response: 'Selected directory response',
            isError: false,
            modelName: 'Gemini 2.5 Flash',
          ),
        ];

        late BuildContext buildContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  buildContext = context;
                  return const Text('Ready');
                },
              ),
            ),
          ),
        );

        await tester.runAsync(() async {
          await exportAiHistory(buildContext, history);
        });
        await tester.pump();

        expect(
          find.textContaining('Exported successfully to:'),
          findsOneWidget,
        );
        final files = tempDir.listSync().whereType<File>().toList();
        expect(files.isNotEmpty, isTrue);
      },
    );

    testWidgets('clicking Copy Path in SnackBar sets clipboard data', (
      tester,
    ) async {
      FilePickerPlatform.instance = FakeFilePickerPlatform(
        saveFilePath: null,
        directoryPath: tempDir.path,
      );

      String? copiedPath;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedPath = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      final history = [
        AgentHistoryEntry(
          timestamp: DateTime(2026, 8, 16, 3, 0, 0),
          prompt: 'Copy path test',
          response: 'Copy path response',
          isError: false,
          modelName: 'Gemini 2.5 Flash',
        ),
      ];

      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildContext = context;
                return const Text('Ready');
              },
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await exportAiHistory(buildContext, history);
      });
      await tester.pump();

      expect(find.byType(SnackBarAction), findsOneWidget);
      final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
      action.onPressed();
      await tester.pump();

      expect(copiedPath, isNotNull);
      expect(copiedPath, contains('ai_drawing_history_'));
    });
  });
}
