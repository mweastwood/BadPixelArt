import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_agent/local_agent.dart';

class LoggingAiService implements AiService {
  final AiService _delegate;
  void Function(AgentHistoryEntry entry)? onLog;

  LoggingAiService(this._delegate);

  @override
  Future<AiCoreStatus> checkStatus() => _delegate.checkStatus();

  @override
  Future<void> triggerDownload() => _delegate.triggerDownload();

  @override
  Future<void> setModelConfig({
    required String releaseStage,
    required String preference,
  }) => _delegate.setModelConfig(
    releaseStage: releaseStage,
    preference: preference,
  );

  @override
  Future<AiResponse?> generateContentRaw({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    try {
      final response = await _delegate.generateContentRaw(
        prompt: prompt,
        imageBytes: imageBytes,
        temperature: temperature,
        maxOutputTokens: maxOutputTokens,
      );

      onLog?.call(
        AgentHistoryEntry(
          timestamp: DateTime.now(),
          prompt: prompt,
          response: response?.text ?? '',
          isError: response == null,
          imageBytes: imageBytes,
        ),
      );
      return response;
    } catch (e) {
      onLog?.call(
        AgentHistoryEntry(
          timestamp: DateTime.now(),
          prompt: prompt,
          response: e.toString(),
          isError: true,
          imageBytes: imageBytes,
        ),
      );
      rethrow;
    }
  }

  @override
  Future<String?> generateContent({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    final res = await generateContentRaw(
      prompt: prompt,
      imageBytes: imageBytes,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
    );
    return res?.text;
  }

  @override
  Future<int> countTokens({required String prompt, Uint8List? imageBytes}) =>
      _delegate.countTokens(prompt: prompt, imageBytes: imageBytes);
}

final loggingAiServiceProvider = Provider<AiService>((ref) {
  final baseService = ref.watch(aiServiceProvider);
  return LoggingAiService(baseService);
});
