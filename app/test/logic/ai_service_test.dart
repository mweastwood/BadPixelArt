import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bad_pixel_art/logic/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mweastwood.bad_pixel_art/aicore');

  group('MockAiService Tests', () {
    late MockAiService mockAiService;

    setUp(() {
      mockAiService = MockAiService();
    });

    test(
      'checkStatus returns correct status and setMockStatus updates it',
      () async {
        expect(
          await mockAiService.checkStatus(),
          equals(AiCoreStatus.available),
        );
        mockAiService.setMockStatus(AiCoreStatus.downloadable);
        expect(
          await mockAiService.checkStatus(),
          equals(AiCoreStatus.downloadable),
        );
      },
    );

    test('triggerDownload transitions status appropriately', () async {
      mockAiService.setMockStatus(AiCoreStatus.downloadable);
      await mockAiService.triggerDownload();
      expect(
        await mockAiService.checkStatus(),
        equals(AiCoreStatus.downloading),
      );

      // Wait for mock delay to finish transition to available
      await Future.delayed(const Duration(seconds: 2, milliseconds: 100));
      expect(await mockAiService.checkStatus(), equals(AiCoreStatus.available));
    });

    test(
      'generateContent lowTemperature suggestions are formatted correctly',
      () async {
        final response = await mockAiService.generateContent(
          prompt: 'suggest palette',
          lowTemperature: true,
        );
        expect(response, isNotNull);
        final decoded = jsonDecode(response!);
        expect(decoded, isA<List>());
        expect(decoded.length, equals(16));
        expect(decoded[0], startsWith('#'));
      },
    );

    test('generateContent cyclic stroke suggestions are valid JSON', () async {
      // Stroke 1
      final res1 = await mockAiService.generateContent(
        prompt: 'draw',
        lowTemperature: false,
      );
      expect(res1, isNotNull);
      final map1 = jsonDecode(res1!);
      expect(map1['tool'], equals('line'));

      // Stroke 2
      final res2 = await mockAiService.generateContent(
        prompt: 'draw',
        lowTemperature: false,
      );
      expect(res2, isNotNull);
      final map2 = jsonDecode(res2!);
      expect(map2['tool'], equals('fill'));

      // Stroke 3
      final res3 = await mockAiService.generateContent(
        prompt: 'draw',
        lowTemperature: false,
      );
      expect(res3, isNotNull);
      final map3 = jsonDecode(res3!);
      expect(map3['tool'], equals('hatch'));

      // Stroke 4 (wrap around)
      final res4 = await mockAiService.generateContent(
        prompt: 'draw',
        lowTemperature: false,
      );
      expect(res4, isNotNull);
      final map4 = jsonDecode(res4!);
      expect(map4['tool'], equals('circle'));
    });
    group('MethodChannelAiService Tests', () {
      late MethodChannelAiService service;
      final List<MethodCall> log = [];
      dynamic mockResponse;
      int throwCount = 0;

      setUp(() {
        service = MethodChannelAiService();
        log.clear();
        mockResponse = null;
        throwCount = 0;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              log.add(methodCall);
              if (throwCount > 0) {
                throwCount--;
                throw PlatformException(code: 'ERROR', message: 'Failed');
              }
              return mockResponse;
            });
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      test('checkStatus maps values correctly', () async {
        mockResponse = 'available';
        expect(await service.checkStatus(), equals(AiCoreStatus.available));

        mockResponse = 'downloadable';
        expect(await service.checkStatus(), equals(AiCoreStatus.downloadable));

        mockResponse = 'downloading';
        expect(await service.checkStatus(), equals(AiCoreStatus.downloading));

        mockResponse = 'unavailable';
        expect(await service.checkStatus(), equals(AiCoreStatus.unavailable));

        mockResponse = null;
        expect(await service.checkStatus(), equals(AiCoreStatus.unavailable));
      });

      test('triggerDownload invokes native triggerDownload', () async {
        await service.triggerDownload();
        expect(log.length, equals(1));
        expect(log.first.method, equals('triggerDownload'));
      });

      test(
        'generateContent maps parameters correctly when lowTemperature is false',
        () async {
          mockResponse = '{"tool": "circle"}';
          final imageBytes = Uint8List.fromList([1, 2, 3]);

          final result = await service.generateContent(
            prompt: 'draw something',
            imageBytes: imageBytes,
            lowTemperature: false,
          );

          expect(result, equals('{"tool": "circle"}'));
          expect(log.length, equals(1));
          expect(log.first.method, equals('getNextStroke'));
          expect(log.first.arguments['prompt'], equals('draw something'));
          expect(log.first.arguments['canvasImage'], equals(imageBytes));
        },
      );

      test(
        'generateContent maps parameters correctly when lowTemperature is true',
        () async {
          mockResponse = '["#ff0000"]';
          final imageBytes = Uint8List.fromList([4, 5, 6]);

          final result = await service.generateContent(
            prompt: 'suggest palette',
            imageBytes: imageBytes,
            lowTemperature: true,
          );

          expect(result, equals('["#ff0000"]'));
          expect(log.length, equals(1));
          expect(log.first.method, equals('suggestPalette'));
          expect(log.first.arguments['prompt'], equals('suggest palette'));
          expect(log.first.arguments['referenceImage'], equals(imageBytes));
        },
      );

      test('generateContent retries on exception and succeeds', () async {
        throwCount = 2; // Fail twice, then succeed
        mockResponse = '{"tool": "fill"}';

        final result = await service.generateContent(
          prompt: 'retry me',
          lowTemperature: false,
        );

        expect(result, equals('{"tool": "fill"}'));
        expect(log.length, equals(3)); // 2 fails + 1 success
        expect(log[0].method, equals('getNextStroke'));
        expect(log[1].method, equals('getNextStroke'));
        expect(log[2].method, equals('getNextStroke'));
      });

      test(
        'generateContent returns error JSON after exhausting retries',
        () async {
          throwCount = 4; // Fail all 4 attempts

          final result = await service.generateContent(
            prompt: 'always fails',
            lowTemperature: false,
          );

          expect(result, contains('error'));
          expect(log.length, equals(4));
        },
      );
    });
  });
}
