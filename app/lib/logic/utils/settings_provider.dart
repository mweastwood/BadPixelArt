import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

enum AiEngine { local, geminiCloud, zhipuCloud }

class SettingsState {
  final AiEngine aiEngine;
  final String geminiApiKey;
  final String zhipuApiKey;
  final String geminiModel;
  final String zhipuModel;
  final double throttlePercentage;

  SettingsState({
    required this.aiEngine,
    required this.geminiApiKey,
    required this.zhipuApiKey,
    required this.geminiModel,
    required this.zhipuModel,
    required this.throttlePercentage,
  });

  SettingsState copyWith({
    AiEngine? aiEngine,
    String? geminiApiKey,
    String? zhipuApiKey,
    String? geminiModel,
    String? zhipuModel,
    double? throttlePercentage,
  }) {
    return SettingsState(
      aiEngine: aiEngine ?? this.aiEngine,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      zhipuApiKey: zhipuApiKey ?? this.zhipuApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      zhipuModel: zhipuModel ?? this.zhipuModel,
      throttlePercentage: throttlePercentage ?? this.throttlePercentage,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
    : super(
        SettingsState(
          aiEngine: AiEngine.values[_prefs.getInt('aiEngine') ?? 0],
          geminiApiKey: _prefs.getString('geminiApiKey') ?? '',
          zhipuApiKey: _prefs.getString('zhipuApiKey') ?? '',
          geminiModel: _prefs.getString('geminiModel') ?? 'gemini-3.5-flash',
          zhipuModel: _prefs.getString('zhipuModel') ?? 'glm-4.7-flash',
          throttlePercentage: _prefs.getDouble('throttlePercentage') ?? 100.0,
        ),
      );

  Future<void> setAiEngine(AiEngine engine) async {
    await _prefs.setInt('aiEngine', engine.index);
    state = state.copyWith(aiEngine: engine);
  }

  Future<void> setGeminiApiKey(String key) async {
    await _prefs.setString('geminiApiKey', key);
    state = state.copyWith(geminiApiKey: key);
  }

  Future<void> setZhipuApiKey(String key) async {
    await _prefs.setString('zhipuApiKey', key);
    state = state.copyWith(zhipuApiKey: key);
  }

  Future<void> setGeminiModel(String model) async {
    await _prefs.setString('geminiModel', model);
    state = state.copyWith(geminiModel: model);
  }

  Future<void> setZhipuModel(String model) async {
    await _prefs.setString('zhipuModel', model);
    state = state.copyWith(zhipuModel: model);
  }

  Future<void> setThrottlePercentage(double value) async {
    await _prefs.setDouble('throttlePercentage', value);
    state = state.copyWith(throttlePercentage: value);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main');
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SettingsNotifier(prefs);
  },
  dependencies: [sharedPreferencesProvider],
);

class ZhipuCloudAiService extends CloudAiService {
  ZhipuCloudAiService({
    required super.baseUrl,
    required super.apiKey,
    required super.modelName,
    super.throttlePercentage,
  });

  @override
  Future<AiResponse?> generateContentRaw({
    required String prompt,
    Uint8List? imageBytes,
    double temperature = 1.0,
    int? maxOutputTokens,
  }) async {
    final isVisionModel =
        modelName.contains('v') || modelName.contains('vision');
    final effectiveImageBytes = isVisionModel ? imageBytes : null;
    return super.generateContentRaw(
      prompt: prompt,
      imageBytes: effectiveImageBytes,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
    );
  }
}

final appAiServiceProvider = Provider<AiService>((ref) {
  final settings = ref.watch(settingsProvider);
  switch (settings.aiEngine) {
    case AiEngine.local:
      return getAiService();
    case AiEngine.geminiCloud:
      return CloudAiService(
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: settings.geminiApiKey,
        modelName: settings.geminiModel,
        throttlePercentage: settings.throttlePercentage,
      );
    case AiEngine.zhipuCloud:
      return ZhipuCloudAiService(
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        apiKey: settings.zhipuApiKey,
        modelName: settings.zhipuModel,
        throttlePercentage: settings.throttlePercentage,
      );
  }
}, dependencies: [settingsProvider]);
