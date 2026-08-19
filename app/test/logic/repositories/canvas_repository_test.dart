import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agent_core/flutter_agent_core.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bad_pixel_art/logic/repositories/canvas_repository.dart';
import 'package:bad_pixel_art/logic/models/canvas_model.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CanvasRepository Unit Tests', () {
    late AppDatabase db;
    late CanvasRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      repository = CanvasRepository(dbGetter: () => db);
    });

    tearDown(() async {
      await db.close();
    });

    test('CanvasRepository can be instantiated and resolved via provider', () {
      expect(repository, isNotNull);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repoFromProvider = container.read(canvasRepositoryProvider);
      expect(repoFromProvider, isA<CanvasRepository>());
    });

    test('getAllCreations returns all creations from database', () async {
      expect(await repository.getAllCreations(), isEmpty);

      final now = DateTime.now();
      await db.createCreation(
        CreationsCompanion(
          title: const Value('Creation 1'),
          gridSize: const Value(16),
          gridData: const Value('[[0, 0], [0, 0]]'),
          paletteName: const Value('primary'),
          paletteColors: const Value('["#00000000", "#ffffffff"]'),
          decomposedComponents: const Value('[]'),
          aiHistoryLogs: const Value('[]'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.createCreation(
        CreationsCompanion(
          title: const Value('Creation 2'),
          gridSize: const Value(8),
          gridData: const Value('[[1]]'),
          paletteName: const Value('primary'),
          paletteColors: const Value('["#00000000", "#ff0000ff"]'),
          decomposedComponents: const Value('[]'),
          aiHistoryLogs: const Value('[]'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final creations = await repository.getAllCreations();
      expect(creations.length, equals(2));
      expect(
        creations.map((c) => c.title),
        containsAll(['Creation 1', 'Creation 2']),
      );
    });

    test(
      'renameCanvasById updates title and updatedAt without modifying other fields',
      () async {
        final initialTime = DateTime(2026, 1, 1, 10, 0);
        final id = await db.createCreation(
          CreationsCompanion(
            title: const Value('Original Title'),
            gridSize: const Value(16),
            gridData: const Value('[[1, 2], [3, 4]]'),
            paletteName: const Value('gameboy'),
            paletteColors: const Value('["#000000", "#ffffff"]'),
            decomposedComponents: const Value('["comp1"]'),
            aiHistoryLogs: const Value('["log1"]'),
            referenceImage: const Value(null),
            originalReferenceImage: const Value(null),
            createdAt: Value(initialTime),
            updatedAt: Value(initialTime),
          ),
        );

        await repository.renameCanvasById(id, 'Updated Title');

        final creation = await db.getCreationById(id);
        expect(creation, isNotNull);
        expect(creation!.title, equals('Updated Title'));
        expect(creation.gridSize, equals(16));
        expect(creation.gridData, equals('[[1, 2], [3, 4]]'));
        expect(creation.paletteName, equals('gameboy'));
        expect(creation.paletteColors, equals('["#000000", "#ffffff"]'));
        expect(creation.decomposedComponents, equals('["comp1"]'));
        expect(creation.aiHistoryLogs, equals('["log1"]'));
        expect(creation.createdAt, equals(initialTime));
        expect(creation.updatedAt.isAfter(initialTime), isTrue);
      },
    );

    test('renameCanvasById does nothing when id is non-existent', () async {
      await expectLater(
        repository.renameCanvasById(999, 'Non-existent Title'),
        completes,
      );
      expect(await repository.getAllCreations(), isEmpty);
    });

    test(
      'saveCanvas, loadCanvas, duplicateCanvas, and deleteCanvas work via repository',
      () async {
        final model = CanvasModel(
          gridSize: 16,
          grid: List.generate(16, (_) => List.filled(16, 0)),
          selectedColorIndex: 1,
          selectedTool: CanvasTool.line,
          paletteName: 'primary',
          palette: [Colors.black, Colors.white],
          userPrompt: 'A pixel cat',
          aiStatus: AiCoreStatus.available,
          isGenerating: false,
          autoRun: false,
          autoRunSpeed: 1.5,
          undoStack: const [],
          redoStack: const [],
          aiHistory: const [],
          referenceImage: null,
          originalReferenceImage: null,
          title: 'My Cat Canvas',
          modelReleaseStage: 'stable',
          modelPreference: 'full',
        );

        final saved = await repository.saveCanvas(model);
        expect(saved.creationId, isNotNull);
        final creationId = saved.creationId!;

        final loaded = await repository.loadCanvas(creationId, model);
        expect(loaded, isNotNull);
        expect(loaded!.title, equals('My Cat Canvas'));

        final duplicatedId = await repository.duplicateCanvas(creationId);
        expect(duplicatedId, isNotNull);
        final duplicatedCreation = await db.getCreationById(duplicatedId!);
        expect(duplicatedCreation!.title, equals('My Cat Canvas (Copy)'));

        final nextId = await repository.deleteCanvas(creationId);
        expect(nextId, equals(duplicatedId));

        final remaining = await repository.getAllCreations();
        expect(remaining.length, equals(1));
        expect(remaining.first.id, equals(duplicatedId));
      },
    );
  });
}
