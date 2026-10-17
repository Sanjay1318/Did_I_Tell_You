import 'package:did_i_tell_you/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';

/// A reminder service whose scheduling always fails.
class _FailingReminders extends FakeReminderService {
  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? repeat,
  }) async {
    throw StateError('notifications unavailable');
  }
}

DateTime _ahead(int days) => DateTime.now().add(Duration(days: days));
DateTime _ago(int days) => DateTime.now().subtract(Duration(days: days));

void main() {
  group('allMemoriesForBackup', () {
    test('includes archived memories as well as the ones on screen',
        () async {
      final t = await makeService([
        makeMemory(id: 1, text: 'active one'),
        makeMemory(id: 2, text: 'archived one', status: 'archived'),
      ]);

      final all = await t.service.allMemoriesForBackup();

      expect(all.map((m) => m.originalText),
          unorderedEquals(['active one', 'archived one']));
    });

    test('is empty when there is nothing at all', () async {
      final t = await makeService();
      expect(await t.service.allMemoriesForBackup(), isEmpty);
    });
  });

  group('previewImport', () {
    test('separates new memories from ones that are already here', () async {
      final t = await makeService([
        makeMemory(
            id: 1, text: 'I lent Rahul 500', createdAt: DateTime.utc(2026, 1, 1)),
      ]);

      final preview = await t.service.previewImport([
        makeMemory(text: 'I lent Rahul 500', createdAt: DateTime.utc(2026, 1, 1)),
        makeMemory(text: 'Parked at Forum', createdAt: DateTime.utc(2026, 1, 2)),
      ]);

      expect(preview.duplicates, 1);
      expect(preview.newMemories.map((m) => m.originalText), ['Parked at Forum']);
    });

    test('counts an archived memory as already here', () async {
      final t = await makeService([
        makeMemory(
            id: 1,
            text: 'old note',
            status: 'archived',
            createdAt: DateTime.utc(2026, 1, 1)),
      ]);

      final preview = await t.service.previewImport([
        makeMemory(
            text: 'old note',
            status: 'archived',
            createdAt: DateTime.utc(2026, 1, 1)),
      ]);

      expect(preview.duplicates, 1);
      expect(preview.newMemories, isEmpty);
    });

    test('counts a repeat inside the backup itself once', () async {
      final t = await makeService();
      final same = makeMemory(text: 'twice', createdAt: DateTime.utc(2026, 1, 1));

      final preview = await t.service.previewImport([same, same]);

      expect(preview.newMemories, hasLength(1));
      expect(preview.duplicates, 1);
    });

    test('changes nothing', () async {
      final t = await makeService([makeMemory(id: 1, text: 'here')]);

      await t.service.previewImport([makeMemory(text: 'new one')]);

      expect(t.service.memories, hasLength(1));
      expect(t.db.rows, hasLength(1));
    });
  });

  group('importMemories', () {
    test('importing the same archived memory twice adds it once', () async {
      final t = await makeService();
      final archived = makeMemory(
          text: 'archived', status: 'archived', createdAt: DateTime.utc(2026, 1, 1));

      expect(await t.service.importMemories([archived]), 1);
      expect(await t.service.importMemories([archived]), 0);

      expect(t.db.rows, hasLength(1));
    });

    test('sets up the notification for a future reminder', () async {
      final when = _ahead(3);
      final t = await makeService();

      await t.service.importMemories([
        makeMemory(text: 'Pay rent', reminderAt: when.toIso8601String()),
      ]);

      final scheduled = t.reminders.scheduled.single;
      expect(scheduled.id, t.service.memories.single.id);
      expect(scheduled.body, 'Pay rent');
      expect(scheduled.time, when);
      expect(scheduled.repeat, isNull);
    });

    test('sets up a repeating reminder with its repeat setting', () async {
      final t = await makeService();

      await t.service.importMemories([
        makeMemory(
            text: 'Water plants',
            recurrence: 'weekly',
            reminderAt: _ahead(2).toIso8601String()),
      ]);

      expect(t.reminders.scheduled.single.repeat, 'weekly');
    });

    test('does not schedule a one-off reminder that is already in the past',
        () async {
      final t = await makeService();

      await t.service.importMemories([
        makeMemory(text: 'Old', reminderAt: _ago(3).toIso8601String()),
      ]);

      expect(t.reminders.scheduled, isEmpty);
    });

    test('does not schedule anything for a memory without a reminder',
        () async {
      final t = await makeService();

      await t.service.importMemories([makeMemory(text: 'plain')]);

      expect(t.reminders.scheduled, isEmpty);
      expect(t.reminders.cancelled, isEmpty);
    });

    test('does not schedule a reminder for an archived memory', () async {
      final t = await makeService();

      await t.service.importMemories([
        makeMemory(
            text: 'Archived',
            status: 'archived',
            reminderAt: _ahead(3).toIso8601String()),
      ]);

      expect(t.reminders.scheduled, isEmpty);
    });

    test('a notification problem does not stop the import', () async {
      final db = FakeDatabaseService();
      final service = MemoryService(db, reminders: _FailingReminders());
      await service.loadMemories();

      final count = await service.importMemories([
        makeMemory(text: 'one', reminderAt: _ahead(3).toIso8601String()),
        makeMemory(text: 'two', createdAt: DateTime.utc(2026, 1, 2)),
      ]);

      expect(count, 2);
      expect(db.rows, hasLength(2));
      expect(service.error, isNull);
    });
  });
}
