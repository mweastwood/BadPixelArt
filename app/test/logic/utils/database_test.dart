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
      'migration onUpgrade from v1 to v2 creates reference_images and preserves existing data',
      () async {
        final v1Db = _TestV1Database(NativeDatabase.memory());
        final now = DateTime.now();

        // Seed v1 data: an active creation and a workspace session referencing it
        final creationId = await v1Db.createCreation(
          CreationsCompanion(
            title: const drift.Value('V1 Creation'),
            gridSize: const drift.Value(16),
            gridData: const drift.Value('[[1, 2], [3, 4]]'),
            paletteName: const drift.Value('retro'),
            paletteColors: const drift.Value('["#000000", "#ffffff"]'),
            decomposedComponents: const drift.Value('[]'),
            aiHistoryLogs: const drift.Value('[]'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        expect(creationId, isPositive);

        await v1Db.saveSession(
          WorkspaceSessionsCompanion(
            id: const drift.Value(1),
            activeCreationId: drift.Value(creationId),
            selectedColorIndex: const drift.Value(2),
            selectedTool: const drift.Value('pencil'),
            userPrompt: const drift.Value('v1 prompt'),
            lastSavedAt: drift.Value(now),
          ),
        );

        // Verify user_version is 1 and reference_images table does not exist prior to upgrade
        await v1Db.customStatement('PRAGMA user_version = 1;');
        final tablesBefore = await v1Db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='reference_images';",
            )
            .get();
        expect(tablesBefore, isEmpty);

        // Execute migration from schema v1 to v2
        final migrator = v1Db.createMigrator();
        await v1Db.migration.onUpgrade(migrator, 1, 2);

        // 1. Table Creation & Usability: Verify reference_images table exists and is operational
        final tablesAfter = await v1Db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='reference_images';",
            )
            .get();
        expect(tablesAfter, hasLength(1));

        final refImageId = await v1Db.createReferenceImage(
          ReferenceImagesCompanion(
            title: const drift.Value('Post Migration Ref'),
            imageData: drift.Value(Uint8List.fromList([10, 20, 30])),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        expect(refImageId, isPositive);

        final queriedRef = await v1Db.getReferenceImageById(refImageId);
        expect(queriedRef, isNotNull);
        expect(queriedRef!.title, equals('Post Migration Ref'));

        // 2. Creations Data Preservation: Verify existing creations records are untouched
        final preservedCreation = await v1Db.getCreationById(creationId);
        expect(preservedCreation, isNotNull);
        expect(preservedCreation!.title, equals('V1 Creation'));
        expect(preservedCreation.gridData, equals('[[1, 2], [3, 4]]'));
        expect(preservedCreation.paletteName, equals('retro'));

        // 3. Session Data Preservation: Verify session row remains intact and activeCreationId is preserved
        final preservedSession = await v1Db.getSession();
        expect(preservedSession, isNotNull);
        expect(preservedSession!.activeCreationId, equals(creationId));
        expect(preservedSession.selectedTool, equals('pencil'));
        expect(preservedSession.userPrompt, equals('v1 prompt'));

        await v1Db.close();
      },
    );

    test(
      'migration onUpgrade does not recreate tables when from version is >= 2',
      () async {
        final migrator = db.createMigrator();
        // Calling onUpgrade with from >= 2 should evaluate from < 2 to false and be a no-op
        await db.migration.onUpgrade(migrator, 2, 2);
        await db.migration.onUpgrade(migrator, 2, 3);
      },
    );
  });

  group('ReferenceImages Stream Operations Tests', () {
    test(
      'watchAllReferenceImages emits initial empty list and subsequent inserts',
      () async {
        final stream = db.watchAllReferenceImages();
        final emissions = <List<ReferenceImage>>[];
        final subscription = stream.listen(emissions.add);

        // Initial emission should be an empty list
        await pumpEventQueue();
        expect(emissions, hasLength(1));
        expect(emissions.first, isEmpty);

        final now = DateTime.now();
        await db.createReferenceImage(
          ReferenceImagesCompanion(
            title: const drift.Value('Stream Ref 1'),
            imageData: drift.Value(Uint8List.fromList([1, 2, 3])),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        // Stream emits updated list containing the inserted item
        await pumpEventQueue();
        expect(emissions, hasLength(2));
        expect(emissions.last.length, equals(1));
        expect(emissions.last.first.title, equals('Stream Ref 1'));

        await subscription.cancel();
      },
    );

    test(
      'watchAllReferenceImages emits reactive updates on update and delete',
      () async {
        final now = DateTime.now();
        final id = await db.createReferenceImage(
          ReferenceImagesCompanion(
            title: const drift.Value('Original Stream Ref'),
            imageData: drift.Value(Uint8List.fromList([4, 5])),
            prompt: const drift.Value('initial prompt'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        final stream = db.watchAllReferenceImages();
        final emissions = <List<ReferenceImage>>[];
        final subscription = stream.listen(emissions.add);

        // Initial emission with original reference image
        await pumpEventQueue();
        expect(emissions, hasLength(1));
        expect(emissions.first.first.title, equals('Original Stream Ref'));

        // Update reference image
        await db.updateReferenceImage(
          ReferenceImagesCompanion(
            id: drift.Value(id),
            title: const drift.Value('Updated Stream Ref'),
            prompt: const drift.Value('updated prompt'),
          ),
        );

        await pumpEventQueue();
        expect(emissions, hasLength(2));
        expect(emissions[1].first.title, equals('Updated Stream Ref'));
        expect(emissions[1].first.prompt, equals('updated prompt'));

        // Delete reference image
        await db.deleteReferenceImage(id);

        await pumpEventQueue();
        expect(emissions, hasLength(3));
        expect(emissions[2], isEmpty);

        await subscription.cancel();
      },
    );

    test(
      'watchAllReferenceImages emits items ordered by updatedAt DESC, id DESC',
      () async {
        final now = DateTime.now();
        final tOld = now.subtract(const Duration(hours: 2));
        final tNew = now.subtract(const Duration(hours: 1));

        // Ref A: Older updatedAt
        final idA = await db.createReferenceImage(
          ReferenceImagesCompanion(
            title: const drift.Value('Ref A'),
            imageData: drift.Value(Uint8List.fromList([1])),
            createdAt: drift.Value(tOld),
            updatedAt: drift.Value(tOld),
          ),
        );

        // Ref B: Newer updatedAt
        final idB = await db.createReferenceImage(
          ReferenceImagesCompanion(
            title: const drift.Value('Ref B'),
            imageData: drift.Value(Uint8List.fromList([2])),
            createdAt: drift.Value(tNew),
            updatedAt: drift.Value(tNew),
          ),
        );

        // Ref C: Identical updatedAt as Ref B, but higher id
        final idC = await db.createReferenceImage(
          ReferenceImagesCompanion(
            title: const drift.Value('Ref C'),
            imageData: drift.Value(Uint8List.fromList([3])),
            createdAt: drift.Value(tNew),
            updatedAt: drift.Value(tNew),
          ),
        );

        expect(idC, greaterThan(idB));
        expect(idB, greaterThan(idA));

        final orderedList = await db.watchAllReferenceImages().first;
        expect(orderedList.map((e) => e.id).toList(), equals([idC, idB, idA]));
        expect(
          orderedList.map((e) => e.title).toList(),
          equals(['Ref C', 'Ref B', 'Ref A']),
        );
      },
    );
  });

  group('Database Constraints & Defaults Tests', () {
    test(
      'WorkspaceSessions singleton check constraint and update-in-place semantics',
      () async {
        final now = DateTime.now();

        // Initial save
        await db.saveSession(
          WorkspaceSessionsCompanion(
            id: const drift.Value(1),
            selectedColorIndex: const drift.Value(2),
            selectedTool: const drift.Value('line'),
            userPrompt: const drift.Value('initial prompt'),
            lastSavedAt: drift.Value(now),
          ),
        );

        final session1 = await db.getSession();
        expect(session1, isNotNull);
        expect(session1!.selectedTool, equals('line'));

        // Subsequent save with updated values modifies in-place (no duplicate rows)
        await db.saveSession(
          WorkspaceSessionsCompanion(
            id: const drift.Value(1),
            selectedColorIndex: const drift.Value(5),
            selectedTool: const drift.Value('brush'),
            userPrompt: const drift.Value('updated prompt'),
            lastSavedAt: drift.Value(now.add(const Duration(seconds: 10))),
          ),
        );

        final sessionCount = await db
            .customSelect('SELECT COUNT(*) AS c FROM workspace_sessions;')
            .getSingle();
        expect(sessionCount.data['c'], equals(1));

        final updatedSession = await db.getSession();
        expect(updatedSession!.selectedTool, equals('brush'));
        expect(updatedSession.selectedColorIndex, equals(5));
        expect(updatedSession.userPrompt, equals('updated prompt'));

        // Inserting with id != 1 violates CHECK (id = 1) constraint
        expect(
          () => db
              .into(db.workspaceSessions)
              .insert(
                WorkspaceSessionsCompanion(
                  id: const drift.Value(2),
                  lastSavedAt: drift.Value(DateTime.now()),
                ),
              ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'foreign key cascade sets activeCreationId to null when creation is deleted',
      () async {
        final fkDb = AppDatabase(NativeDatabase.memory());
        await fkDb.customStatement('PRAGMA foreign_keys = ON;');

        final now = DateTime.now();
        final creationId = await fkDb.createCreation(
          CreationsCompanion(
            title: const drift.Value('Referenced Creation'),
            gridSize: const drift.Value(16),
            gridData: const drift.Value('[]'),
            paletteName: const drift.Value('default'),
            paletteColors: const drift.Value('[]'),
            decomposedComponents: const drift.Value('[]'),
            aiHistoryLogs: const drift.Value('[]'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        await fkDb.saveSession(
          WorkspaceSessionsCompanion(
            id: const drift.Value(1),
            activeCreationId: drift.Value(creationId),
            lastSavedAt: drift.Value(now),
          ),
        );

        final sessionBefore = await fkDb.getSession();
        expect(sessionBefore!.activeCreationId, equals(creationId));

        // Delete referenced creation; foreign key onDelete: KeyAction.setNull triggers
        await fkDb.deleteCreation(creationId);

        final sessionAfter = await fkDb.getSession();
        expect(sessionAfter, isNotNull);
        expect(sessionAfter!.activeCreationId, isNull);

        await fkDb.close();
      },
    );

    test(
      'default column values are applied when optional fields are omitted',
      () async {
        final now = DateTime.now();

        // Creations defaults
        final creationId = await db.createCreation(
          CreationsCompanion.insert(
            gridSize: 16,
            gridData: '[]',
            paletteName: 'primary',
            paletteColors: '[]',
            decomposedComponents: '[]',
            aiHistoryLogs: '[]',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final creation = await db.getCreationById(creationId);
        expect(creation!.title, equals('Untitled'));

        // ReferenceImages defaults
        final refId = await db.createReferenceImage(
          ReferenceImagesCompanion.insert(
            imageData: Uint8List.fromList([1, 2, 3]),
            createdAt: now,
            updatedAt: now,
          ),
        );
        final ref = await db.getReferenceImageById(refId);
        expect(ref!.title, equals('Untitled Reference'));
        expect(ref.source, equals('upload'));
        expect(ref.bmpData, isNull);
        expect(ref.prompt, isNull);

        // WorkspaceSessions defaults
        await db.saveSession(
          WorkspaceSessionsCompanion.insert(lastSavedAt: now),
        );
        final session = await db.getSession();
        expect(session!.selectedColorIndex, equals(1));
        expect(session.selectedTool, equals('line'));
        expect(session.userPrompt, equals(''));
        expect(session.activeCreationId, isNull);
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

class _TestV1Database extends AppDatabase {
  _TestV1Database(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  drift.MigrationStrategy get migration => drift.MigrationStrategy(
    onCreate: (m) async {
      await m.createTable(creations);
      await m.createTable(workspaceSessions);
    },
    onUpgrade: super.migration.onUpgrade,
  );
}
