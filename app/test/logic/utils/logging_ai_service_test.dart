import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/utils/logging_ai_service.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';

import '../../test_helper.dart';

void main() {
  group('LoggingAiService Real-Time Pending & Update Tests', () {
    test(
      'emits pending entry immediately and updates when AI completes',
      () async {
        final fakeService = TestMockAiService(
          completer: Completer<AiResponse?>(),
        );
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
        fakeService.completer!.complete(
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

    test(
      'updates entry with isError: true when AI call throws exception',
      () async {
        final fakeService = TestMockAiService(shouldThrow: true);
        final loggingService = LoggingAiService(
          fakeService,
          modelName: 'test-model',
        );
        final notifier = CanvasNotifier(loggingService);

        // Launch failing query
        await expectLater(
          loggingService.generateContentRaw(prompt: 'Failing call'),
          throwsA(isA<Exception>()),
        );

        // Verify pending entry turned into error entry in state.aiHistory
        expect(notifier.state.aiHistory.length, equals(1));
        expect(notifier.state.aiHistory.first.isError, isTrue);
        expect(
          notifier.state.aiHistory.first.response,
          contains('API quota exceeded'),
        );
      },
    );

    test('falls back to onLog when onLogUpdate is null', () async {
      final fakeService = TestMockAiService(
        completer: Completer<AiResponse?>(),
      );
      final loggingService = LoggingAiService(fakeService);

      final loggedEntries = <AgentHistoryEntry>[];
      loggingService.onLog = (entry) => loggedEntries.add(entry);

      final future = loggingService.generateContentRaw(prompt: 'Fallback test');
      expect(loggedEntries.length, equals(1));
      expect(loggedEntries.first.response, equals('Generating response...'));

      fakeService.completer!.complete(AiResponse(text: 'Done fallback'));
      await future;

      expect(loggedEntries.length, equals(2));
      expect(loggedEntries.last.response, equals('Done fallback'));
    });

    test('CanvasNotifier updates aiHistory state in real time', () async {
      final fakeService = TestMockAiService(
        completer: Completer<AiResponse?>(),
      );
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
      fakeService.completer!.complete(
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

    test('updateAiService re-wires onLog and onLogUpdate callbacks', () async {
      final fakeService1 = TestMockAiService(
        completer: Completer<AiResponse?>(),
      );
      final logging1 = LoggingAiService(fakeService1);
      final notifier = CanvasNotifier(logging1);

      final fakeService2 = TestMockAiService(
        completer: Completer<AiResponse?>(),
      );
      final logging2 = LoggingAiService(fakeService2);

      notifier.updateAiService(logging2);

      final future = logging2.generateContentRaw(prompt: 'New service call');
      expect(notifier.state.aiHistory.length, equals(1));
      expect(notifier.state.aiHistory.first.prompt, equals('New service call'));

      fakeService2.completer!.complete(AiResponse(text: 'New response'));
      await future;

      expect(notifier.state.aiHistory.length, equals(1));
      expect(notifier.state.aiHistory.first.response, equals('New response'));
    });

    test(
      'updates entry with isError: true when response text is error JSON',
      () async {
        final fakeService = TestMockAiService(
          completer: Completer<AiResponse?>(),
        );
        final loggingService = LoggingAiService(
          fakeService,
          modelName: 'test-model',
        );
        final notifier = CanvasNotifier(loggingService);

        final future = loggingService.generateContentRaw(prompt: 'Trigger 503');
        fakeService.completer!.complete(
          AiResponse(text: '{"error": "Server returned code 503"}'),
        );
        await future;

        expect(notifier.state.aiHistory.length, equals(1));
        expect(notifier.state.aiHistory.first.isError, isTrue);
        expect(
          notifier.state.aiHistory.first.response,
          equals('{"error": "Server returned code 503"}'),
        );
      },
    );

    test(
      'updates entry with isError: true for formatted and markdown code-fenced error JSON variations',
      () async {
        final variations = [
          '{ "error": "Spaced error format" }',
          '{\n  "error": "Multiline error format"\n}',
          '```json\n{\n  "error": "Markdown fenced error"\n}\n```',
          '  { \n "error" : "Indented and colon spaced" }  ',
        ];

        for (final errorText in variations) {
          final fakeService = TestMockAiService(
            completer: Completer<AiResponse?>(),
          );
          final loggingService = LoggingAiService(
            fakeService,
            modelName: 'test-model',
          );
          final notifier = CanvasNotifier(loggingService);

          final future = loggingService.generateContentRaw(
            prompt: 'Test error format',
          );
          fakeService.completer!.complete(AiResponse(text: errorText));
          await future;

          expect(notifier.state.aiHistory.length, equals(1));
          expect(notifier.state.aiHistory.first.isError, isTrue);
          expect(notifier.state.aiHistory.first.response, equals(errorText));
        }
      },
    );

    test(
      'updates entry with isError: false when response is valid non-error JSON',
      () async {
        final fakeService = TestMockAiService(
          completer: Completer<AiResponse?>(),
        );
        final loggingService = LoggingAiService(
          fakeService,
          modelName: 'test-model',
        );
        final notifier = CanvasNotifier(loggingService);

        final future = loggingService.generateContentRaw(prompt: 'Draw circle');
        fakeService.completer!.complete(
          AiResponse(text: '{"tool": "circle_filled", "params": [5, 5, 2]}'),
        );
        await future;

        expect(notifier.state.aiHistory.length, equals(1));
        expect(notifier.state.aiHistory.first.isError, isFalse);
      },
    );
  });
}
