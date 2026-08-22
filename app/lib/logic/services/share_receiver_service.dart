import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../canvas_state.dart';
import '../repositories/reference_library_repository.dart';
import '../utils/database.dart';

class SharedMediaItem {
  final Uint8List bytes;
  final String? text;
  final String? subject;
  final String? mimeType;

  const SharedMediaItem({
    required this.bytes,
    this.text,
    this.subject,
    this.mimeType,
  });

  factory SharedMediaItem.fromMap(Map<dynamic, dynamic> map) {
    final rawBytes = map['bytes'];
    final Uint8List bytes = rawBytes is Uint8List
        ? rawBytes
        : Uint8List.fromList(List<int>.from(rawBytes as List));

    return SharedMediaItem(
      bytes: bytes,
      text: map['text'] as String?,
      subject: map['subject'] as String?,
      mimeType: map['mimeType'] as String?,
    );
  }
}

final shareReceiverServiceProvider = Provider<ShareReceiverService>((ref) {
  final service = ShareReceiverService(
    ref.read(referenceLibraryRepositoryProvider),
    () => ref.read(canvasStateProvider.notifier),
  );
  ref.onDispose(() => service.dispose());
  return service;
});

class ShareReceiverService {
  static const MethodChannel _channel = MethodChannel(
    'com.mweastwood.bad_pixel_art/share_receiver',
  );

  final ReferenceLibraryRepository _repository;
  final CanvasNotifier Function() _getCanvasNotifier;
  final StreamController<ReferenceImage> _sharedImageController =
      StreamController<ReferenceImage>.broadcast();

  Stream<ReferenceImage> get onSharedImageImported =>
      _sharedImageController.stream;

  bool _isInitialized = false;

  ShareReceiverService(this._repository, this._getCanvasNotifier);

  void initialize({void Function(ReferenceImage importedImage)? onImported}) {
    if (_isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedDataReceived') {
        final rawList = call.arguments;
        if (rawList is List) {
          for (final rawItem in rawList) {
            if (rawItem is Map) {
              final item = SharedMediaItem.fromMap(rawItem);
              final imported = await handleSharedItem(item);
              if (imported != null) {
                _sharedImageController.add(imported);
                onImported?.call(imported);
              }
            }
          }
        }
      }
    });

    _fetchInitialSharedData(onImported);
  }

  Future<void> _fetchInitialSharedData(
    void Function(ReferenceImage importedImage)? onImported,
  ) async {
    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>(
        'getInitialSharedData',
      );
      if (rawList != null) {
        for (final rawItem in rawList) {
          if (rawItem is Map) {
            final item = SharedMediaItem.fromMap(rawItem);
            final imported = await handleSharedItem(item);
            if (imported != null) {
              _sharedImageController.add(imported);
              onImported?.call(imported);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching initial shared data: $e');
    }
  }

  Future<ReferenceImage?> handleSharedItem(SharedMediaItem item) async {
    try {
      final imageBytes = item.bytes;
      if (imageBytes.isEmpty) return null;

      final now = DateTime.now();
      String? title = item.subject?.trim();
      if (title == null || title.isEmpty) {
        title =
            'Gemini Reference (${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')})';
      }

      final prompt = item.text?.trim();

      // Convert to 512x512 BMP for optimal model processing
      final bmpBytes = await resizeAndConvertToBmp(imageBytes, 512);

      final saved = await _repository.addReferenceImage(
        imageBytes: imageBytes,
        bmpBytes: bmpBytes,
        title: title,
        prompt: prompt,
        source: 'gemini',
      );

      // Automatically set as active reference image on the canvas
      final notifier = _getCanvasNotifier();
      if (bmpBytes != null) {
        notifier.setReferenceImage(bmpBytes, originalBytes: imageBytes);
      } else {
        await notifier.setUploadedReferenceImage(imageBytes);
      }

      // If user shared prompt alongside image, update prompt if currently empty
      if (prompt != null && prompt.isNotEmpty) {
        notifier.updatePrompt(prompt);
      }

      return saved;
    } catch (e) {
      debugPrint('Error processing shared media item: $e');
      return null;
    }
  }

  void dispose() {
    _sharedImageController.close();
  }
}
