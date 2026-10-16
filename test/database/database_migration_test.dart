import 'package:did_i_tell_you/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db_test_support.dart';

// These tests rebuild the databases that older app versions left on a phone,
// then open them with the current DatabaseService to check that the upgrade
// keeps every row and fills in sensible defaults for the new columns.
//
// The old layouts are reconstructed from the migration code in
// database_service.dart (what version 3 and version 4 add), not copied from
// the old releases. If you still have a build from an older release, restoring
// its database file into a test is a stronger check.

/// Columns that existed before version 3.
const _baseColumns = '''
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  original_text TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  person TEXT,
  amount REAL,
  extracted_date TEXT,
  location TEXT,
  status TEXT DEFAULT 'active',
''';

/// Columns added by the version 3 upgrade.
const _v3Columns = '''
  is_pinned INTEGER NOT NULL DEFAULT 0,
  reminder_at TEXT,
  money_status TEXT NOT NULL DEFAULT 'open',
''';

Future<void> _createBaseIndexes(Database db) async {
  await db.execute('CREATE INDEX idx_memories_person ON memories(person)');
  await db.execute('CREATE INDEX idx_memories_category ON memories(category)');
  await db
      .execute('CREATE INDEX idx_memories_created_at ON memories(created_at)');
}

/// Writes a database file shaped like an app release older than version 3.
Future<void> _writeLegacyV2(
  String path, {
  int version = 2,
  List<Map<String, Object?>> rows = const [],
}) async {
  final db = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE memories (
            $_baseColumns
            metadata TEXT DEFAULT '{}'
          )
        ''');
        await _createBaseIndexes(db);
        // Older versions had a full-text search table that the upgrade drops.
        await db.execute('CREATE TABLE memories_fts (content TEXT)');
        for (final row in rows) {
          await db.insert('memories', row);
        }
      },
    ),
  );
  await db.close();
}

/// Writes a database file shaped like an app release at version 3.
Future<void> _writeLegacyV3(
  String path, {
  List<Map<String, Object?>> rows = const [],
}) async {
  final db = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE memories (
            $_baseColumns
            $_v3Columns
            metadata TEXT DEFAULT '{}'
          )
        ''');
        await _createBaseIndexes(db);
        await db.execute('CREATE INDEX idx_memories_status ON memories(status)');
        for (final row in rows) {
          await db.insert('memories', row);
        }
      },
    ),
  );
  await db.close();
}

