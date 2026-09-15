import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:bad_pixel_art/logic/utils/bmp_utils.dart';
import 'package:bad_pixel_art/logic/utils/settings_provider.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) _handler;

  MockHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is! http.Request) {
      throw UnsupportedError('Expected http.Request');
    }
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

http.Response mockJsonResponse(
  Map<String, dynamic> data, {
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(data),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, dynamic> openAiChatResponse(String content) {
  return {
    'id': 'chatcmpl-test-123',
    'object': 'chat.completion',
    'created': 1700000000,
    'model': 'glm-4v-flash',
    'choices': [
      {
        'index': 0,
        'message': {'role': 'assistant', 'content': content},
        'finish_reason': 'stop',
      },
    ],
    'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'total_tokens': 15},
  };
}

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
  });

  group('SettingsState.activeModelName', () {
    test('returns "Local AI Model" when aiEngine is AiEngine.local', () {
      final state = SettingsState(
        aiEngine: AiEngine.local,
        geminiApiKey: 'key',
        zhipuApiKey: 'key',
        geminiModel: 'custom-gemini',
        zhipuModel: 'custom-zhipu',
        throttlePercentage: 100.0,
      );
      expect(state.activeModelName, equals('Local AI Model'));
    });

    test(
      'returns configured geminiModel or falls back to "Gemini 2.0 Flash" for AiEngine.geminiCloud',
      () {
        final configuredState = SettingsState(
          aiEngine: AiEngine.geminiCloud,
          geminiApiKey: 'key',
          zhipuApiKey: 'key',
          geminiModel: 'custom-gemini-model',
          zhipuModel: '',
          throttlePercentage: 100.0,
        );
        expect(configuredState.activeModelName, equals('custom-gemini-model'));

        final fallbackState = SettingsState(
          aiEngine: AiEngine.geminiCloud,
          geminiApiKey: 'key',
          zhipuApiKey: 'key',
          geminiModel: '',
          zhipuModel: '',
          throttlePercentage: 100.0,
        );
        expect(fallbackState.activeModelName, equals('Gemini 2.0 Flash'));
      },
    );

    test(
      'returns configured zhipuModel or falls back to "GLM-4V-Flash" for AiEngine.zhipuCloud',
      () {
        final configuredState = SettingsState(
          aiEngine: AiEngine.zhipuCloud,
          geminiApiKey: 'key',
          zhipuApiKey: 'key',
          geminiModel: '',
          zhipuModel: 'custom-zhipu-model',
          throttlePercentage: 100.0,
        );
        expect(configuredState.activeModelName, equals('custom-zhipu-model'));

        final fallbackState = SettingsState(
          aiEngine: AiEngine.zhipuCloud,
          geminiApiKey: 'key',
          zhipuApiKey: 'key',
          geminiModel: '',
          zhipuModel: '',
          throttlePercentage: 100.0,
        );
        expect(fallbackState.activeModelName, equals('GLM-4V-Flash'));
      },
    );
  });

  group('ZhipuCloudAiService', () {
    test(
      'automatically converts BMP image bytes to PNG for recognized vision model (glm-4v-flash)',
      () async {
        http.Request? capturedRequest;
        final client = MockHttpClient((request) async {
          capturedRequest = request;
          return mockJsonResponse(
            openAiChatResponse('Vision analysis complete'),
          );
        });

        final service = ZhipuCloudAiService(
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          apiKey: 'test-api-key',
          modelName: 'glm-4v-flash',
          httpClient: client,
        );

        final bmpBytes = generateBmp(
          [
            [1, 1],
            [1, 1],
          ],
          [Colors.blue],
        );
        expect(bmpBytes[0], equals(0x42));
        expect(bmpBytes[1], equals(0x4D));

        final response = await service.generateContentRaw(
          prompt: 'Identify the pixel art subject',
          imageBytes: bmpBytes,
        );

        expect(response, isNotNull);
        expect(response?.isError, isFalse);
        expect(response?.text, equals('Vision analysis complete'));

        expect(capturedRequest, isNotNull);
        expect(
          capturedRequest!.url.toString(),
          equals('https://open.bigmodel.cn/api/paas/v4/chat/completions'),
        );
        expect(
          capturedRequest!.headers['Authorization'],
          equals('Bearer test-api-key'),
        );

        final payload =
            jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        expect(payload['model'], equals('glm-4v-flash'));

        final messages = payload['messages'] as List<dynamic>;
        expect(messages.length, equals(1));
        final content = messages[0]['content'] as List<dynamic>;
        expect(content[0]['type'], equals('text'));
        expect(content[0]['text'], equals('Identify the pixel art subject'));
        expect(content[1]['type'], equals('image_url'));

        final imageUrl = content[1]['image_url']['url'] as String;
        expect(imageUrl, startsWith('data:image/png;base64,'));

        final base64String = imageUrl.replaceFirst(
          'data:image/png;base64,',
          '',
        );
        final decodedBytes = base64Decode(base64String);
        expect(decodedBytes[0], equals(0x89));
        expect(decodedBytes[1], equals(0x50)); // 'P'
        expect(decodedBytes[2], equals(0x4E)); // 'N'
        expect(decodedBytes[3], equals(0x47)); // 'G'
      },
    );

    test(
      'recognizes vision model via substring fallback ("v" or "vision") and converts BMP to PNG',
      () async {
        http.Request? capturedRequest;
        final client = MockHttpClient((request) async {
          capturedRequest = request;
          return mockJsonResponse(
            openAiChatResponse('Substring vision response'),
          );
        });

        final service = ZhipuCloudAiService(
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          apiKey: 'test-api-key',
          modelName: 'custom-glm-vision-preview',
          httpClient: client,
        );

        final bmpBytes = generateBmp(
          [
            [1],
          ],
          [Colors.red],
        );

        final response = await service.generateContentRaw(
          prompt: 'Describe image with substring fallback',
          imageBytes: bmpBytes,
        );

        expect(response?.text, equals('Substring vision response'));
        expect(capturedRequest, isNotNull);

        final payload =
            jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        final messages = payload['messages'] as List<dynamic>;
        final content = messages[0]['content'] as List<dynamic>;
        expect(content[1]['type'], equals('image_url'));
        final imageUrl = content[1]['image_url']['url'] as String;
        expect(imageUrl, startsWith('data:image/png;base64,'));
      },
    );

    test(
      'passes through already formatted PNG bytes without modification for vision model',
      () async {
        http.Request? capturedRequest;
        final client = MockHttpClient((request) async {
          capturedRequest = request;
          return mockJsonResponse(openAiChatResponse('PNG passthrough'));
        });

        final service = ZhipuCloudAiService(
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          apiKey: 'test-api-key',
          modelName: 'glm-4v-flash',
          httpClient: client,
        );

        final rawPngBytes = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x00,
          0x00,
        ]);

        final response = await service.generateContentRaw(
          prompt: 'PNG test',
          imageBytes: rawPngBytes,
        );

        expect(response?.text, equals('PNG passthrough'));
        expect(capturedRequest, isNotNull);

        final payload =
            jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        final messages = payload['messages'] as List<dynamic>;
        final content = messages[0]['content'] as List<dynamic>;
        final imageUrl = content[1]['image_url']['url'] as String;
        final base64String = imageUrl.replaceFirst(
          'data:image/png;base64,',
          '',
        );
        expect(base64Decode(base64String), equals(rawPngBytes));
      },
    );

    test(
      'bypasses convertToPngBytes and strips imageBytes for non-vision model (e.g. glm-4.7-flash)',
      () async {
        http.Request? capturedRequest;
        final client = MockHttpClient((request) async {
          capturedRequest = request;
          return mockJsonResponse(
            openAiChatResponse('Text-only model response'),
          );
        });

        final service = ZhipuCloudAiService(
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          apiKey: 'test-api-key',
          modelName: 'glm-4.7-flash',
          httpClient: client,
        );

        final rawBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final response = await service.generateContentRaw(
          prompt: 'Text prompt with unused image',
          imageBytes: rawBytes,
        );

        expect(response?.text, equals('Text-only model response'));
        expect(capturedRequest, isNotNull);

        final payload =
            jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        expect(payload['model'], equals('glm-4.7-flash'));

        final messages = payload['messages'] as List<dynamic>;
        expect(messages.length, equals(1));
        // For non-vision models, effectiveImageBytes is null, so messages contain plain string content
        expect(messages[0]['content'], equals('Text prompt with unused image'));
      },
    );

    test(
      'bypasses image conversion and sends plain string prompt for custom non-vision model',
      () async {
        http.Request? capturedRequest;
        final client = MockHttpClient((request) async {
          capturedRequest = request;
          return mockJsonResponse(openAiChatResponse('Custom text response'));
        });

        final service = ZhipuCloudAiService(
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          apiKey: 'test-api-key',
          modelName: 'custom-text-only',
          httpClient: client,
        );

        final rawBytes = Uint8List.fromList([10, 20, 30]);
        final response = await service.generateContentRaw(
          prompt: 'Custom text prompt',
          imageBytes: rawBytes,
        );

        expect(response?.text, equals('Custom text response'));
        expect(capturedRequest, isNotNull);

        final payload =
            jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        final messages = payload['messages'] as List<dynamic>;
        expect(messages[0]['content'], equals('Custom text prompt'));
      },
    );

    test(
      'sends simple string prompt without image_url when imageBytes is null or empty',
      () async {
        http.Request? capturedRequest;
        final client = MockHttpClient((request) async {
          capturedRequest = request;
          return mockJsonResponse(openAiChatResponse('Text prompt response'));
        });

        final service = ZhipuCloudAiService(
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          apiKey: 'test-api-key',
          modelName: 'glm-4v-flash',
          httpClient: client,
        );

        // Null imageBytes
        final responseNull = await service.generateContentRaw(
          prompt: 'Null image test',
          imageBytes: null,
        );
        expect(responseNull?.text, equals('Text prompt response'));
        var payload = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        expect(payload['messages'][0]['content'], equals('Null image test'));

        // Empty imageBytes
        final responseEmpty = await service.generateContentRaw(
          prompt: 'Empty image test',
          imageBytes: Uint8List(0),
        );
        expect(responseEmpty?.text, equals('Text prompt response'));
        payload = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        expect(payload['messages'][0]['content'], equals('Empty image test'));
      },
    );

    test(
      'handles API HTTP error gracefully returning error AiResponse',
      () async {
        final client = MockHttpClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {'message': 'Invalid API Key'},
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = ZhipuCloudAiService(
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          apiKey: 'invalid-key',
          modelName: 'glm-4v-flash',
          httpClient: client,
        );

        final response = await service.generateContentRaw(
          prompt: 'Test error handling',
        );

        expect(response, isNotNull);
        expect(response?.isError, isTrue);
      },
    );
  });

  group('appAiServiceProvider switching', () {
    test(
      'instantiates local AiService when aiEngine is AiEngine.local',
      () async {
        SharedPreferences.setMockInitialValues({
          'aiEngine': AiEngine.local.index,
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final service = container.read(appAiServiceProvider);
        expect(service, isA<AiService>());
        expect(service, isNot(isA<CloudAiService>()));
      },
    );

    test(
      'instantiates CloudAiService with correct config when aiEngine is AiEngine.geminiCloud',
      () async {
        SharedPreferences.setMockInitialValues({
          'aiEngine': AiEngine.geminiCloud.index,
          'geminiApiKey': 'gemini_test_key',
          'geminiModel': 'gemini-3.5-flash',
          'throttlePercentage': 80.0,
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final service = container.read(appAiServiceProvider);
        expect(service, isA<CloudAiService>());
        expect(service, isNot(isA<ZhipuCloudAiService>()));

        final cloudService = service as CloudAiService;
        expect(
          cloudService.baseUrl,
          equals('https://generativelanguage.googleapis.com/v1beta/openai'),
        );
        expect(cloudService.apiKey, equals('gemini_test_key'));
        expect(cloudService.modelName, equals('gemini-3.5-flash'));
        expect(cloudService.throttlePercentage, equals(80.0));
      },
    );

    test(
      'instantiates ZhipuCloudAiService with correct config when aiEngine is AiEngine.zhipuCloud',
      () async {
        SharedPreferences.setMockInitialValues({
          'aiEngine': AiEngine.zhipuCloud.index,
          'zhipuApiKey': 'zhipu_test_key',
          'zhipuModel': 'glm-4v-flash',
          'throttlePercentage': 60.0,
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final service = container.read(appAiServiceProvider);
        expect(service, isA<ZhipuCloudAiService>());

        final zhipuService = service as ZhipuCloudAiService;
        expect(
          zhipuService.baseUrl,
          equals('https://open.bigmodel.cn/api/paas/v4'),
        );
        expect(zhipuService.apiKey, equals('zhipu_test_key'));
        expect(zhipuService.modelName, equals('glm-4v-flash'));
        expect(zhipuService.throttlePercentage, equals(60.0));
      },
    );
  });
}
