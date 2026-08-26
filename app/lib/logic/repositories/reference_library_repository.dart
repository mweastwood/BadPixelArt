import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/bmp_utils.dart';
import '../utils/database.dart';

final referenceLibraryRepositoryProvider = Provider<ReferenceLibraryRepository>(
  (ref) {
    return ReferenceLibraryRepository();
  },
);

class ReferenceLibraryRepository {
  final AppDatabase Function() _getDb;

  ReferenceLibraryRepository({AppDatabase Function()? dbGetter})
    : _getDb = dbGetter ?? (() => AppDatabaseHelper.db);

  AppDatabase get _db => _getDb();

  /// Retrieves all reference images ordered by last updated descending.
  Future<List<ReferenceImage>> getAllReferenceImages() async {
    return await _db.getAllReferenceImages();
  }

  /// Streams all reference images ordered by last updated descending.
  Stream<List<ReferenceImage>> watchAllReferenceImages() {
    return _db.watchAllReferenceImages();
  }

  /// Retrieves a specific reference image by ID.
  Future<ReferenceImage?> getReferenceImageById(int id) async {
    return await _db.getReferenceImageById(id);
  }

  /// Adds a new reference image to the library.
  /// Automatically generates 512x512 BMP data if not provided.
  Future<ReferenceImage> addReferenceImage({
    required Uint8List imageBytes,
    Uint8List? bmpBytes,
    String? title,
    String? prompt,
    String source = 'upload',
  }) async {
    final now = DateTime.now();
    final effectiveBmp =
        bmpBytes ?? await resizeAndConvertToBmp(imageBytes, 512);

    String defaultTitle;
    if (title != null && title.trim().isNotEmpty) {
      defaultTitle = title.trim();
    } else if (source == 'gemini') {
      defaultTitle =
          'Gemini Reference (${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')})';
    } else {
      defaultTitle =
          'Reference (${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')})';
    }

    final companion = ReferenceImagesCompanion(
      title: drift.Value(defaultTitle),
      imageData: drift.Value(imageBytes),
      bmpData: drift.Value(effectiveBmp ?? imageBytes),
      prompt: drift.Value(prompt?.trim()),
      source: drift.Value(source),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    );

    final id = await _db.createReferenceImage(companion);
    final item = await _db.getReferenceImageById(id);
    if (item == null) {
      throw StateError('Failed to fetch newly created reference image ID: $id');
    }
    return item;
  }

  /// Deletes a reference image by ID.
  Future<void> deleteReferenceImage(int id) async {
    await _db.deleteReferenceImage(id);
  }

  /// Updates the title and prompt of an existing reference image.
  Future<void> updateReferenceImageDetails({
    required int id,
    required String title,
    String? prompt,
  }) async {
    final existing = await _db.getReferenceImageById(id);
    if (existing == null) return;

    final now = DateTime.now();
    final companion = ReferenceImagesCompanion(
      id: drift.Value(id),
      title: drift.Value(title.trim().isEmpty ? existing.title : title.trim()),
      imageData: drift.Value(existing.imageData),
      bmpData: drift.Value(existing.bmpData),
      prompt: drift.Value(prompt?.trim()),
      source: drift.Value(existing.source),
      createdAt: drift.Value(existing.createdAt),
      updatedAt: drift.Value(now),
    );

    await _db.updateReferenceImage(companion);
  }
}
