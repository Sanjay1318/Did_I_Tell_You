import 'dart:io';

import 'package:did_i_tell_you/models/memory.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Switches sqflite to its desktop (FFI) implementation so database code can
/// run in `flutter test` and CI without a phone or emulator. Call once at the
/// top of `main()`.
void useFfiDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// A throwaway folder that sqflite treats as the app's databases folder, so
/// every test starts from an empty database file.
class TempDatabaseDir {
  TempDatabaseDir._(this.dir);

  final Directory dir;

  /// Where `DatabaseService` keeps its file inside this folder.
  String get dbPath => p.join(dir.path, 'memory_app.db');

  static Future<TempDatabaseDir> create() async {
    final temp = TempDatabaseDir._(
      Directory.systemTemp.createTempSync('did_i_tell_you_db_'),
    );
    await temp.activate();
    return temp;
  }

  /// Makes sqflite use this folder from now on.
  Future<void> activate() => databaseFactory.setDatabasesPath(dir.path);

  void delete() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {
      // Best effort: a file still locked on Windows must not fail the run.
    }
  }
}

/// Builds a [Memory] with sensible defaults so tests only spell out what they
/// care about.
Memory makeMemory({
  int? id,
  String text = 'a note',
  DateTime? createdAt,
  DateTime? updatedAt,
  String category = 'general',
  String? person,
  double? amount,
  String? extractedDate,
  String? location,
  String status = 'active',
  bool isPinned = false,
  String? reminderAt,
  String moneyStatus = 'open',
  List<String> tags = const [],
  List<String> attachmentPaths = const [],
  String? taskAction,
  String taskStatus = 'none',
  String? recurrence,
  Map<String, dynamic> metadata = const {},
}) {
  final created = createdAt ?? DateTime.utc(2026, 1, 1);
  return Memory(
    id: id,
    originalText: text,
    createdAt: created,
    updatedAt: updatedAt ?? created,
    category: category,
    person: person,
    amount: amount,
    extractedDate: extractedDate,
    location: location,
    status: status,
    isPinned: isPinned,
    reminderAt: reminderAt,
    moneyStatus: moneyStatus,
    tags: tags,
    attachmentPaths: attachmentPaths,
    taskAction: taskAction,
    taskStatus: taskStatus,
    recurrence: recurrence,
    metadata: metadata,
  );
}

/// The schema version stored in the database file (SQLite's user_version).
Future<int> schemaVersion(Database db) async {
  final rows = await db.rawQuery('PRAGMA user_version');
  return rows.first['user_version'] as int;
}

/// Column name -> "type|notnull|default|pk" for the memories table.
Future<Map<String, String>> columnSchema(Database db) async {
  final rows = await db.rawQuery('PRAGMA table_info(memories)');
  return {
    for (final row in rows)
      row['name'] as String: '${row['type']}'
          '|notnull=${row['notnull']}'
          '|default=${row['dflt_value']}'
          '|pk=${row['pk']}',
  };
}

Future<Set<String>> indexNames(Database db) async {
  final rows = await db.rawQuery('PRAGMA index_list(memories)');
  return {for (final row in rows) row['name'] as String};
}

Future<Set<String>> tableNames(Database db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  );
  return {for (final row in rows) row['name'] as String};
}
