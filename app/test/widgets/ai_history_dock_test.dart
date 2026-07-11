import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:bad_pixel_art/widgets/ai_history_dock.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/ai_service.dart';
import '../test_helper.dart';

class LocalMockAiService implements AiService {
  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<Map<String, dynamic>?> getNextStroke({
    required Uint8List canvasImage,
    required String prompt,
  }) async {
    return null;
  }

  @override
  Future<List<Color>?> suggestPalette(Uint8List referenceImage) async =>
      List.generate(16, (i) => Color(0xFF000000 + i));
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
  });
}
