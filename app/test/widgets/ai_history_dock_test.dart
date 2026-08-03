import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
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

void main() {
  group('AiHistoryDock Widget & Golden Tests', () {
    testWidgets('shows empty state directly when no logs', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: AiHistoryDock())),
      );

      expect(find.textContaining('No AI history logs yet.'), findsOneWidget);
    });

    testWidgets('renders chat messages, model name, and token statistics', (
      tester,
    ) async {
      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 26, 11, 57, 30),
        prompt: 'Draw a red sword',
        response: 'Adding sword blade pixels',
        isError: false,
        modelName: 'Gemini 2.0 Flash',
        inputTokens: 45,
        outputTokens: 120,
        totalTokens: 165,
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

      final widget = buildTestableWidget(
        child: const Scaffold(body: AiHistoryDock()),
        overrides: [
          aiServiceProvider.overrideWithValue(mockService),
          canvasStateProvider.overrideWith((ref) => notifier),
        ],
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Verify User prompt and AI response text
      expect(find.text('Draw a red sword'), findsOneWidget);
      expect(find.text('Adding sword blade pixels'), findsOneWidget);

      // Verify Model name header
      expect(find.text('Gemini 2.0 Flash'), findsOneWidget);

      // Verify User input token badge
      expect(find.text('45 tokens'), findsOneWidget);

      // Verify AI response token badge (N tokens (M total) • cost)
      expect(find.text('120 tokens (165 total) • \$0.0025'), findsOneWidget);

      // Verify timestamp
      expect(find.textContaining('2026-07-26 11:57:30'), findsNWidgets(2));
    });

    testGoldens('AiHistoryDock renders correctly', (tester) async {
      final entry = AgentHistoryEntry(
        timestamp: DateTime(2026, 7, 26, 11, 57, 30),
        prompt: 'Draw a red sword',
        response: 'Adding sword blade pixels',
        isError: false,
        modelName: 'Gemini 2.0 Flash',
        inputTokens: 45,
        outputTokens: 120,
        totalTokens: 165,
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

    testWidgets(
      'renders active pending query with spinner and italicized status',
      (tester) async {
        final pendingEntry = AgentHistoryEntry(
          timestamp: DateTime(2026, 8, 2, 17, 30, 0),
          prompt: 'Decompose prompt: dragon',
          response: 'Generating response...',
          isError: false,
          modelName: 'Gemini 2.0 Flash',
        );

        final mockService = LocalMockAiService();
        final notifier = CanvasNotifier(mockService);
        notifier.state = notifier.state.copyWith(aiHistory: [pendingEntry]);

        final widget = buildTestableWidget(
          child: const Scaffold(body: AiHistoryDock()),
          overrides: [
            aiServiceProvider.overrideWithValue(mockService),
            canvasStateProvider.overrideWith((ref) => notifier),
          ],
        );

        await tester.pumpWidget(widget);
        await tester.pump();

        // Verify User prompt is displayed
        expect(find.text('Decompose prompt: dragon'), findsOneWidget);

        // Verify Pending text and CircularProgressIndicator spinner
        expect(find.text('Generating response...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );
  });
}
