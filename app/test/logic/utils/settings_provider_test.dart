import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/utils/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'aiEngine': 1, // geminiCloud
        'geminiApiKey': 'test_gemini_key',
        'zhipuApiKey': 'test_zhipu_key',
        'geminiModel': 'custom-gemini-model',
        'zhipuModel': 'custom-zhipu-model',
        'throttlePercentage': 50.0,
      });
    });

    test(
      'SettingsNotifier loads correct initial state from SharedPreferences',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final notifier = SettingsNotifier(prefs);

        expect(notifier.state.aiEngine, equals(AiEngine.geminiCloud));
        expect(notifier.state.geminiApiKey, equals('test_gemini_key'));
        expect(notifier.state.zhipuApiKey, equals('test_zhipu_key'));
        expect(notifier.state.geminiModel, equals('custom-gemini-model'));
        expect(notifier.state.zhipuModel, equals('custom-zhipu-model'));
        expect(notifier.state.throttlePercentage, equals(50.0));
      },
    );

    test(
      'SettingsNotifier state changes update SharedPreferences and state',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final notifier = SettingsNotifier(prefs);

        await notifier.setAiEngine(AiEngine.zhipuCloud);
        expect(notifier.state.aiEngine, equals(AiEngine.zhipuCloud));
        expect(prefs.getInt('aiEngine'), equals(AiEngine.zhipuCloud.index));

        await notifier.setGeminiApiKey('new_gemini_key');
        expect(notifier.state.geminiApiKey, equals('new_gemini_key'));
        expect(prefs.getString('geminiApiKey'), equals('new_gemini_key'));

        await notifier.setZhipuApiKey('new_zhipu_key');
        expect(notifier.state.zhipuApiKey, equals('new_zhipu_key'));
        expect(prefs.getString('zhipuApiKey'), equals('new_zhipu_key'));

        await notifier.setGeminiModel('gemini-3.5-pro');
        expect(notifier.state.geminiModel, equals('gemini-3.5-pro'));
        expect(prefs.getString('geminiModel'), equals('gemini-3.5-pro'));

        await notifier.setZhipuModel('glm-4.7-pro');
        expect(notifier.state.zhipuModel, equals('glm-4.7-pro'));
        expect(prefs.getString('zhipuModel'), equals('glm-4.7-pro'));

        await notifier.setThrottlePercentage(75.0);
        expect(notifier.state.throttlePercentage, equals(75.0));
        expect(prefs.getDouble('throttlePercentage'), equals(75.0));
      },
    );

    test(
      'appAiServiceProvider instantiates CloudAiService with correct config',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );

        final service = container.read(appAiServiceProvider);
        expect(service, isA<CloudAiService>());

        final cloudService = service as CloudAiService;
        expect(
          cloudService.baseUrl,
          equals('https://generativelanguage.googleapis.com/v1beta/openai'),
        );
      },
    );
  });
}
