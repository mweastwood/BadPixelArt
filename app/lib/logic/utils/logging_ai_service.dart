import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

import 'settings_provider.dart';

class LoggingAiService implements AiService {
  final AiService _delegate;
  final String? modelName;
  void Function(AgentHistoryEntry entry)? onLog;
  void Function(AgentHistoryEntry oldEntry, AgentHistoryEntry newEntry)?
  onLogUpdate;

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
    final startTime = DateTime.now();
    final pendingEntry = AgentHistoryEntry(
      timestamp: startTime,
      prompt: prompt,
      response: 'Generating response...',
      isError: false,
      imageBytes: imageBytes,
      modelName: modelName,
    );

    // Emit initial pending entry immediately so UI displays active query
    onLog?.call(pendingEntry);

    try {
      final response = await _delegate.generateContentRaw(
        prompt: prompt,
        imageBytes: imageBytes,
        temperature: temperature,
        maxOutputTokens: maxOutputTokens,
      );

      final responseText = response?.text ?? '';
      final isErrorResponse =
          response == null ||
          responseText.trim().startsWith('{"error":') ||
          responseText.trim().startsWith('{"error" :') ||
          responseText.trim().startsWith('{"error\n');

      final completedEntry = AgentHistoryEntry(
        timestamp: startTime,
        prompt: prompt,
        response: responseText,
        isError: isErrorResponse,
        imageBytes: imageBytes,
        modelName: modelName,
        inputTokens: response?.inputTokens,
        outputTokens: response?.outputTokens,
        totalTokens: response?.totalTokens,
        estimatedCostUsd: response?.estimatedCostUsd,
      );

      if (onLogUpdate != null) {
        onLogUpdate!(pendingEntry, completedEntry);
      } else {
        onLog?.call(completedEntry);
      }

      return response;
    } catch (e) {
      final errorEntry = AgentHistoryEntry(
        timestamp: startTime,
        prompt: prompt,
        response: e.toString(),
        isError: true,
        imageBytes: imageBytes,
        modelName: modelName,
      );

      if (onLogUpdate != null) {
        onLogUpdate!(pendingEntry, errorEntry);
      } else {
        onLog?.call(errorEntry);
      }
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
