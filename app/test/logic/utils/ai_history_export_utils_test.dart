import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/utils/ai_history_export_utils.dart';

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
  });
}
