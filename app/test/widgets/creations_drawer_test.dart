import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:bad_pixel_art/logic/utils/database.dart';
import 'package:bad_pixel_art/widgets/creations_drawer.dart';
import 'package:bad_pixel_art/logic/canvas_state.dart';
import 'package:bad_pixel_art/logic/utils/logging_ai_service.dart';
import '../test_helper.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  group('CreationsDrawer Widget & Golden Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      AppDatabaseHelper.db = db;
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertMockCreation(String title, {int gridSize = 16}) async {
      final now = DateTime.now();
      await db.createCreation(
        CreationsCompanion(
          title: Value(title),
          gridSize: Value(gridSize),
          gridData: const Value('[[0, 0], [0, 0]]'),
          paletteName: const Value('primary'),
          paletteColors: const Value('["#00000000", "#ffffffff"]'),
          decomposedComponents: const Value('[]'),
          aiHistoryLogs: const Value('[]'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }

    testWidgets('renders empty state correctly when no creations exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: CreationsDrawer())),
      );

      // Wait for FutureBuilder to resolve
      await tester.pump();

      expect(find.text('Creations Gallery'), findsOneWidget);
      expect(find.text('No creations yet'), findsOneWidget);
    });

    testWidgets('renders creations list and supports search query filtering', (
      tester,
    ) async {
      await insertMockCreation('Sword Design');
      await insertMockCreation('Shield Sprite');

      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: CreationsDrawer())),
      );

      // Wait for FutureBuilder to resolve
      await tester.pump();

      expect(find.text('Sword Design'), findsOneWidget);
      expect(find.text('Shield Sprite'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'shield');
      await tester.pump();

      expect(find.text('Shield Sprite'), findsOneWidget);
      expect(find.text('Sword Design'), findsNothing);
    });

    testWidgets('clicking on a creation triggers loading it', (tester) async {
      await insertMockCreation('Sword Design');

      // Query the created record to get its ID
      final list = await db.getAllCreations();
      final creationId = list.first.id;

      int? loadedCreationId;

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [
            canvasStateProvider.overrideWith((ref) {
              final aiService = ref.watch(loggingAiServiceProvider);
              return _MockCanvasNotifier(
                aiService,
                onLoad: (id) => loadedCreationId = id,
              );
            }),
          ],
          child: const Scaffold(body: CreationsDrawer()),
        ),
      );

      await tester.pump();

      // Tap on the creation
      await tester.tap(find.text('Sword Design'));
      await tester.pumpAndSettle();

      expect(loadedCreationId, equals(creationId));
    });

    testWidgets('Rename dialog triggers name update', (tester) async {
      await insertMockCreation('Old Title');

      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: CreationsDrawer())),
      );

      await tester.pump();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Rename
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Enter new name
      await tester.enterText(find.byType(TextField).last, 'New Title');
      await tester.tap(
        find.byKey(const ValueKey('rename_dialog_confirm_button')),
      );
      await tester.pumpAndSettle();

      // Check database
      final creations = await db.getAllCreations();
      expect(creations.first.title, equals('New Title'));
    });

    testWidgets('Delete option triggers creation removal', (tester) async {
      await insertMockCreation('To Delete');

      await tester.pumpWidget(
        buildTestableWidget(child: const Scaffold(body: CreationsDrawer())),
      );

      await tester.pump();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm delete dialog
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      // Check database is empty
      final creations = await db.getAllCreations();
      expect(creations, isEmpty);
    });

    testGoldens('CreationsDrawer renders correctly', (tester) async {
      // Clear database to test empty state
      db = AppDatabase(NativeDatabase.memory());
      AppDatabaseHelper.db = db;

      final builderEmpty = GoldenBuilder.column()
        ..addScenario(
          'Empty Creations List',
          const SizedBox(width: 320, height: 600, child: CreationsDrawer()),
        );

      await tester.pumpWidgetBuilder(
        builderEmpty.build(),
        wrapper: testMaterialAppWrapper(),
        surfaceSize: const Size(400, 700),
      );
      await screenMatchesGolden(tester, 'creations_drawer_empty');

      // Populate database to test list state
      db = AppDatabase(NativeDatabase.memory());
      AppDatabaseHelper.db = db;
      final now = DateTime(2026, 7, 20, 12, 34);
      await db.createCreation(
        CreationsCompanion(
          id: const Value(1),
          title: const Value('Blue Sword'),
          gridSize: const Value(16),
          gridData: const Value('[[0, 1], [1, 0]]'),
          paletteName: const Value('primary'),
          paletteColors: const Value('["#00000000", "#ff0000ff"]'),
          decomposedComponents: const Value('[]'),
          aiHistoryLogs: const Value('[]'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.createCreation(
        CreationsCompanion(
          id: const Value(2),
          title: const Value('Red Shield'),
          gridSize: const Value(8),
          gridData: const Value('[[0]]'),
          paletteName: const Value('primary'),
          paletteColors: const Value('["#00000000", "#ff0000ff"]'),
          decomposedComponents: const Value('[]'),
          aiHistoryLogs: const Value('[]'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final builderList = GoldenBuilder.column()
        ..addScenario(
          'Populated Creations List',
          const SizedBox(width: 320, height: 600, child: CreationsDrawer()),
        );

      await tester.pumpWidgetBuilder(
        builderList.build(),
        wrapper: testMaterialAppWrapper(),
        surfaceSize: const Size(400, 700),
      );
      await screenMatchesGolden(tester, 'creations_drawer_list');
    });
  });
}

class _MockCanvasNotifier extends CanvasNotifier {
  final Function(int id)? onLoad;

  _MockCanvasNotifier(super.aiService, {this.onLoad});

  @override
  Future<void> loadFromDb(int id) async {
    if (onLoad != null) onLoad!(id);
    return super.loadFromDb(id);
  }
}
