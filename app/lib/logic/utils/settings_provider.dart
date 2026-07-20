import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';

enum AiEngine { local, geminiCloud, zhipuCloud }

class SettingsState {
  final AiEngine aiEngine;
  final String geminiApiKey;
  final String zhipuApiKey;

  SettingsState({
    required this.aiEngine,
    required this.geminiApiKey,
    required this.zhipuApiKey,
  });

  SettingsState copyWith({
    AiEngine? aiEngine,
    String? geminiApiKey,
    String? zhipuApiKey,
  }) {
    return SettingsState(
      aiEngine: aiEngine ?? this.aiEngine,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      zhipuApiKey: zhipuApiKey ?? this.zhipuApiKey,
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
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main');
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SettingsNotifier(prefs);
  },
);

final appAiServiceProvider = Provider<AiService>((ref) {
  final settings = ref.watch(settingsProvider);
  switch (settings.aiEngine) {
    case AiEngine.local:
      return getAiService();
    case AiEngine.geminiCloud:
      return CloudAiService(
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: settings.geminiApiKey,
        modelName: 'gemini-1.5-flash',
      );
    case AiEngine.zhipuCloud:
      return CloudAiService(
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        apiKey: settings.zhipuApiKey,
        modelName: 'glm-4-flash',
      );
  }
});
