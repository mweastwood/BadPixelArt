import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bad_pixel_art/logic/repositories/reference_library_repository.dart';
import 'package:bad_pixel_art/logic/services/share_receiver_service.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';

import '../../test_helper.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.mweastwood.bad_pixel_art/share_receiver';
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('ShareReceiverService Unit Tests', () {
    late AppDatabase db;
    late ReferenceLibraryRepository repository;
    late CanvasNotifier canvasNotifier;
    late ShareReceiverService service;
    late Uint8List sampleBmp;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      repository = ReferenceLibraryRepository(dbGetter: () => db);
      final aiService = TestMockAiService();
      canvasNotifier = CanvasNotifier(aiService);
      service = ShareReceiverService(repository, () => canvasNotifier);
      sampleBmp = generateBmpFromRgba(
        Uint8List.fromList([255, 0, 0, 255]),
        1,
        1,
      );
    });

    tearDown(() async {
      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        null,
      );
      service.dispose();
      await db.close();
    });

    group('SharedMediaItem', () {
      test(
        'SharedMediaItem parses correctly from map with Uint8List bytes',
        () {
          final sampleBytes = Uint8List.fromList([1, 2, 3]);
          final map = {
            'bytes': sampleBytes,
            'text': 'A fantasy crystal dagger',
            'subject': 'Gemini Generation',
            'mimeType': 'image/png',
          };
          final item = SharedMediaItem.fromMap(map);
          expect(item.bytes, equals(sampleBytes));
          expect(item.text, equals('A fantasy crystal dagger'));
          expect(item.subject, equals('Gemini Generation'));
          expect(item.mimeType, equals('image/png'));
        },
      );

      test(
        'SharedMediaItem parses correctly from map with List<int> bytes',
        () {
          final rawList = [10, 20, 30, 40];
          final map = {
            'bytes': rawList,
            'text': null,
            'subject': null,
            'mimeType': null,
          };
          final item = SharedMediaItem.fromMap(map);
          expect(item.bytes, equals(Uint8List.fromList(rawList)));
          expect(item.text, isNull);
          expect(item.subject, isNull);
          expect(item.mimeType, isNull);
        },
      );
    });

    group('handleSharedItem', () {
      test(
        'saves reference image, sets active canvas image, and sets prompt',
        () async {
          final item = SharedMediaItem(
            bytes: sampleBmp,
            text: 'A red ruby pixel shield',
            subject: '  Ruby Shield  ',
            mimeType: 'image/png',
          );

          final saved = await service.handleSharedItem(item);
          expect(saved, isNotNull);
          expect(saved?.title, equals('Ruby Shield'));
          expect(saved?.prompt, equals('A red ruby pixel shield'));
          expect(saved?.source, equals('gemini'));

          // Check CanvasNotifier state was updated
          expect(canvasNotifier.state.referenceImage, isNotNull);
          expect(
            canvasNotifier.state.originalReferenceImage,
            equals(sampleBmp),
          );
          expect(
            canvasNotifier.state.userPrompt,
            equals('A red ruby pixel shield'),
          );

          // Check DB contains the image
          final inDb = await repository.getAllReferenceImages();
          expect(inDb.length, equals(1));
          expect(inDb.first.title, equals('Ruby Shield'));
        },
      );

      test('generates default title when subject is null or empty', () async {
        final itemNullSubject = SharedMediaItem(
          bytes: sampleBmp,
          text: '',
          subject: null,
        );
        final saved1 = await service.handleSharedItem(itemNullSubject);
        expect(saved1, isNotNull);
        expect(saved1!.title.startsWith('Gemini Reference ('), isTrue);

        final itemEmptySubject = SharedMediaItem(
          bytes: sampleBmp,
          text: '   ',
          subject: '   ',
        );
        final saved2 = await service.handleSharedItem(itemEmptySubject);
        expect(saved2, isNotNull);
        expect(saved2!.title.startsWith('Gemini Reference ('), isTrue);
        // Prompt should remain untouched because text was empty/whitespace
        expect(canvasNotifier.state.userPrompt, equals(''));
      });

      test('returns null on empty bytes', () async {
        final item = SharedMediaItem(bytes: Uint8List(0), text: 'Nothing');
        final result = await service.handleSharedItem(item);
        expect(result, isNull);
        expect(await repository.getAllReferenceImages(), isEmpty);
      });

      test(
        'falls back to setUploadedReferenceImage when image bytes cannot convert to BMP',
        () async {
          final nonBmpBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
          final item = SharedMediaItem(
            bytes: nonBmpBytes,
            subject: 'Raw Non BMP',
          );

          final saved = await service.handleSharedItem(item);
          expect(saved, isNotNull);
          expect(saved?.title, equals('Raw Non BMP'));
          expect(saved?.bmpData, equals(nonBmpBytes));

          final inDb = await repository.getAllReferenceImages();
          expect(inDb.length, equals(1));
          expect(inDb.first.bmpData, equals(nonBmpBytes));
          expect(inDb.first.imageData, equals(nonBmpBytes));
        },
      );

      test('catches exceptions gracefully and returns null', () async {
        final failingService = ShareReceiverService(
          repository,
          () => throw Exception('Notifier failure'),
        );
        final item = SharedMediaItem(bytes: sampleBmp, subject: 'Fail Subject');
        final result = await failingService.handleSharedItem(item);
        expect(result, isNull);
      });
    });

    group('Method Channel Initialization & Idempotency', () {
      test(
        'registers method call handler and fetches initial shared data once',
        () async {
          int getInitialDataCalls = 0;
          messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'getInitialSharedData') {
              getInitialDataCalls++;
              return [
                {
                  'bytes': sampleBmp,
                  'text': 'Initial Item',
                  'subject': 'Initial Subject',
                },
              ];
            }
            return null;
          });

          ReferenceImage? importedCallbackImage;
          service.initialize(onImported: (img) => importedCallbackImage = img);

          // Allow async _fetchInitialSharedData to execute
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(getInitialDataCalls, equals(1));
          expect(importedCallbackImage, isNotNull);
          expect(importedCallbackImage?.title, equals('Initial Subject'));
          expect(canvasNotifier.state.userPrompt, equals('Initial Item'));

          // Calling initialize() again should be a no-op (idempotent)
          service.initialize(onImported: (_) {});
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(getInitialDataCalls, equals(1));
        },
      );

      test(
        'handles null or invalid return from getInitialSharedData gracefully',
        () async {
          messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'getInitialSharedData') {
              return null;
            }
            return null;
          });

          bool callbackCalled = false;
          service.initialize(onImported: (_) => callbackCalled = true);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(callbackCalled, isFalse);
          expect(await repository.getAllReferenceImages(), isEmpty);
        },
      );

      test(
        'handles non-map or empty items in getInitialSharedData gracefully',
        () async {
          messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'getInitialSharedData') {
              return [
                'invalid string entry',
                123,
                {'bytes': Uint8List(0)}, // Empty bytes item returns null
              ];
            }
            return null;
          });

          bool callbackCalled = false;
          service.initialize(onImported: (_) => callbackCalled = true);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(callbackCalled, isFalse);
          expect(await repository.getAllReferenceImages(), isEmpty);
        },
      );

      test(
        'handles PlatformException in getInitialSharedData without crashing',
        () async {
          messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'getInitialSharedData') {
              throw PlatformException(
                code: 'UNAVAILABLE',
                message: 'Channel unavailable on test platform',
              );
            }
            return null;
          });

          expect(() => service.initialize(), returnsNormally);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
      );
    });

    group('Runtime Share Intent Broadcast (onSharedDataReceived)', () {
      test(
        'parses payload, saves to repository, and notifies stream and callback',
        () async {
          messenger.setMockMethodCallHandler(
            const MethodChannel(channelName),
            (MethodCall methodCall) async => null,
          );

          final receivedStreamImages = <ReferenceImage>[];
          final sub = service.onSharedImageImported.listen(
            receivedStreamImages.add,
          );

          ReferenceImage? callbackImage;
          service.initialize(onImported: (img) => callbackImage = img);
          await Future<void>.delayed(const Duration(milliseconds: 20));

          final ByteData message = codec.encodeMethodCall(
            MethodCall('onSharedDataReceived', [
              {
                'bytes': sampleBmp,
                'text': 'Broadcast Prompt',
                'subject': 'Broadcast Art',
              },
            ]),
          );

          await messenger.handlePlatformMessage(
            channelName,
            message,
            (ByteData? reply) {},
          );

          // Allow stream and async handleSharedItem to process
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(callbackImage, isNotNull);
          expect(callbackImage?.title, equals('Broadcast Art'));
          expect(receivedStreamImages.length, equals(1));
          expect(receivedStreamImages.first.title, equals('Broadcast Art'));
          expect(canvasNotifier.state.userPrompt, equals('Broadcast Prompt'));

          await sub.cancel();
        },
      );

      test(
        'ignores non-list arguments or non-matching method names safely',
        () async {
          messenger.setMockMethodCallHandler(
            const MethodChannel(channelName),
            (MethodCall methodCall) async => null,
          );

          int callbackCount = 0;
          service.initialize(onImported: (_) => callbackCount++);
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // 1. Different method name
          final ByteData unknownMethodMsg = codec.encodeMethodCall(
            const MethodCall('otherMethod', []),
          );
          await messenger.handlePlatformMessage(
            channelName,
            unknownMethodMsg,
            (ByteData? reply) {},
          );

          // 2. Non-list arguments
          final ByteData nonListArgsMsg = codec.encodeMethodCall(
            const MethodCall('onSharedDataReceived', 'not a list'),
          );
          await messenger.handlePlatformMessage(
            channelName,
            nonListArgsMsg,
            (ByteData? reply) {},
          );

          // 3. List with non-map or empty items
          final ByteData invalidListMsg = codec.encodeMethodCall(
            MethodCall('onSharedDataReceived', [
              42,
              {'bytes': Uint8List(0)},
            ]),
          );
          await messenger.handlePlatformMessage(
            channelName,
            invalidListMsg,
            (ByteData? reply) {},
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(callbackCount, equals(0));
        },
      );
    });

    group('Disposal & Provider Lifecycle', () {
      test('dispose cleanly closes onSharedImageImported stream', () async {
        final testService = ShareReceiverService(
          repository,
          () => canvasNotifier,
        );
        expect(testService.onSharedImageImported, emitsDone);
        testService.dispose();
      });

      test(
        'shareReceiverServiceProvider initializes and disposes correctly',
        () async {
          final container = ProviderContainer(
            overrides: [
              referenceLibraryRepositoryProvider.overrideWithValue(repository),
              canvasStateProvider.overrideWith((ref) => canvasNotifier),
            ],
          );

          final providerService = container.read(shareReceiverServiceProvider);
          expect(providerService, isA<ShareReceiverService>());

          final saved = await providerService.handleSharedItem(
            SharedMediaItem(bytes: sampleBmp, text: 'Provider Test'),
          );
          expect(saved, isNotNull);
          expect(canvasNotifier.state.userPrompt, equals('Provider Test'));

          expect(() => container.dispose(), returnsNormally);
        },
      );

      test(
        'dispose detaches method call handler and ignores subsequent platform messages',
        () async {
          messenger.setMockMethodCallHandler(
            const MethodChannel(channelName),
            (MethodCall methodCall) async => null,
          );

          final testService = ShareReceiverService(
            repository,
            () => canvasNotifier,
          );
          int callbackCount = 0;
          testService.initialize(onImported: (_) => callbackCount++);
          await Future<void>.delayed(const Duration(milliseconds: 20));

          final ByteData message = codec.encodeMethodCall(
            MethodCall('onSharedDataReceived', [
              {
                'bytes': sampleBmp,
                'text': 'Prompt Before Dispose',
                'subject': 'Art Before Dispose',
              },
            ]),
          );

          await messenger.handlePlatformMessage(
            channelName,
            message,
            (ByteData? reply) {},
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(callbackCount, equals(1));

          // Dispose service; handler must be detached and initialized flag reset
          testService.dispose();

          // Subsequent platform message should be ignored with no callbacks
          await messenger.handlePlatformMessage(
            channelName,
            message,
            (ByteData? reply) {},
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(callbackCount, equals(1));
        },
      );

      test(
        'late-resolving shared items do not throw StateError when service is disposed',
        () async {
          final delayedService = _DelayedShareReceiverService(
            repository,
            () => canvasNotifier,
          );

          messenger.setMockMethodCallHandler(
            const MethodChannel(channelName),
            (MethodCall methodCall) async => null,
          );

          delayedService.initialize();
          await Future<void>.delayed(const Duration(milliseconds: 20));

          final ByteData message = codec.encodeMethodCall(
            MethodCall('onSharedDataReceived', [
              {
                'bytes': sampleBmp,
                'text': 'Late Prompt',
                'subject': 'Late Art',
              },
            ]),
          );

          final platformFuture = messenger.handlePlatformMessage(
            channelName,
            message,
            (ByteData? reply) {},
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Dispose while handleSharedItem is pending
          delayedService.dispose();

          final sampleImage = ReferenceImage(
            id: 99,
            title: 'Late Art',
            imageData: sampleBmp,
            source: 'gemini',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          expect(
            () => delayedService.completer.complete(sampleImage),
            returnsNormally,
          );
          await platformFuture;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
      );

      test(
        'initial shared data resolving after dispose does not throw StateError',
        () async {
          final delayedService = _DelayedShareReceiverService(
            repository,
            () => canvasNotifier,
          );

          messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'getInitialSharedData') {
              return [
                {
                  'bytes': sampleBmp,
                  'text': 'Initial Late Prompt',
                  'subject': 'Initial Late Art',
                },
              ];
            }
            return null;
          });

          delayedService.initialize();
          await Future<void>.delayed(const Duration(milliseconds: 20));

          delayedService.dispose();

          final sampleImage = ReferenceImage(
            id: 100,
            title: 'Initial Late Art',
            imageData: sampleBmp,
            source: 'gemini',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          expect(
            () => delayedService.completer.complete(sampleImage),
            returnsNormally,
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
      );
    });
  });
}

class _DelayedShareReceiverService extends ShareReceiverService {
  final Completer<ReferenceImage?> completer = Completer<ReferenceImage?>();

  _DelayedShareReceiverService(super.repository, super.getCanvasNotifier);

  @override
  Future<ReferenceImage?> handleSharedItem(SharedMediaItem item) =>
      completer.future;
}
