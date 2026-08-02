import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/utils/logging_ai_service.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';

class _FakeAiService implements AiService {
  final Completer<AiResponse?> completer = Completer<AiResponse?>();

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
  Future<int> countTokens({
    required String prompt,
    Uint8List? imageBytes,
  }) async => 0;

  @override
  Future<AiResponse?> generateContentRaw({
    required String prompt,
    double temperature = 1.0,
    int? maxOutputTokens,
    dynamic imageBytes,
  }) async {
    return completer.future;
  }

  @override
  Future<String?> generateContent({
    required String prompt,
    double temperature = 1.0,
    int? maxOutputTokens,
    dynamic imageBytes,
  }) async {
    final res = await generateContentRaw(
      prompt: prompt,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
      imageBytes: imageBytes,
    );
    return res?.text;
  }
}

void main() {
  group('LoggingAiService Real-Time Pending & Update Tests', () {
    test(
      'emits pending entry immediately and updates when AI completes',
      () async {
        final fakeService = _FakeAiService();
        final loggingService = LoggingAiService(
          fakeService,
          modelName: 'test-model',
        );

        final loggedEntries = <AgentHistoryEntry>[];
        final updatedEntries = <Map<String, AgentHistoryEntry>>[];

        loggingService.onLog = (entry) => loggedEntries.add(entry);
        loggingService.onLogUpdate = (oldEntry, newEntry) {
          updatedEntries.add({'old': oldEntry, 'new': newEntry});
        };

        // Launch query in background
        final future = loggingService.generateContentRaw(prompt: 'Hello AI');

        // Assert pending entry was emitted immediately before AI response completes
        expect(loggedEntries.length, equals(1));
        expect(loggedEntries.first.prompt, equals('Hello AI'));
        expect(loggedEntries.first.response, equals('Generating response...'));
        expect(updatedEntries, isEmpty);

        // Complete AI call
        fakeService.completer.complete(
          AiResponse(
            text: 'AI Result',
            inputTokens: 10,
            outputTokens: 5,
            totalTokens: 15,
            estimatedCostUsd: 0.001,
          ),
        );

        final response = await future;
        expect(response?.text, equals('AI Result'));

        // Assert entry was updated with actual AI result
        expect(updatedEntries.length, equals(1));
        expect(updatedEntries.first['old'], equals(loggedEntries.first));
        expect(updatedEntries.first['new']!.response, equals('AI Result'));
        expect(updatedEntries.first['new']!.inputTokens, equals(10));
      },
    );

    test('CanvasNotifier updates aiHistory state in real time', () async {
      final fakeService = _FakeAiService();
      final loggingService = LoggingAiService(
        fakeService,
        modelName: 'test-model',
      );
      final notifier = CanvasNotifier(loggingService);

      // Launch query
      final future = loggingService.generateContentRaw(prompt: 'Paint a cat');

      // Verify pending entry is in aiHistory
      expect(notifier.state.aiHistory.length, equals(1));
      expect(
        notifier.state.aiHistory.first.response,
        equals('Generating response...'),
      );

      // Complete AI response
      fakeService.completer.complete(
        AiResponse(
          text: 'Cat painted',
          inputTokens: 20,
          outputTokens: 10,
          totalTokens: 30,
        ),
      );

      await future;

      // Verify aiHistory updated in place
      expect(notifier.state.aiHistory.length, equals(1));
      expect(notifier.state.aiHistory.first.response, equals('Cat painted'));
    });
  });
}
