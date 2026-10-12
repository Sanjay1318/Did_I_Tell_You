import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/memory.dart';

class DatabaseService {
  Database? _database;

  Future<Database> get database async {
    _database ??= await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'memory_app.db');
    _database = await openDatabase(
      path,
      version: 4,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE memories (
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
        is_pinned INTEGER NOT NULL DEFAULT 0,
        reminder_at TEXT,
        money_status TEXT NOT NULL DEFAULT 'open',
        tags TEXT NOT NULL DEFAULT '[]',
        attachment_paths TEXT NOT NULL DEFAULT '[]',
        task_action TEXT,
        task_status TEXT NOT NULL DEFAULT 'none',
        recurrence TEXT,
        metadata TEXT DEFAULT '{}'
      )
    ''');

    await db.execute('CREATE INDEX idx_memories_person ON memories(person)');
    await db
        .execute('CREATE INDEX idx_memories_category ON memories(category)');
    await db.execute(
        'CREATE INDEX idx_memories_created_at ON memories(created_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Drop FTS table if it exists from an older version
    try {
      await db.execute('DROP TABLE IF EXISTS memories_fts');
    } catch (_) {}
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE memories ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE memories ADD COLUMN reminder_at TEXT');
      await db.execute(
          "ALTER TABLE memories ADD COLUMN money_status TEXT NOT NULL DEFAULT 'open'");
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_memories_status ON memories(status)');
    }
    if (oldVersion < 4) {
      await db.execute(
          "ALTER TABLE memories ADD COLUMN tags TEXT NOT NULL DEFAULT '[]'");
      await db.execute(
          "ALTER TABLE memories ADD COLUMN attachment_paths TEXT NOT NULL DEFAULT '[]'");
      await db.execute('ALTER TABLE memories ADD COLUMN task_action TEXT');
      await db.execute(
          "ALTER TABLE memories ADD COLUMN task_status TEXT NOT NULL DEFAULT 'none'");
      await db.execute('ALTER TABLE memories ADD COLUMN recurrence TEXT');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_memories_task_status ON memories(task_status)');
    }
  }

  Future<int> insertMemory(Memory memory) async {
    final db = await database;
    return await db.insert('memories', memory.toMap());
  }

  Future<int> updateMemory(Memory memory) async {
    final db = await database;
    return await db.update(
      'memories',
      memory.toMap(),
      where: 'id = ?',
      whereArgs: [memory.id],
    );
  }

  Future<int> deleteMemory(int id) async {
    final db = await database;
    return await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Memory>> getAllMemories() async {
    final db = await database;
    final result = await db.query(
      'memories',
      where: "status = 'active'",
      orderBy: 'is_pinned DESC, created_at DESC',
    );
    return result.map(Memory.fromMap).toList();
  }

  Future<List<Memory>> getMemoriesByPerson(String person) async {
    final db = await database;
    final result = await db.query(
      'memories',
      where: "person = ? AND status = 'active'",
      whereArgs: [person],
      orderBy: 'created_at DESC',
    );
    return result.map(Memory.fromMap).toList();
  }

  Future<List<Memory>> searchMemories(String query) async {
    final db = await database;
    // Use simple LIKE-based search across multiple fields
    final likePattern = '%${query.toLowerCase()}%';
    final result = await db.query(
      'memories',
      where:
          "status = 'active' AND (LOWER(original_text) LIKE ? OR LOWER(person) LIKE ? OR LOWER(location) LIKE ?)",
      whereArgs: [likePattern, likePattern, likePattern],
      orderBy: 'created_at DESC',
    );
    return result.map(Memory.fromMap).toList();
  }

  Future<List<Memory>> getMemoriesByCategory(String category) async {
    final db = await database;
    final result = await db.query(
      'memories',
      where: "category = ? AND status = 'active'",
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );
    return result.map(Memory.fromMap).toList();
  }

  Future<List<Memory>> getMemoriesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final result = await db.query(
      'memories',
      where: "created_at >= ? AND created_at <= ? AND status = 'active'",
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return result.map(Memory.fromMap).toList();
  }

  Future<Memory?> getMemoryById(int id) async {
    final db = await database;
    final result = await db.query(
      'memories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Memory.fromMap(result.first);
  }

  Future<List<String>> getAllDistinctPersons() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT person FROM memories
      WHERE person IS NOT NULL AND person != '' AND status = 'active'
      ORDER BY person COLLATE NOCASE
    ''');
    return result.map((row) => row['person'] as String).toList();
  }

  Future<void> deleteAllMemories() async {
    final db = await database;
    await db.delete('memories');
  }

  Future<List<Memory>> getArchivedMemories() async {
    final db = await database;
    final result = await db.query(
      'memories',
      where: "status = 'archived'",
      orderBy: 'updated_at DESC',
    );
    return result.map(Memory.fromMap).toList();
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
