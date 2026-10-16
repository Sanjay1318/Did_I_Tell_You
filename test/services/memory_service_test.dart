import 'dart:io';

import 'package:did_i_tell_you/models/memory.dart';
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
  }) async {
    throw StateError('notifications unavailable');
  }
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));
DateTime _daysAhead(int days) => DateTime.now().add(Duration(days: days));

void main() {
  group('addMemory', () {
    test('saves the text with the details found in it', () async {
      final t = await makeService();

      final saved = await t.service.addMemory('I lent Rahul 500 rupees');

      expect(saved, isNotNull);
      expect(saved!.id, isNotNull);
      expect(saved.originalText, 'I lent Rahul 500 rupees');
      expect(saved.person, 'Rahul');
      expect(saved.amount, 500.0);
      expect(saved.category, 'money');
      expect(saved.status, 'active');
      expect(saved.metadata['keywords'], isA<String>());
      expect(t.service.memories.single.id, saved.id);
      expect(t.db.rows.single.id, saved.id);
      expect(t.service.error, isNull);
    });

    test('trims the text before saving', () async {
      final t = await makeService();
      final saved = await t.service.addMemory('   Parked at Forum Mall  \n');
      expect(saved!.originalText, 'Parked at Forum Mall');
    });

    test('refuses empty or blank text and says why', () async {
      final t = await makeService();

      expect(await t.service.addMemory(''), isNull);
      expect(await t.service.addMemory('   \n '), isNull);

      expect(t.service.error, 'A memory cannot be empty.');
      expect(t.db.rows, isEmpty);
      expect(t.service.memories, isEmpty);
    });

    test('puts the newest memory first', () async {
      final t = await makeService();
      await t.service.addMemory('first note');
      await t.service.addMemory('second note');
      expect(t.service.memories.map((m) => m.originalText),
          ['second note', 'first note']);
    });

    test('cleans the tags: trims, drops blanks, removes repeats', () async {
      final t = await makeService();
      final saved = await t.service
          .addMemory('note', tags: [' work ', '', '  ', 'work', 'ideas']);
      expect(saved!.tags, ['work', 'ideas']);
    });

    test('keeps attachment paths and recurrence', () async {
      final t = await makeService();
      final saved = await t.service.addMemory('note',
          attachmentPaths: ['/a.jpg', '/b.jpg'], recurrence: 'weekly');
      expect(saved!.attachmentPaths, ['/a.jpg', '/b.jpg']);
      expect(saved.recurrence, 'weekly');
    });

    test('turns a promise into a pending follow-up', () async {
      final t = await makeService();
      final saved = await t.service.addMemory("I'll send the resume tomorrow");
      expect(saved!.taskAction, 'send the resume');
      expect(saved.taskStatus, 'pending');
    });

    test('an ordinary note has no follow-up', () async {
      final t = await makeService();
      final saved = await t.service.addMemory('Parked at Forum Mall');
      expect(saved!.taskAction, isNull);
      expect(saved.taskStatus, 'none');
    });

    test('tells listeners about the change', () async {
      final t = await makeService();
      var calls = 0;
      t.service.addListener(() => calls++);
      await t.service.addMemory('note');
      expect(calls, greaterThan(0));
    });

    group('reminders', () {
      test('a future reminder is stored and scheduled', () async {
        final t = await makeService();
        final when = _daysAhead(2);

        final saved = await t.service.addMemory('Call the bank', reminderAt: when);

        expect(saved!.reminderAt, when.toIso8601String());
        expect(t.reminders.scheduled, hasLength(1));
        expect(t.reminders.scheduled.single.id, saved.id);
        expect(t.reminders.scheduled.single.body, 'Call the bank');
        expect(t.reminders.scheduled.single.time, when);
      });

      test('a reminder time already past is stored but not scheduled',
          () async {
        final t = await makeService();
        final saved = await t.service
            .addMemory('Old news', reminderAt: _daysAgo(1));
        expect(saved!.reminderAt, isNotNull);
        expect(t.reminders.scheduled, isEmpty);
      });

      test('no reminder means nothing is scheduled', () async {
        final t = await makeService();
        final saved = await t.service.addMemory('note');
        expect(saved!.reminderAt, isNull);
        expect(t.reminders.scheduled, isEmpty);
      });

      test('the memory is still saved if scheduling fails', () async {
        final db = FakeDatabaseService();
        final service = MemoryService(db, reminders: _FailingReminders());

        final saved =
            await service.addMemory('note', reminderAt: _daysAhead(1));

        expect(saved, isNotNull);
        expect(db.rows, hasLength(1));
        expect(service.memories, hasLength(1));
      });
    });

    test('reports a failure and keeps the list unchanged', () async {
      final t = await makeService();
      t.db.failWrites = true;

      final saved = await t.service.addMemory('note');

      expect(saved, isNull);
      expect(t.service.error, 'Could not save memory. Please try again.');
      expect(t.service.memories, isEmpty);
    });

    test('a later success clears the earlier error', () async {
      final t = await makeService();
      await t.service.addMemory('');
      expect(t.service.error, isNotNull);
      await t.service.addMemory('note');
      expect(t.service.error, isNull);
    });
  });

  group('loadMemories', () {
    test('loads active memories, pinned first then newest first', () async {
      final t = await makeService([
        makeMemory(text: 'old', createdAt: DateTime.utc(2026, 1, 1)),
        makeMemory(text: 'new', createdAt: DateTime.utc(2026, 3, 1)),
        makeMemory(
            text: 'pinned old',
            createdAt: DateTime.utc(2025, 1, 1),
            isPinned: true),
        makeMemory(text: 'hidden', status: 'archived'),
      ]);
      expect(t.service.memories.map((m) => m.originalText),
          ['pinned old', 'new', 'old']);
      expect(t.service.isLoading, isFalse);
    });

    test('the list it hands out cannot be edited from outside', () async {
      final t = await makeService([makeMemory()]);
      expect(() => t.service.memories.add(makeMemory()), throwsUnsupportedError);
    });
  });

  group('updateMemory', () {
    test('re-reads the details from edited text', () async {
      final original = makeMemory(
        id: 1,
        text: 'I lent Rahul 500 rupees',
        person: 'Rahul',
        amount: 500.0,
        category: 'money',
        isPinned: true,
        tags: ['loan'],
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final t = await makeService([original]);

      final ok = await t.service
          .updateMemory(original.copyWith(originalText: 'Paid Priya 200 rupees'));

      expect(ok, isTrue);
      final updated = t.service.memories.single;
      expect(updated.originalText, 'Paid Priya 200 rupees');
      expect(updated.person, 'Priya');
      expect(updated.amount, 200.0);
      expect(updated.category, 'money');
      // Things the text cannot change are kept.
      expect(updated.id, 1);
      expect(updated.createdAt, DateTime.utc(2026, 1, 1));
      expect(updated.isPinned, isTrue);
      expect(updated.tags, ['loan']);
      expect(updated.updatedAt.isAfter(DateTime.utc(2026, 1, 1)), isTrue);
      expect(t.db.rows.single.originalText, 'Paid Priya 200 rupees');
    });

    group('follow-up status when the text is edited', () {
      test('a completed follow-up stays completed if it is still a follow-up',
          () async {
        final original = makeMemory(
          id: 1,
          text: 'I will call the bank',
          taskAction: 'call the bank',
          taskStatus: 'completed',
        );
        final t = await makeService([original]);

        await t.service.updateMemory(
            original.copyWith(originalText: 'I will call the bank on Monday'));

        final updated = t.service.memories.single;
        expect(updated.taskStatus, 'completed');
        expect(updated.taskAction, 'call the bank on Monday');
      });

      test('a pending follow-up stays pending', () async {
        final original = makeMemory(
          id: 1,
          text: 'I will call the bank',
          taskAction: 'call the bank',
          taskStatus: 'pending',
        );
        final t = await makeService([original]);

        await t.service.updateMemory(
            original.copyWith(originalText: 'I will email the bank'));

        expect(t.service.memories.single.taskStatus, 'pending');
      });

      test('a note that becomes a follow-up starts as pending', () async {
        final original = makeMemory(id: 1, text: 'Bank closes at five');
        final t = await makeService([original]);

        await t.service.updateMemory(
            original.copyWith(originalText: 'I will visit the bank'));

        expect(t.service.memories.single.taskStatus, 'pending');
      });

      test('editing the follow-up away clears it, even if it was completed',
          () async {
        final original = makeMemory(
          id: 1,
          text: 'I will call the bank',
          taskAction: 'call the bank',
          taskStatus: 'completed',
        );
        final t = await makeService([original]);

        await t.service
            .updateMemory(original.copyWith(originalText: 'Bank closes at five'));

        final updated = t.service.memories.single;
        expect(updated.taskStatus, 'none');
        expect(updated.taskAction, isNull);
      });
    });

    test('with reanalyze off, hand-corrected details are kept', () async {
      final original = makeMemory(
          id: 1, text: 'Met someone', person: 'Zed', category: 'people');
      final t = await makeService([original]);

      await t.service.updateMemory(original, reanalyze: false);

      expect(t.service.memories.single.person, 'Zed');
      expect(t.service.memories.single.category, 'people');
    });

    test('trims the edited text', () async {
      final original = makeMemory(id: 1, text: 'a');
      final t = await makeService([original]);
      await t.service.updateMemory(original.copyWith(originalText: '  b  '));
      expect(t.service.memories.single.originalText, 'b');
    });

    test('rejects empty text', () async {
      final original = makeMemory(id: 1, text: 'keep me');
      final t = await makeService([original]);

      final ok =
          await t.service.updateMemory(original.copyWith(originalText: '  '));

      expect(ok, isFalse);
      expect(t.service.memories.single.originalText, 'keep me');
    });

    test('rejects a memory that was never saved (no id)', () async {
      final t = await makeService();
      expect(await t.service.updateMemory(makeMemory(text: 'x')), isFalse);
    });

    test('reports a database failure', () async {
      final original = makeMemory(id: 1, text: 'a');
      final t = await makeService([original]);
      t.db.failWrites = true;

      final ok = await t.service
          .updateMemory(original.copyWith(originalText: 'changed'));

      expect(ok, isFalse);
      expect(t.service.error, 'Could not update memory. Please try again.');
      expect(t.service.memories.single.originalText, 'a');
    });
  });

  group('deleting', () {
    test('deleteMemory removes it from the list and the database', () async {
      final t = await makeService([makeMemory(id: 1), makeMemory(id: 2)]);

      expect(await t.service.deleteMemory(1), isTrue);

      expect(t.service.memories.map((m) => m.id), [2]);
      expect(t.db.rows.map((m) => m.id), [2]);
    });

    test('deleteMemory also deletes the memory\'s attachment files', () async {
      final dir = Directory.systemTemp.createTempSync('attach_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final photo = File('${dir.path}/photo.jpg')..writeAsStringSync('x');
      final t = await makeService([
        makeMemory(id: 1, attachmentPaths: [photo.path]),
      ]);

      await t.service.deleteMemory(1);

      expect(photo.existsSync(), isFalse);
    });

    test('a missing attachment file does not stop the delete', () async {
      final t = await makeService([
        makeMemory(id: 1, attachmentPaths: ['/no/such/file.jpg']),
      ]);
      expect(await t.service.deleteMemory(1), isTrue);
      expect(t.service.memories, isEmpty);
    });

    test('deleteMemory reports a database failure', () async {
      final t = await makeService([makeMemory(id: 1)]);
      t.db.failWrites = true;

      expect(await t.service.deleteMemory(1), isFalse);
      expect(t.service.error, 'Could not delete memory. Please try again.');
      expect(t.service.memories, hasLength(1));
    });

    test('deleteAllMemories empties the list and the database', () async {
      final t = await makeService([makeMemory(id: 1), makeMemory(id: 2)]);

      expect(await t.service.deleteAllMemories(), isTrue);

      expect(t.service.memories, isEmpty);
      expect(t.db.rows, isEmpty);
    });

    test('deleteAllMemories reports a database failure', () async {
      final t = await makeService([makeMemory(id: 1)]);
      t.db.failWrites = true;

      expect(await t.service.deleteAllMemories(), isFalse);
      expect(t.service.error, 'Could not delete memories. Please try again.');
      expect(t.service.memories, hasLength(1));
    });
  });

  group('pin, archive, restore and statuses', () {
    test('pinning moves a memory to the top', () async {
      final older = makeMemory(
          id: 1, text: 'older', createdAt: DateTime.utc(2026, 1, 1));
      final newer = makeMemory(
          id: 2, text: 'newer', createdAt: DateTime.utc(2026, 2, 1));
      final t = await makeService([older, newer]);
      expect(t.service.memories.first.originalText, 'newer');

      await t.service.setPinned(older, true);

      expect(t.service.memories.map((m) => m.originalText), ['older', 'newer']);
      expect(t.db.rows.firstWhere((m) => m.id == 1).isPinned, isTrue);
    });

    test('unpinning puts it back in date order', () async {
      final older = makeMemory(
          id: 1,
          text: 'older',
          createdAt: DateTime.utc(2026, 1, 1),
          isPinned: true);
      final newer = makeMemory(
          id: 2, text: 'newer', createdAt: DateTime.utc(2026, 2, 1));
      final t = await makeService([older, newer]);

      await t.service.setPinned(older, false);

      expect(t.service.memories.map((m) => m.originalText), ['newer', 'older']);
    });

    test('archiving removes it from the list but keeps it stored', () async {
      final memory = makeMemory(id: 1, text: 'to archive');
      final t = await makeService([memory]);

      expect(await t.service.archiveMemory(memory), isTrue);

      expect(t.service.memories, isEmpty);
      final archived = await t.service.getArchivedMemories();
      expect(archived.map((m) => m.originalText), ['to archive']);
    });

    test('restoring brings an archived memory back', () async {
      final archived = makeMemory(id: 1, text: 'back again', status: 'archived');
      final t = await makeService([archived]);
      expect(t.service.memories, isEmpty);

      expect(await t.service.restoreMemory(archived), isTrue);

      expect(t.service.memories.map((m) => m.originalText), ['back again']);
      expect(t.service.memories.single.status, 'active');
      expect(await t.service.getArchivedMemories(), isEmpty);
    });

    test('setMoneyStatus saves the new status', () async {
      final memory = makeMemory(id: 1, category: 'money');
      final t = await makeService([memory]);

      await t.service.setMoneyStatus(memory, 'settled');

      expect(t.service.memories.single.moneyStatus, 'settled');
      expect(t.db.rows.single.moneyStatus, 'settled');
    });

    test('setTaskStatus saves the new status', () async {
      final memory = makeMemory(id: 1, taskStatus: 'pending');
      final t = await makeService([memory]);

      await t.service.setTaskStatus(memory, 'completed');

      expect(t.service.memories.single.taskStatus, 'completed');
      expect(t.db.rows.single.taskStatus, 'completed');
    });

    test('a failed change leaves the list as it was', () async {
      final memory = makeMemory(id: 1);
      final t = await makeService([memory]);
      t.db.failWrites = true;

      expect(await t.service.setPinned(memory, true), isFalse);
      expect(t.service.memories.single.isPinned, isFalse);
      expect(t.service.error, 'Could not update memory. Please try again.');
    });
  });

  group('setReminder', () {
    test('sets a future reminder and schedules it', () async {
      final memory = makeMemory(id: 7, text: 'Pay rent');
      final t = await makeService([memory]);
      final when = _daysAhead(3);

      expect(await t.service.setReminder(memory, when), isTrue);

      expect(t.service.memories.single.reminderAt, when.toIso8601String());
      expect(t.db.rows.single.reminderAt, when.toIso8601String());
      expect(t.reminders.cancelled, [7]); // the old one is replaced
      expect(t.reminders.scheduled.single.id, 7);
      expect(t.reminders.scheduled.single.body, 'Pay rent');
    });

    test('removing the reminder clears it everywhere and cancels it',
        () async {
      final when = _daysAhead(3);
      final memory = makeMemory(id: 7, reminderAt: when.toIso8601String());
      final t = await makeService([memory]);

      expect(await t.service.setReminder(memory, null), isTrue);

      expect(t.service.memories.single.reminderAt, isNull);
      expect(t.db.rows.single.reminderAt, isNull);
      expect(t.reminders.cancelled, [7]);
      expect(t.reminders.scheduled, isEmpty);
    });

    test('removing the reminder leaves every other field alone', () async {
      final memory = makeMemory(
        id: 7,
        text: 'Call Priya',
        person: 'Priya',
        amount: 10,
        category: 'people',
        location: 'Office',
        isPinned: true,
        tags: ['family'],
        attachmentPaths: ['/a.jpg'],
        taskAction: 'call',
        taskStatus: 'pending',
        recurrence: 'weekly',
        metadata: {'keywords': 'call,priya'},
        reminderAt: _daysAhead(1).toIso8601String(),
      );
      final t = await makeService([memory]);

      await t.service.setReminder(memory, null);

      final after = t.service.memories.single;
      expect(after.reminderAt, isNull);
      expect(after.originalText, 'Call Priya');
      expect(after.person, 'Priya');
      expect(after.amount, 10);
      expect(after.category, 'people');
      expect(after.location, 'Office');
      expect(after.isPinned, isTrue);
      expect(after.tags, ['family']);
      expect(after.attachmentPaths, ['/a.jpg']);
      expect(after.taskAction, 'call');
      expect(after.taskStatus, 'pending');
      expect(after.recurrence, 'weekly');
      expect(after.metadata, {'keywords': 'call,priya'});
    });

    test('a reminder in the past is saved but not scheduled', () async {
      final memory = makeMemory(id: 7);
      final t = await makeService([memory]);

      await t.service.setReminder(memory, _daysAgo(1));

      expect(t.service.memories.single.reminderAt, isNotNull);
      expect(t.reminders.scheduled, isEmpty);
      expect(t.reminders.cancelled, [7]);
    });

    test('a failed save neither cancels nor schedules anything', () async {
      final memory = makeMemory(id: 7);
      final t = await makeService([memory]);
      t.db.failWrites = true;

      expect(await t.service.setReminder(memory, _daysAhead(1)), isFalse);

      expect(t.reminders.cancelled, isEmpty);
      expect(t.reminders.scheduled, isEmpty);
    });
  });

  group('clearing a field', () {
    test('copyWith cannot clear a value (known limitation)', () {
      // This is why setReminder, and the "Correct details" screen, build a
      // new Memory instead of using copyWith when a value must become empty.
      final memory = makeMemory(person: 'Rahul', reminderAt: '2026-01-01');
      expect(memory.copyWith(person: null).person, 'Rahul');
      expect(memory.copyWith(reminderAt: null).reminderAt, '2026-01-01');
    });

    test('the person can be cleared through updateMemory', () async {
      final memory = makeMemory(
        id: 1,
        text: 'Lunch with someone',
        person: 'Rahul',
        amount: 300,
        location: 'Cafe',
        tags: ['food'],
        attachmentPaths: ['/a.jpg'],
        taskAction: 'pay',
        taskStatus: 'pending',
        recurrence: 'daily',
      );
      final t = await makeService([memory]);

      // Same shape as the "Correct details" screen builds.
      final cleared = Memory(
        id: memory.id,
        originalText: memory.originalText,
        createdAt: memory.createdAt,
        updatedAt: DateTime.now(),
        category: memory.category,
        person: null,
        amount: memory.amount,
        extractedDate: memory.extractedDate,
        location: memory.location,
        status: memory.status,
        isPinned: memory.isPinned,
        reminderAt: memory.reminderAt,
        moneyStatus: memory.moneyStatus,
        tags: memory.tags,
        attachmentPaths: memory.attachmentPaths,
        taskAction: memory.taskAction,
        taskStatus: memory.taskStatus,
        recurrence: memory.recurrence,
        metadata: memory.metadata,
      );
      expect(await t.service.updateMemory(cleared, reanalyze: false), isTrue);

      final after = t.service.memories.single;
      expect(after.person, isNull);
      expect(t.db.rows.single.person, isNull);
      expect(after.amount, 300);
      expect(after.tags, ['food']);
      expect(after.attachmentPaths, ['/a.jpg']);
      expect(after.taskStatus, 'pending');
      expect(after.recurrence, 'daily');
    });

    test('a person removed from a memory disappears from the people list',
        () async {
      final memory = makeMemory(id: 1, person: 'Rahul');
      final t = await makeService([memory]);
      expect(t.service.getAllPersons(), ['Rahul']);

      await t.service.updateMemory(
        Memory(
          id: 1,
          originalText: memory.originalText,
          createdAt: memory.createdAt,
          updatedAt: DateTime.now(),
          category: memory.category,
        ),
        reanalyze: false,
      );

      expect(t.service.getAllPersons(), isEmpty);
    });
  });

  group('importMemories', () {
    Memory incoming(String text, {DateTime? at, bool pinned = false}) =>
        makeMemory(text: text, createdAt: at ?? DateTime.utc(2026, 1, 1), isPinned: pinned);

    test('adds new memories, gives them ids and returns how many', () async {
      final t = await makeService();

      final count = await t.service.importMemories([
        incoming('one', at: DateTime.utc(2026, 1, 1)),
        incoming('two', at: DateTime.utc(2026, 1, 2)),
      ]);

      expect(count, 2);
      expect(t.service.memories.map((m) => m.originalText), ['two', 'one']);
      expect(t.service.memories.every((m) => m.id != null), isTrue);
      expect(t.db.rows, hasLength(2));
    });

    test('skips a memory with the same text and time as one already there',
        () async {
      final t = await makeService([
        makeMemory(id: 1, text: 'Same note', createdAt: DateTime.utc(2026, 1, 1)),
      ]);

      final count = await t.service.importMemories([
        incoming('Same note'),
      ]);

      expect(count, 0);
      expect(t.service.memories, hasLength(1));
    });

    test('ignores letter case and surrounding spaces when comparing text',
        () async {
      final t = await makeService([
        makeMemory(id: 1, text: 'Same note', createdAt: DateTime.utc(2026, 1, 1)),
      ]);

      final count = await t.service.importMemories([
        incoming('  SAME NOTE '),
      ]);

      expect(count, 0);
    });

    test('same text at a different time is a different memory', () async {
      final t = await makeService([
        makeMemory(id: 1, text: 'Same note', createdAt: DateTime.utc(2026, 1, 1)),
      ]);

      final count = await t.service.importMemories([
        incoming('Same note', at: DateTime.utc(2026, 2, 1)),
      ]);

      expect(count, 1);
      expect(t.service.memories, hasLength(2));
    });

    test('importing the same backup twice adds nothing the second time',
        () async {
      final t = await makeService();
      final backup = [incoming('a'), incoming('b', at: DateTime.utc(2026, 1, 2))];

      expect(await t.service.importMemories(backup), 2);
      expect(await t.service.importMemories(backup), 0);
      expect(t.service.memories, hasLength(2));
    });

    test('a repeat inside the same backup is only added once', () async {
      final t = await makeService();
      final count = await t.service.importMemories([incoming('a'), incoming('a')]);
      expect(count, 1);
    });

    test('keeps every field of the imported memory', () async {
      final t = await makeService();
      final original = makeMemory(
        text: 'Lent Rahul 500',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 5),
        category: 'money',
        person: 'Rahul',
        amount: 500,
        extractedDate: '2026-01-02T00:00:00.000',
        location: 'Cafe',
        isPinned: true,
        reminderAt: '2026-02-01T09:00:00.000',
        moneyStatus: 'settled',
        tags: ['loan'],
        attachmentPaths: ['/a.jpg'],
        taskAction: 'collect',
        taskStatus: 'pending',
        recurrence: 'monthly',
        metadata: {'keywords': 'lent'},
      );

      await t.service.importMemories([original]);

      final saved = t.service.memories.single;
      expect(saved.originalText, original.originalText);
      expect(saved.updatedAt, original.updatedAt);
      expect(saved.category, 'money');
      expect(saved.person, 'Rahul');
      expect(saved.amount, 500);
      expect(saved.extractedDate, original.extractedDate);
      expect(saved.location, 'Cafe');
      expect(saved.isPinned, isTrue);
      expect(saved.reminderAt, original.reminderAt);
      expect(saved.moneyStatus, 'settled');
      expect(saved.tags, ['loan']);
      expect(saved.attachmentPaths, ['/a.jpg']);
      expect(saved.taskAction, 'collect');
      expect(saved.taskStatus, 'pending');
      expect(saved.recurrence, 'monthly');
      expect(saved.metadata, {'keywords': 'lent'});
    });

    test('pinned imports are listed first', () async {
      final t = await makeService();
      await t.service.importMemories([
        incoming('new', at: DateTime.utc(2026, 5, 1)),
        incoming('pinned old', at: DateTime.utc(2025, 1, 1), pinned: true),
      ]);
      expect(t.service.memories.map((m) => m.originalText),
          ['pinned old', 'new']);
    });

    test('archived memories are stored but not shown in the main list',
        () async {
      final t = await makeService();

      final count = await t.service.importMemories([
        makeMemory(text: 'archived one', status: 'archived'),
      ]);

      expect(count, 1);
      expect(t.service.memories, isEmpty);
      expect(await t.service.getArchivedMemories(), hasLength(1));
    });

    test('an empty backup imports nothing', () async {
      final t = await makeService();
      expect(await t.service.importMemories([]), 0);
    });

    test('a database failure returns 0 and reports it', () async {
      final t = await makeService();
      t.db.failWrites = true;

      expect(await t.service.importMemories([incoming('a')]), 0);
      expect(t.service.error, 'Could not import the backup.');
    });
  });

  group('checkDuplicate', () {
    test('returns nothing when there are no memories', () async {
      final t = await makeService();
      expect(await t.service.checkDuplicate('anything at all'), isNull);
    });

    test('flags the same text', () async {
      final t = await makeService([makeMemory(text: 'I lent Rahul 500 rupees')]);
      expect(await t.service.checkDuplicate('I lent Rahul 500 rupees'),
          'You already told me something very similar.');
    });

    test('flags mostly overlapping text as a duplicate', () async {
      final t = await makeService([makeMemory(text: 'I lent Rahul 500 rupees')]);
      expect(await t.service.checkDuplicate('I lent Rahul 500 rupees yesterday'),
          'You already told me something very similar.');
    });

    test('flags loosely overlapping text as similar', () async {
      // 3 shared words out of 8 distinct words = 0.375
      final t = await makeService([makeMemory(text: 'I lent Rahul 500 rupees')]);
      expect(await t.service.checkDuplicate('Rahul owes me 500 rupees today'),
          'This is similar to something you told me before.');
    });

    test('flags a negation of an earlier memory as a possible contradiction',
        () async {
      final t = await makeService([makeMemory(text: 'Priya likes tea')]);
      expect(await t.service.checkDuplicate('Priya does not like tea'),
          'It looks like this may update or contradict a previous memory.');
    });

    test('says nothing about unrelated text', () async {
      final t = await makeService([makeMemory(text: 'Parked at Forum Mall')]);
      expect(await t.service.checkDuplicate('Bought milk today'), isNull);
    });

    test('compares against every memory, not just the first', () async {
      final t = await makeService([
        makeMemory(id: 1, text: 'Parked at Forum Mall'),
        makeMemory(id: 2, text: 'I lent Rahul 500 rupees'),
      ]);
      expect(await t.service.checkDuplicate('I lent Rahul 500 rupees'),
          'You already told me something very similar.');
    });

    test('archived memories are not compared', () async {
      final t = await makeService([
        makeMemory(text: 'I lent Rahul 500 rupees', status: 'archived'),
      ]);
      expect(await t.service.checkDuplicate('I lent Rahul 500 rupees'), isNull);
    });
  });

  group('people', () {
    late MemoryService service;

    setUp(() async {
      final t = await makeService([
        makeMemory(id: 1, person: 'Rahul'),
        makeMemory(id: 2, person: 'Rahul'),
        makeMemory(id: 3, person: 'Priya'),
        makeMemory(id: 4, person: ''),
        makeMemory(id: 5),
        makeMemory(id: 6, person: 'Amit'),
        makeMemory(id: 7, person: 'Amit'),
        makeMemory(id: 8, person: 'Amit'),
      ]);
      service = t.service;
    });

    test('getAllPersons lists each name once, sorted, skipping blanks', () {
      expect(service.getAllPersons(), ['Amit', 'Priya', 'Rahul']);
    });

    test('getPersonSummaries counts mentions and puts the most mentioned first',
        () {
      final summaries = service.getPersonSummaries();
      expect(summaries.map((s) => s.name), ['Amit', 'Rahul', 'Priya']);
      expect(summaries.map((s) => s.mentionCount), [3, 2, 1]);
      expect(summaries.first.memories, hasLength(3));
    });
  });

  group('dates and day labels', () {
    test('getMemoriesForDate returns only memories from that calendar day',
        () async {
      final now = DateTime.now();
      final earlierToday = DateTime(now.year, now.month, now.day, 0, 0, 1);
      final t = await makeService([
        makeMemory(id: 1, text: 'today', createdAt: earlierToday),
        makeMemory(id: 2, text: 'long ago', createdAt: _daysAgo(40)),
      ]);

      final result = t.service.getMemoriesForDate(now);

      expect(result.map((m) => m.originalText), ['today']);
    });

    test('groupMemoriesByDay labels today and yesterday', () async {
      final t = await makeService([
        makeMemory(id: 1, text: 'a', createdAt: DateTime.now()),
        makeMemory(id: 2, text: 'b', createdAt: DateTime.now()),
        makeMemory(id: 3, text: 'c', createdAt: _daysAgo(1)),
      ]);

      final grouped = t.service.groupMemoriesByDay();

      expect(grouped.keys.toList(), ['Today', 'Yesterday']);
      expect(grouped['Today'], hasLength(2));
      expect(grouped['Yesterday'], hasLength(1));
    });

    test('2 to 6 days ago is labelled with the weekday name', () async {
      for (final days in [2, 3, 6]) {
        final created = _daysAgo(days);
        final t = await makeService([makeMemory(id: 1, createdAt: created)]);
        expect(t.service.groupMemoriesByDay().keys.single,
            _weekdays[created.weekday - 1],
            reason: '$days days ago');
      }
    });

    test('a week or more ago is labelled with the full date', () async {
      for (final days in [7, 10, 400]) {
        final created = _daysAgo(days);
        final t = await makeService([makeMemory(id: 1, createdAt: created)]);
        expect(t.service.groupMemoriesByDay().keys.single,
            '${_months[created.month - 1]} ${created.day}, ${created.year}',
            reason: '$days days ago');
      }
    });

    test('an empty list gives no groups', () async {
      final t = await makeService();
      expect(t.service.groupMemoriesByDay(), isEmpty);
    });

    group('getUpcomingReminders', () {
      test('groups future dates, ignoring past, missing and invalid ones',
          () async {
        final soon = _daysAhead(3);
        final t = await makeService([
          makeMemory(id: 1, text: 'soon', extractedDate: soon.toIso8601String()),
          makeMemory(
              id: 2,
              text: 'also soon',
              extractedDate: soon.toIso8601String()),
          makeMemory(
              id: 3,
              text: 'past',
              extractedDate: _daysAgo(2).toIso8601String()),
          makeMemory(id: 4, text: 'no date'),
          makeMemory(id: 5, text: 'bad date', extractedDate: 'not a date'),
        ]);

        final upcoming = t.service.getUpcomingReminders();

        expect(upcoming.keys.single, _weekdays[soon.weekday - 1]);
        expect(upcoming.values.single.map((m) => m.originalText),
            unorderedEquals(['soon', 'also soon']));
      });

      test('a date more than a week ahead shows the full date', () async {
        final far = _daysAhead(30);
        final t = await makeService([
          makeMemory(id: 1, extractedDate: far.toIso8601String()),
        ]);

        expect(t.service.getUpcomingReminders().keys.single,
            '${_months[far.month - 1]} ${far.day}, ${far.year}');
      });
    });
  });

  group('parseNaturalQuery', () {
    late MemoryService service;

    setUp(() async {
      final t = await makeService([
        makeMemory(
            id: 1,
            text: 'I lent Rahul 500 rupees',
            category: 'money',
            person: 'Rahul',
            amount: 500,
            createdAt: _daysAgo(2)),
        makeMemory(
            id: 2,
            text: 'Priya owes me 200 rupees',
            category: 'money',
            person: 'Priya',
            amount: 200,
            createdAt: _daysAgo(3)),
        makeMemory(
            id: 3,
            text: 'Paid the electricity bill',
            category: 'money',
            createdAt: _daysAgo(4)),
        makeMemory(
            id: 4,
            text: 'Parked at Forum Mall',
            category: 'places',
            createdAt: _daysAgo(1)),
        makeMemory(
            id: 5,
            text: 'Interview prep notes',
            category: 'work',
            tags: ['Career'],
            createdAt: _daysAgo(10)),
        makeMemory(
            id: 6,
            text: 'Rahul likes spicy food',
            category: 'general',
            person: 'Rahul',
            createdAt: _daysAgo(20)),
      ]);
      service = t.service;
    });

    List<int?> ids(List<Memory> memories) => memories.map((m) => m.id).toList();

    group('"who owes me"', () {
      test('returns money memories about lending, borrowing or owing', () {
        // The bill is money-related but not about owing, so it is left out.
        expect(ids(service.parseNaturalQuery('Who owes me money?')), [1, 2]);
      });

      test('also accepts "who owe me" and any letter case', () {
        expect(ids(service.parseNaturalQuery('WHO OWE ME anything')), [1, 2]);
      });

      test('takes priority over a name in the question', () {
        expect(ids(service.parseNaturalQuery('who owes me, Rahul?')), [1, 2]);
      });

      test('returns nothing when no one owes anything', () async {
        final t = await makeService([
          makeMemory(text: 'Paid the bill', category: 'money'),
        ]);
        expect(t.service.parseNaturalQuery('who owes me'), isEmpty);
      });
    });

    group('questions about a person', () {
      test('"what do I know about <name>"', () {
        expect(ids(service.parseNaturalQuery('What do I know about Rahul?')),
            [1, 6]);
      });

      test('"tell me about <name>"', () {
        expect(ids(service.parseNaturalQuery('tell me about priya')), [2]);
      });

      test('"show everything related to <name>"', () {
        expect(
            ids(service.parseNaturalQuery('Show everything related to Rahul')),
            [1, 6]);
      });

      test('also finds memories that only mention the name in the text', () async {
        final t = await makeService([
          makeMemory(id: 1, text: 'Dinner with Meena', person: null),
          makeMemory(id: 2, text: 'Something else'),
        ]);
        expect(ids(t.service.parseNaturalQuery('what do i know about meena')),
            [1]);
      });

      test('a name appearing anywhere in the question lists that person',
          () {
        expect(ids(service.parseNaturalQuery('what did rahul say')), [1, 6]);
      });

      test('a name beats a date word in the same question', () {
        expect(ids(service.parseNaturalQuery('Rahul yesterday')), [1, 6]);
      });
    });

    group('dates', () {
      test('"yesterday" returns memories from yesterday', () {
        expect(ids(service.parseNaturalQuery('what happened yesterday')), [4]);
      });

      test('"today" returns memories from today', () async {
        final t = await makeService([
          makeMemory(id: 1, text: 'fresh', createdAt: DateTime.now()),
          makeMemory(id: 2, text: 'stale', createdAt: _daysAgo(3)),
        ]);
        expect(ids(t.service.parseNaturalQuery('anything today')), [1]);
      });

      test('"last week" returns the past 7 days and nothing older', () {
        expect(ids(service.parseNaturalQuery('what did I do last week')),
            [4, 1, 2, 3]);
      });

      test('"last week" leaves out memories dated in the future', () async {
        final t = await makeService([
          makeMemory(id: 1, text: 'past', createdAt: _daysAgo(1)),
          makeMemory(id: 2, text: 'future', createdAt: _daysAhead(1)),
        ]);
        expect(ids(t.service.parseNaturalQuery('last week')), [1]);
      });

      test('"yesterday" is checked before "last week"', () {
        expect(ids(service.parseNaturalQuery('yesterday or last week')), [4]);
      });
    });

    group('categories and plain search', () {
      test('a category name returns that category', () {
        expect(ids(service.parseNaturalQuery('show my places')), [4]);
        expect(ids(service.parseNaturalQuery('money')), [1, 2, 3]);
      });

      test('other words search the text', () {
        expect(ids(service.parseNaturalQuery('forum')), [4]);
      });

      test('text search ignores letter case and outer spaces', () {
        expect(ids(service.parseNaturalQuery('   FORUM  ')), [4]);
      });

      test('text search also looks at tags', () {
        expect(ids(service.parseNaturalQuery('career')), [5]);
      });

      test('a question with no match returns nothing', () {
        expect(service.parseNaturalQuery('zebra'), isEmpty);
      });
    });
  });
}
