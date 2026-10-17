import 'package:did_i_tell_you/models/memory.dart';
import 'package:did_i_tell_you/services/database_service.dart';
import 'package:did_i_tell_you/services/memory_service.dart';
import 'package:did_i_tell_you/services/reminder_service.dart';

/// A database that lives in a list, so service and widget tests run instantly
/// and without SQLite. It mimics what the real queries return: only active
/// memories, pinned first, then newest first.
class FakeDatabaseService extends DatabaseService {
  FakeDatabaseService([List<Memory> initial = const []]) {
    for (final memory in initial) {
      _insert(memory);
    }
  }

  final List<Memory> rows = [];
  int _nextId = 1;

  /// Set to make every write fail, to test error handling.
  bool failWrites = false;

  int _insert(Memory memory) {
    final id = memory.id ?? _nextId;
    if (id >= _nextId) _nextId = id + 1;
    rows.add(memory.copyWith(id: id));
    return id;
  }

  @override
  Future<int> insertMemory(Memory memory) async {
    if (failWrites) throw StateError('write failed');
    return _insert(memory);
  }

  @override
  Future<int> updateMemory(Memory memory) async {
    if (failWrites) throw StateError('write failed');
    final index = rows.indexWhere((m) => m.id == memory.id);
    if (index == -1) return 0;
    rows[index] = memory;
    return 1;
  }

  @override
  Future<int> deleteMemory(int id) async {
    if (failWrites) throw StateError('write failed');
    final before = rows.length;
    rows.removeWhere((m) => m.id == id);
    return before - rows.length;
  }

  @override
  Future<void> deleteAllMemories() async {
    if (failWrites) throw StateError('write failed');
    rows.clear();
  }

  @override
  Future<List<Memory>> getAllMemories() async {
    final active = rows.where((m) => m.status == 'active').toList();
    active.sort((a, b) {
      final pinned = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
      return pinned != 0 ? pinned : b.createdAt.compareTo(a.createdAt);
    });
    return active;
  }

  @override
  Future<List<Memory>> getArchivedMemories() async =>
      rows.where((m) => m.status == 'archived').toList();

  @override
  Future<Memory?> getMemoryById(int id) async {
    for (final memory in rows) {
      if (memory.id == id) return memory;
    }
    return null;
  }

  @override
  Future<void> close() async {}
}

/// Records reminder calls instead of touching the phone's notifications.
class FakeReminderService extends ReminderService {
  FakeReminderService() : super.forTesting();

  final List<({int id, String body, DateTime time, String? repeat})> scheduled =
      [];
  final List<int> cancelled = [];

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? repeat,
  }) async {
    scheduled.add((id: id, body: body, time: scheduledTime, repeat: repeat));
  }

  @override
  Future<void> cancelReminder(int id) async {
    cancelled.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelled.add(-1);
  }
}

/// A [MemoryService] wired to fakes, already loaded.
Future<({MemoryService service, FakeDatabaseService db, FakeReminderService reminders})>
    makeService([List<Memory> initial = const []]) async {
  final db = FakeDatabaseService(initial);
  final reminders = FakeReminderService();
  final service = MemoryService(db, reminders: reminders);
  await service.loadMemories();
  return (service: service, db: db, reminders: reminders);
}
