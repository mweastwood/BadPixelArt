import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import 'settings_provider.dart';

class LoggingAiService implements AiService {
  final AiService _delegate;
  final String? modelName;
  void Function(AgentHistoryEntry entry)? onLog;

  LoggingAiService(this._delegate, {this.modelName});

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
          modelName: modelName,
          inputTokens: response?.inputTokens,
          outputTokens: response?.outputTokens,
          totalTokens: response?.totalTokens,
          estimatedCostUsd: response?.estimatedCostUsd,
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
          modelName: modelName,
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

  String? currentModelName;
  try {
    final settings = ref.read(settingsProvider);
    switch (settings.aiEngine) {
      case AiEngine.geminiCloud:
        currentModelName = settings.geminiModel;
        break;
      case AiEngine.zhipuCloud:
        currentModelName = settings.zhipuModel;
        break;
      case AiEngine.local:
        currentModelName = 'Local Model';
        break;
    }
  } catch (_) {}

  return LoggingAiService(baseService, modelName: currentModelName);
});