/// Writes a database file shaped like the first version 4 builds: all the
/// version 4 columns, but without the status and task_status indexes (those
/// were only added to a brand-new database later).
Future<void> _writeEarlyV4(
  String path, {
  List<Map<String, Object?>> rows = const [],
}) async {
  final db = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE memories (
            $_baseColumns
            $_v3Columns
            tags TEXT NOT NULL DEFAULT '[]',
            attachment_paths TEXT NOT NULL DEFAULT '[]',
            task_action TEXT,
            task_status TEXT NOT NULL DEFAULT 'none',
            recurrence TEXT,
            metadata TEXT DEFAULT '{}'
          )
        ''');
        await _createBaseIndexes(db);
        for (final row in rows) {
          await db.insert('memories', row);
        }
      },
    ),
  );
  await db.close();
}

Map<String, Object?> _legacyRow({
  required String text,
  required String createdAt,
  String category = 'general',
  String? person,
  double? amount,
  String status = 'active',
  String metadata = '{}',
}) {
  return {
    'original_text': text,
    'created_at': createdAt,
    'updated_at': createdAt,
    'category': category,
    'person': person,
    'amount': amount,
    'status': status,
    'metadata': metadata,
  };
}

void main() {
  useFfiDatabase();

  late TempDatabaseDir temp;
  late DatabaseService service;

  setUp(() async {
    temp = await TempDatabaseDir.create();
    service = DatabaseService();
  });

  tearDown(() async {
    await service.close();
    temp.delete();
  });

  group('upgrading from version 3', () {
    setUp(() async {
      await _writeLegacyV3(temp.dbPath, rows: [
        {
          ..._legacyRow(
            text: 'I lent Rahul 500 rupees',
            createdAt: '2026-01-01T00:00:00.000Z',
            category: 'money',
            person: 'Rahul',
            amount: 500.0,
            metadata: 'keywords:lent,rahul|source:voice',
          ),
          'is_pinned': 1,
          'reminder_at': '2026-02-01T09:00:00.000Z',
          'money_status': 'settled',
        },
        {
          ..._legacyRow(
            text: 'Parked at Forum Mall',
            createdAt: '2026-01-02T00:00:00.000Z',
            category: 'places',
          ),
          'is_pinned': 0,
          'money_status': 'open',
        },
      ]);
    });

    test('moves the database to version 5', () async {
      final db = await service.database;
      expect(await schemaVersion(db), 5);
    });

    test('keeps every row and every existing value', () async {
      final memories = await service.getAllMemories();
      expect(memories, hasLength(2));

      final lent = memories.firstWhere((m) => m.person == 'Rahul');
      expect(lent.originalText, 'I lent Rahul 500 rupees');
      expect(lent.createdAt, DateTime.utc(2026, 1, 1));
      expect(lent.category, 'money');
      expect(lent.amount, 500.0);
      expect(lent.isPinned, isTrue);
      expect(lent.reminderAt, '2026-02-01T09:00:00.000Z');
      expect(lent.moneyStatus, 'settled');
    });

    test('gives the new version 4 columns their defaults', () async {
      for (final memory in await service.getAllMemories()) {
        expect(memory.tags, isEmpty);
        expect(memory.attachmentPaths, isEmpty);
        expect(memory.taskAction, isNull);
        expect(memory.taskStatus, 'none');
        expect(memory.recurrence, isNull);
      }
    });

    test('still reads metadata saved in the old "key:value|key:value" format',
        () async {
      final lent = (await service.getAllMemories())
          .firstWhere((m) => m.person == 'Rahul');
      expect(lent.metadata, {'keywords': 'lent,rahul', 'source': 'voice'});
    });

    test('adds the task_status index', () async {
      final db = await service.database;
      expect(await indexNames(db), contains('idx_memories_task_status'));
    });

    test('accepts new-style memories after the upgrade', () async {
      final id = await service.insertMemory(makeMemory(
        text: 'written after the upgrade',
        tags: ['new'],
        attachmentPaths: ['/photos/a.jpg'],
        taskAction: 'call the bank',
        taskStatus: 'pending',
        recurrence: 'daily',
      ));

      final loaded = (await service.getMemoryById(id))!;
      expect(loaded.tags, ['new']);
      expect(loaded.attachmentPaths, ['/photos/a.jpg']);
      expect(loaded.taskAction, 'call the bank');
      expect(loaded.taskStatus, 'pending');
      expect(loaded.recurrence, 'daily');
      expect(await service.getAllMemories(), hasLength(3));
    });

    test('ids of existing rows are unchanged and new ids continue after them',
        () async {
      final before = (await service.getAllMemories()).map((m) => m.id).toSet();
      expect(before, {1, 2});

      final newId = await service.insertMemory(makeMemory(text: 'next'));
      expect(newId, 3);
    });
  });

  // Version 1 and 2 share one layout as far as the migration code can tell:
  // both are older than 3, so both run the version 3 and version 4 steps.
  for (final oldVersion in [1, 2]) {
    group('upgrading from version $oldVersion', () {
      setUp(() async {
        await _writeLegacyV2(temp.dbPath, version: oldVersion, rows: [
          _legacyRow(
            text: 'Old note about Priya',
            createdAt: '2025-06-01T00:00:00.000Z',
            category: 'people',
            person: 'Priya',
          ),
          _legacyRow(
            text: 'Old archived note',
            createdAt: '2025-06-02T00:00:00.000Z',
            status: 'archived',
          ),
        ]);
      });

      test('moves the database to version 5', () async {
        final db = await service.database;
        expect(await schemaVersion(db), 5);
      });

      test('keeps the rows, including archived ones', () async {
        final active = await service.getAllMemories();
        expect(active.map((m) => m.originalText), ['Old note about Priya']);
        expect(active.single.person, 'Priya');
        expect(active.single.category, 'people');

        final archived = await service.getArchivedMemories();
        expect(archived.map((m) => m.originalText), ['Old archived note']);
      });

      test('fills in the version 3 and version 4 columns with defaults',
          () async {
        final memory = (await service.getAllMemories()).single;
        expect(memory.isPinned, isFalse);
        expect(memory.reminderAt, isNull);
        expect(memory.moneyStatus, 'open');
        expect(memory.tags, isEmpty);
        expect(memory.attachmentPaths, isEmpty);
        expect(memory.taskAction, isNull);
        expect(memory.taskStatus, 'none');
        expect(memory.recurrence, isNull);
      });

      test('drops the old full-text search table', () async {
        final db = await service.database;
        expect(await tableNames(db), isNot(contains('memories_fts')));
      });

      test('adds the status and task_status indexes', () async {
        final db = await service.database;
        expect(
          await indexNames(db),
          containsAll(['idx_memories_status', 'idx_memories_task_status']),
        );
      });
    });
  }

  group('upgraded and brand-new databases', () {
    test('have the same columns, types, defaults and constraints', () async {
      await _writeLegacyV2(temp.dbPath);
      final upgradedSchema = await columnSchema(await service.database);
      await service.close();

      final freshDir = await TempDatabaseDir.create();
      addTearDown(freshDir.delete);
      final fresh = DatabaseService();
      addTearDown(fresh.close);
      final freshSchema = await columnSchema(await fresh.database);

      expect(upgradedSchema, freshSchema);
    });

    test('have the same set of indexes', () async {
      await _writeLegacyV2(temp.dbPath);
      final upgradedIndexes = await indexNames(await service.database);
      await service.close();

      final freshDir = await TempDatabaseDir.create();
      addTearDown(freshDir.delete);
      final fresh = DatabaseService();
      addTearDown(fresh.close);
      final freshIndexes = await indexNames(await fresh.database);

      expect(freshIndexes, upgradedIndexes);
    });
  });

  group('upgrading from an early version 4 without the status indexes', () {
    setUp(() async {
      await _writeEarlyV4(temp.dbPath, rows: [
        {
          ..._legacyRow(text: 'Call Priya', createdAt: '2026-01-01T00:00:00.000Z'),
          'tags': '["family"]',
          'task_action': 'Call Priya',
          'task_status': 'pending',
        },
      ]);
    });

    test('adds the missing indexes and moves to version 5', () async {
      final db = await service.database;
      expect(await schemaVersion(db), 5);
      expect(
        await indexNames(db),
        containsAll(['idx_memories_status', 'idx_memories_task_status']),
      );
    });

    test('keeps the rows untouched', () async {
      final memory = (await service.getAllMemories()).single;
      expect(memory.originalText, 'Call Priya');
      expect(memory.tags, ['family']);
      expect(memory.taskStatus, 'pending');
    });
  });

  group('reopening a current database', () {
    test('does not change or lose data', () async {
      await service.insertMemory(makeMemory(text: 'first', tags: ['x']));
      await service.close();

      final reopened = DatabaseService();
      addTearDown(reopened.close);

      expect(await schemaVersion(await reopened.database), 5);
      final memories = await reopened.getAllMemories();
      expect(memories.map((m) => m.originalText), ['first']);
      expect(memories.single.tags, ['x']);
    });
  });

  group('unusual data already in the database', () {
    Future<int> insertRaw(Map<String, Object?> values) async {
      final db = await service.database;
      return db.insert('memories', {
        'original_text': 'raw row',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
        ...values,
      });
    }

    test('tags that are not valid JSON read back as an empty list', () async {
      final id = await insertRaw({'tags': 'not json'});
      expect((await service.getMemoryById(id))!.tags, isEmpty);
    });

    test('attachment paths stored as a JSON object read back as empty',
        () async {
      final id = await insertRaw({'attachment_paths': '{"a": 1}'});
      expect((await service.getMemoryById(id))!.attachmentPaths, isEmpty);
    });

    test('non-text items inside a tags list are dropped', () async {
      final id = await insertRaw({'tags': '[1, "keep", null]'});
      expect((await service.getMemoryById(id))!.tags, ['keep']);
    });

    test('metadata that is JSON but not an object reads back as empty',
        () async {
      final id = await insertRaw({'metadata': '[1, 2]'});
      expect((await service.getMemoryById(id))!.metadata, isEmpty);
    });

    test('a row missing optional values still loads', () async {
      final id = await insertRaw({});
      final loaded = (await service.getMemoryById(id))!;
      expect(loaded.category, 'general');
      expect(loaded.status, 'active');
      expect(loaded.tags, isEmpty);
      expect(loaded.metadata, isEmpty);
    });
  });
}
