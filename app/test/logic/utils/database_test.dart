import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:bad_pixel_art/logic/utils/database.dart';
import 'package:bad_pixel_art/logic/utils/database_helpers.dart';
import 'package:bad_pixel_art/logic/models/pixel_art_component.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Database Helper Serialization Tests', () {
    test('grid serialize/deserialize works correctly', () {
      final List<List<int>> original = [
        [0, 1],
        [2, 3],
      ];
      final serialized = serializeGrid(original);
      final deserialized = deserializeGrid(serialized);
      expect(deserialized, equals(original));
    });

    test('palette serialize/deserialize works correctly', () {
      final List<Color> original = [Colors.red, Colors.green, Colors.blue];
      final serialized = serializePalette(original);
      final deserialized = deserializePalette(serialized);
      expect(deserialized.length, equals(original.length));
      expect(deserialized[0].toARGB32(), equals(Colors.red.toARGB32()));
      expect(deserialized[1].toARGB32(), equals(Colors.green.toARGB32()));
      expect(deserialized[2].toARGB32(), equals(Colors.blue.toARGB32()));
    });

    test('components serialize/deserialize works correctly', () {
      final original = [
        PixelArtComponent(
          name: 'testComponent',
          description: 'A test shape',
          relativeBoundingBox: const Rect.fromLTWH(0, 0, 10, 10),
          shapes: [],
        ),
      ];
      final serialized = serializeComponents(original);
      final deserialized = deserializeComponents(serialized);
      expect(deserialized.length, equals(original.length));
      expect(deserialized[0].name, equals('testComponent'));
      expect(
        deserialized[0].relativeBoundingBox,
        equals(const Rect.fromLTWH(0, 0, 10, 10)),
      );
    });
  });

  group('Database CRUD Operations Tests', () {
    test('insert, query, update, delete creations', () async {
      final now = DateTime.now();
      final companion = CreationsCompanion(
        title: const drift.Value('Sword Art'),
        gridSize: const drift.Value(16),
        gridData: const drift.Value('[[0]]'),
        paletteName: const drift.Value('primary'),
        paletteColors: const drift.Value('["#ffffffff"]'),
        decomposedComponents: const drift.Value('[]'),
        aiHistoryLogs: const drift.Value('[]'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      );

      // Insert
      final id = await db.createCreation(companion);
      expect(id, isPositive);

      // Query all
      final all = await db.getAllCreations();
      expect(all.length, equals(1));
      expect(all[0].title, equals('Sword Art'));
      expect(all[0].id, equals(id));

      // Query by ID
      final single = await db.getCreationById(id);
      expect(single, isNotNull);
      expect(single!.title, equals('Sword Art'));

      // Update
      final updateCompanion = companion.copyWith(
        id: drift.Value(id),
        title: const drift.Value('Updated Sword Art'),
      );
      await db.updateCreation(updateCompanion);

      final updated = await db.getCreationById(id);
      expect(updated!.title, equals('Updated Sword Art'));

      // Delete
      await db.deleteCreation(id);
      final deleted = await db.getCreationById(id);
      expect(deleted, isNull);
    });

    test('save and load workspace session', () async {
      final now = DateTime.now();
      final session = WorkspaceSessionsCompanion(
        id: const drift.Value(1),
        activeCreationId: const drift.Value(42),
        selectedColorIndex: const drift.Value(3),
        selectedTool: const drift.Value('circle'),
        userPrompt: const drift.Value('draw a dragon'),
        lastSavedAt: drift.Value(now),
      );

      await db.saveSession(session);

      final loaded = await db.getSession();
      expect(loaded, isNotNull);
      expect(loaded!.activeCreationId, equals(42));
      expect(loaded.selectedColorIndex, equals(3));
      expect(loaded.selectedTool, equals('circle'));
      expect(loaded.userPrompt, equals('draw a dragon'));
    });

    test('insert, query, watch, update, delete reference images', () async {
      final now = DateTime.now();
      final companion = ReferenceImagesCompanion(
        title: const drift.Value('Ref 1'),
        imageData: drift.Value(Uint8List.fromList([1, 2, 3])),
        bmpData: drift.Value(Uint8List.fromList([4, 5, 6])),
        prompt: const drift.Value('a cool reference'),
        source: const drift.Value('upload'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      );

      // Insert
      final id = await db.createReferenceImage(companion);
      expect(id, isPositive);

      // Query all
      final all = await db.getAllReferenceImages();
      expect(all.length, equals(1));
      expect(all[0].id, equals(id));
      expect(all[0].title, equals('Ref 1'));
      expect(all[0].prompt, equals('a cool reference'));

      // Query by ID
      final single = await db.getReferenceImageById(id);
      expect(single, isNotNull);
      expect(single!.title, equals('Ref 1'));

      // Update
      final updateCompanion = companion.copyWith(
        id: drift.Value(id),
        title: const drift.Value('Updated Ref'),
      );
      await db.updateReferenceImage(updateCompanion);

      final updated = await db.getReferenceImageById(id);
      expect(updated!.title, equals('Updated Ref'));

      // Delete
      await db.deleteReferenceImage(id);
      final deleted = await db.getReferenceImageById(id);
      expect(deleted, isNull);
    });
  });

  group('Database Migration Tests', () {
    test('schemaVersion is 2', () {
      expect(db.schemaVersion, equals(2));
    });

    test(
      'migration onUpgrade from version 1 creates reference_images table',
      () async {
        final migrator = db.createMigrator();
        // Should run without throwing errors
        await db.migration.onUpgrade(migrator, 1, 2);

        final companion = ReferenceImagesCompanion(
          title: const drift.Value('Migration Test Ref'),
          imageData: drift.Value(Uint8List.fromList([10, 20])),
          createdAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        );
        final id = await db.createReferenceImage(companion);
        expect(id, isPositive);
      },
    );
  });

  group('AppDatabaseHelper Isolation & Reset Tests', () {
    test('first test inserts data into AppDatabaseHelper.db', () async {
      final now = DateTime.now();
      final companion = CreationsCompanion(
        title: const drift.Value('Isolated Sword'),
        gridSize: const drift.Value(16),
        gridData: const drift.Value('[[1]]'),
        paletteName: const drift.Value('primary'),
        paletteColors: const drift.Value('["#ffffffff"]'),
        decomposedComponents: const drift.Value('[]'),
        aiHistoryLogs: const drift.Value('[]'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      );
      await AppDatabaseHelper.db.createCreation(companion);
      final creations = await AppDatabaseHelper.db.getAllCreations();
      expect(creations.length, equals(1));
      expect(creations.first.title, equals('Isolated Sword'));
    });

    test(
      'second test confirms clean database isolation with no leaked state',
      () async {
        final creations = await AppDatabaseHelper.db.getAllCreations();
        expect(creations, isEmpty);
      },
    );

    test('reset closes database and clears instance without error', () async {
      final currentDb = AppDatabaseHelper.db;
      expect(currentDb, isNotNull);
      await AppDatabaseHelper.reset();
      final newDb = AppDatabaseHelper.db;
      expect(newDb, isNot(same(currentDb)));
    });
  });
}
