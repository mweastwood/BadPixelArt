import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/widgets/ai_history_dock.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import '../test_helper.dart';

class LocalMockAiService extends AiService {
  @override
  Future<AiCoreStatus> checkStatus() async => AiCoreStatus.available;

  @override
  Future<void> triggerDownload() async {}

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) async {}

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async => 'Mock AI response';

  @override
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async => 10;
}

Widget buildTestableWidget({required Widget child}) {
  return ProviderScope(child: MaterialApp(home: child));
}

void main() {
  group('AiHistoryDock Widget & Golden Tests', () {
    testWidgets('shows empty state directly when no logs', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: AiHistoryDock())),
      );

      expect(find.textContaining('No AI history logs yet.'), findsOneWidget);
      expect(find.text('0 Messages'), findsOneWidget);
    });

    testWidgets('renders chat messages, timestamps, and bottom statistics', (
      tester,
    ) async {
      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 26, 11, 57, 30),
        prompt: 'Draw a red sword',
        response: 'Adding sword blade pixels',
        isError: false,
        estimatedCostUsd: 0.0025,
        imageBytes: combineBmps([
          generateBmp(
            List.generate(
              CanvasNotifier.gridSize,
              (_) => List.filled(CanvasNotifier.gridSize, 0),
            ),
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
        child: const MaterialApp(home: Scaffold(body: AiHistoryDock())),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Verify User prompt and AI response text
      expect(find.text('Draw a red sword'), findsOneWidget);
      expect(find.text('Adding sword blade pixels'), findsOneWidget);

      // Verify timestamp
      expect(find.textContaining('2026-07-26 11:57:30'), findsNWidgets(2));

      // Verify bottom statistics
      expect(find.text('1 Messages'), findsOneWidget);
      expect(find.text('Total Cost: \$0.0025'), findsOneWidget);
    });

    testGoldens('AiHistoryDock renders correctly', (tester) async {
      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 26, 11, 57, 30),
        prompt: 'Draw a red sword',
        response: 'Adding sword blade pixels',
        isError: false,
        estimatedCostUsd: 0.0025,
        imageBytes: combineBmps([
          generateBmp(
            List.generate(
              CanvasNotifier.gridSize,
              (_) => List.filled(CanvasNotifier.gridSize, 0),
            ),
            CanvasNotifier.primaryPalette,
          ),
        ]),
      );

      final mockService = LocalMockAiService();
      final notifier = CanvasNotifier(mockService);
      notifier.state = notifier.state.copyWith(aiHistory: [entry]);

      await tester.pumpWidgetBuilder(
        const Scaffold(body: AiHistoryDock()),
        wrapper: testMaterialAppWrapper(
          overrides: [
            aiServiceProvider.overrideWithValue(mockService),
            canvasStateProvider.overrideWith((ref) => notifier),
          ],
        ),
      );
      await screenMatchesGolden(tester, 'ai_history_dock');
    });
  });
}
