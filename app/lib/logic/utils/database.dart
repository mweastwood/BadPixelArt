import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'database_connection/connection.dart' as impl;

part 'database.g.dart';

class Creations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withDefault(const Constant('Untitled'))();
  IntColumn get gridSize => integer()();
  TextColumn get gridData => text()(); // Serialized List<List<int>>
  TextColumn get paletteName => text()();
  TextColumn get paletteColors => text()(); // Serialized List<String>
  TextColumn get decomposedComponents =>
      text()(); // Serialized List<PixelArtComponent>
  TextColumn get aiHistoryLogs =>
      text()(); // Serialized List<AgentHistoryEntry>
  BlobColumn get referenceImage => blob().nullable()();
  BlobColumn get originalReferenceImage => blob().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class WorkspaceSessions extends Table {
  IntColumn get id =>
      integer().customConstraint('DEFAULT 1 CHECK (id = 1) NOT NULL')();
  IntColumn get activeCreationId => integer().nullable().references(
    Creations,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get selectedColorIndex =>
      integer().withDefault(const Constant(1))();
  TextColumn get selectedTool => text().withDefault(const Constant('line'))();
  TextColumn get userPrompt => text().withDefault(const Constant(''))();
  DateTimeColumn get lastSavedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Creations, WorkspaceSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  // Creations query methods
  Future<List<Creation>> getAllCreations() {
    return (select(creations)..orderBy([
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  Future<Creation?> getCreationById(int id) {
    return (select(creations)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> createCreation(CreationsCompanion companion) {
    return into(creations).insert(companion);
  }

  Future<void> updateCreation(CreationsCompanion companion) {
    return (update(
      creations,
    )..where((t) => t.id.equals(companion.id.value))).write(companion);
  }

  Future<void> deleteCreation(int id) {
    return (delete(creations)..where((t) => t.id.equals(id))).go();
  }

  // Sessions query methods
  Future<WorkspaceSession?> getSession() {
    return (select(workspaceSessions)..limit(1)).getSingleOrNull();
  }

  Future<void> saveSession(WorkspaceSessionsCompanion companion) {
    return into(workspaceSessions).insertOnConflictUpdate(companion);
  }
}

QueryExecutor _openConnection() {
  return impl.openConnection();
}

class AppDatabaseHelper {
  static AppDatabase? _db;

  static AppDatabase get db {
    _db ??= AppDatabase();
    return _db!;
  }

  @visibleForTesting
  static set db(AppDatabase database) {
    _db = database;
  }
}
