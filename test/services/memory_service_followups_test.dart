import 'package:did_i_tell_you/models/memory.dart';
import 'package:did_i_tell_you/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';

DateTime _ahead(int days) => DateTime.now().add(Duration(days: days));
DateTime _ago(int days) => DateTime.now().subtract(Duration(days: days));

void main() {
  group('keyword search for questions', () {
    List<int?> ids(List<Memory> memories) => memories.map((m) => m.id).toList();

    test('finds a memory from a question that is not word for word',
        () async {
      final t = await makeService([
        makeMemory(id: 1, text: 'Keys are in the kitchen drawer'),
        makeMemory(id: 2, text: 'Parked at Forum Mall'),
      ]);

      expect(ids(t.service.parseNaturalQuery('where did I put my keys')), [1]);
    });

    test('matches a plural question word to the singular in the memory',
        () async {
      final t = await makeService([
        makeMemory(id: 1, text: 'Bought a water bottle'),
        makeMemory(id: 2, text: 'Parked at Forum Mall'),
      ]);

      expect(ids(t.service.parseNaturalQuery('where are my bottles')), [1]);
    });

    test('puts the memory that matches more words first', () async {
      final t = await makeService([
        makeMemory(
            id: 1,
            text: 'Spare keys kept in the drawer',
            createdAt: DateTime.utc(2026, 1, 1)),
        makeMemory(
            id: 2,
            text: 'Keys are on the table',
            createdAt: DateTime.utc(2026, 1, 2)),
      ]);

      // Memory 2 is newer, but memory 1 matches both "spare" and "keys".
      expect(ids(t.service.parseNaturalQuery('where are the spare keys')),
          [1, 2]);
    });

    test('newest first when memories match equally well', () async {
      final t = await makeService([
        makeMemory(
            id: 1, text: 'Keys on the shelf', createdAt: DateTime.utc(2026, 1, 1)),
        makeMemory(
            id: 2, text: 'Keys on the table', createdAt: DateTime.utc(2026, 1, 2)),
      ]);

      expect(ids(t.service.parseNaturalQuery('where are my keys')), [2, 1]);
    });

    test('also looks at tags, person and location', () async {
      final t = await makeService([
        makeMemory(id: 1, text: 'Left it there', tags: ['spectacles']),
        makeMemory(id: 2, text: 'Nothing here'),
      ]);

      expect(ids(t.service.parseNaturalQuery('where are my spectacles')), [1]);
    });

    test('a question made only of filler words finds nothing', () async {
      final t = await makeService([
        makeMemory(id: 1, text: 'Remember to know everything'),
      ]);

      expect(t.service.parseNaturalQuery('what do I know'), isEmpty);
    });

    test('a question with no matching word finds nothing', () async {
      final t = await makeService([makeMemory(id: 1, text: 'Parked at Forum')]);

      expect(t.service.parseNaturalQuery('where is the zebra'), isEmpty);
    });

    test('a word-for-word match still wins over keyword matching', () async {
      final t = await makeService([
        makeMemory(id: 1, text: 'keys are in the drawer'),
        makeMemory(id: 2, text: 'spare keys with a neighbour'),
      ]);

      expect(ids(t.service.parseNaturalQuery('spare keys')), [2]);
    });
  });

  group('overdue follow-ups', () {
    Memory pending({
      int? id,
      String? reminderAt,
      String? extractedDate,
      String status = 'pending',
    }) =>
        makeMemory(
            id: id,
            taskStatus: status,
            taskAction: 'do it',
            reminderAt: reminderAt,
            extractedDate: extractedDate);

    test('a pending follow-up with a past reminder is overdue', () {
      expect(
          MemoryService.isOverdue(
              pending(reminderAt: _ago(1).toIso8601String())),
          isTrue);
    });

    test('a future reminder is not overdue', () {
      expect(
          MemoryService.isOverdue(
              pending(reminderAt: _ahead(1).toIso8601String())),
          isFalse);
    });

    test('a completed follow-up is never overdue', () {
      expect(
          MemoryService.isOverdue(pending(
              status: 'completed', reminderAt: _ago(5).toIso8601String())),
          isFalse);
    });

    test('a memory that is not a follow-up is never overdue', () {
      expect(
          MemoryService.isOverdue(
              pending(status: 'none', reminderAt: _ago(5).toIso8601String())),
          isFalse);
    });

    test('no reminder and no date means it cannot be overdue', () {
      expect(MemoryService.isOverdue(pending()), isFalse);
    });

    test('a date in the text counts once that day is over', () {
      expect(
          MemoryService.isOverdue(
              pending(extractedDate: _ago(1).toIso8601String())),
          isTrue);
      expect(
          MemoryService.isOverdue(
              pending(extractedDate: DateTime.now().toIso8601String())),
          isFalse);
      expect(
          MemoryService.isOverdue(
              pending(extractedDate: _ahead(2).toIso8601String())),
          isFalse);
    });

    test('the reminder time wins over the date in the text', () {
      expect(
          MemoryService.isOverdue(pending(
              reminderAt: _ahead(1).toIso8601String(),
              extractedDate: _ago(3).toIso8601String())),
          isFalse);
    });

    test('overdueFollowUps lists only overdue ones, longest overdue first',
        () async {
      final t = await makeService([
        pending(id: 1, reminderAt: _ago(1).toIso8601String()),
        pending(id: 2, reminderAt: _ago(5).toIso8601String()),
        pending(id: 3, reminderAt: _ahead(2).toIso8601String()),
        pending(id: 4),
      ]);

      expect(t.service.overdueFollowUps.map((m) => m.id), [2, 1]);
    });
  });

  group('repeating reminders', () {
    test('a repeating reminder is scheduled with its repeat setting',
        () async {
      final when = _ahead(2);
      final memory = makeMemory(id: 7, text: 'Water the plants');
      final t = await makeService([memory]);

      await t.service.setReminder(memory.copyWith(recurrence: 'weekly'), when);

      expect(t.reminders.scheduled.single.repeat, 'weekly');
      expect(t.reminders.scheduled.single.time, when);
    });

    test('a reminder that does not repeat has no repeat setting', () async {
      final memory = makeMemory(id: 7, text: 'Pay rent');
      final t = await makeService([memory]);

      await t.service.setReminder(memory, _ahead(2));

      expect(t.reminders.scheduled.single.repeat, isNull);
    });

    test('setRecurrence saves and reschedules the existing reminder',
        () async {
      final when = _ahead(3);
      final memory =
          makeMemory(id: 7, text: 'Pay rent', reminderAt: when.toIso8601String());
      final t = await makeService([memory]);

      expect(await t.service.setRecurrence(memory, 'monthly'), isTrue);

      expect(t.service.memories.single.recurrence, 'monthly');
      expect(t.db.rows.single.recurrence, 'monthly');
      expect(t.reminders.cancelled, [7]);
      expect(t.reminders.scheduled.single.repeat, 'monthly');
      expect(t.reminders.scheduled.single.time, when);
    });

    test('a repeating reminder in the past carries on from its next time',
        () async {
      final past = _ago(3);
      final memory = makeMemory(
          id: 7, text: 'Take the bins out', reminderAt: past.toIso8601String());
      final t = await makeService([memory]);

      await t.service.setRecurrence(memory, 'daily');

      final scheduled = t.reminders.scheduled.single;
      expect(scheduled.repeat, 'daily');
      expect(scheduled.time.isAfter(DateTime.now()), isTrue);
      expect(scheduled.time.hour, past.hour);
      expect(scheduled.time.minute, past.minute);
    });

    test('a one-off reminder in the past is not scheduled', () async {
      final memory = makeMemory(
          id: 7, text: 'Old', reminderAt: _ago(3).toIso8601String());
      final t = await makeService([memory]);

      await t.service.setRecurrence(memory, null);

      expect(t.reminders.scheduled, isEmpty);
    });

    test('setting a repeat with no reminder saves it but schedules nothing',
        () async {
      final memory = makeMemory(id: 7, text: 'No reminder yet');
      final t = await makeService([memory]);

      expect(await t.service.setRecurrence(memory, 'daily'), isTrue);

      expect(t.service.memories.single.recurrence, 'daily');
      expect(t.reminders.scheduled, isEmpty);
    });

    test('turning the repeat off makes the reminder fire once', () async {
      final memory = makeMemory(
          id: 7,
          text: 'Pay rent',
          recurrence: 'weekly',
          reminderAt: _ahead(3).toIso8601String());
      final t = await makeService([memory]);

      expect(await t.service.setRecurrence(memory, null), isTrue);

      expect(t.service.memories.single.recurrence, isNull);
      expect(t.db.rows.single.recurrence, isNull);
      expect(t.reminders.scheduled.single.repeat, isNull);
    });

    test('an unknown repeat value is refused and changes nothing', () async {
      final memory = makeMemory(id: 7, text: 'Pay rent');
      final t = await makeService([memory]);

      expect(await t.service.setRecurrence(memory, 'hourly'), isFalse);

      expect(t.service.memories.single.recurrence, isNull);
      expect(t.reminders.scheduled, isEmpty);
      expect(t.reminders.cancelled, isEmpty);
    });

    test('a failed save leaves the notification alone', () async {
      final memory = makeMemory(
          id: 7, text: 'Pay rent', reminderAt: _ahead(3).toIso8601String());
      final t = await makeService([memory]);
      t.db.failWrites = true;

      expect(await t.service.setRecurrence(memory, 'daily'), isFalse);

      expect(t.reminders.scheduled, isEmpty);
      expect(t.reminders.cancelled, isEmpty);
    });
  });
}
