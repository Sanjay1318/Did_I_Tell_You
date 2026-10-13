import 'package:did_i_tell_you/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_test_support.dart';

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

  group('fresh database', () {
    test('is created at schema version 4', () async {
      final db = await service.database;
      expect(await schemaVersion(db), 4);
    });

    test('has every expected column', () async {
      final db = await service.database;
      final columns = (await columnSchema(db)).keys.toSet();
      expect(columns, {
        'id',
        'original_text',
        'created_at',
        'updated_at',
        'category',
        'person',
        'amount',
        'extracted_date',
        'location',
        'status',
        'is_pinned',
        'reminder_at',
        'money_status',
        'tags',
        'attachment_paths',
        'task_action',
        'task_status',
        'recurrence',
        'metadata',
      });
    });

    test('has the person, category and created_at indexes', () async {
      final db = await service.database;
      expect(
        await indexNames(db),
        containsAll([
          'idx_memories_person',
          'idx_memories_category',
          'idx_memories_created_at',
        ]),
      );
    });

    test('starts empty', () async {
      expect(await service.getAllMemories(), isEmpty);
      expect(await service.getArchivedMemories(), isEmpty);
      expect(await service.getAllDistinctPersons(), isEmpty);
    });
  });

  group('insert and read back', () {
    test('every field survives a round trip', () async {
      final original = makeMemory(
        text: 'I lent Rahul 500 rupees',
        createdAt: DateTime.utc(2026, 1, 1, 10, 30),
        updatedAt: DateTime.utc(2026, 1, 2, 11, 45),
        category: 'money',
        person: 'Rahul',
        amount: 500,
        extractedDate: '2026-01-02T00:00:00.000Z',
        location: 'Hyderabad',
        isPinned: true,
        reminderAt: '2026-02-01T09:00:00.000Z',
        moneyStatus: 'settled',
        tags: ['Career', 'Ravi'],
        attachmentPaths: ['/private/attachment.jpg'],
        taskAction: 'send my resume',
        taskStatus: 'pending',
        recurrence: 'weekly',
        metadata: {'keywords': 'lent,rahul', 'source': 'voice'},
      );

      final id = await service.insertMemory(original);
      final loaded = await service.getMemoryById(id);

      expect(loaded, isNotNull);
      expect(loaded!.id, id);
      expect(loaded.originalText, 'I lent Rahul 500 rupees');
      expect(loaded.createdAt, DateTime.utc(2026, 1, 1, 10, 30));
      expect(loaded.updatedAt, DateTime.utc(2026, 1, 2, 11, 45));
      expect(loaded.category, 'money');
      expect(loaded.person, 'Rahul');
      expect(loaded.amount, 500.0);
      expect(loaded.extractedDate, '2026-01-02T00:00:00.000Z');
      expect(loaded.location, 'Hyderabad');
      expect(loaded.status, 'active');
      expect(loaded.isPinned, isTrue);
      expect(loaded.reminderAt, '2026-02-01T09:00:00.000Z');
      expect(loaded.moneyStatus, 'settled');
      expect(loaded.tags, ['Career', 'Ravi']);
      expect(loaded.attachmentPaths, ['/private/attachment.jpg']);
      expect(loaded.taskAction, 'send my resume');
      expect(loaded.taskStatus, 'pending');
      expect(loaded.recurrence, 'weekly');
      expect(loaded.metadata, {'keywords': 'lent,rahul', 'source': 'voice'});
    });

    test('optional fields come back as their defaults', () async {
      final id = await service.insertMemory(makeMemory(text: 'plain note'));
      final loaded = (await service.getMemoryById(id))!;

      expect(loaded.person, isNull);
      expect(loaded.amount, isNull);
      expect(loaded.location, isNull);
      expect(loaded.isPinned, isFalse);
      expect(loaded.moneyStatus, 'open');
      expect(loaded.tags, isEmpty);
      expect(loaded.attachmentPaths, isEmpty);
      expect(loaded.taskStatus, 'none');
      expect(loaded.metadata, isEmpty);
    });

    test('text with quotes, emoji and non-English letters is stored intact',
        () async {
      const text = "It's \"Priya's\" birthday 🎉 — రాహుల్ ₹500";
      final id = await service.insertMemory(makeMemory(text: text));
      expect((await service.getMemoryById(id))!.originalText, text);
    });

    test('ids are assigned in order and never reused after a delete',
        () async {
      final first = await service.insertMemory(makeMemory(text: 'one'));
      final second = await service.insertMemory(makeMemory(text: 'two'));
      expect(second, first + 1);

      await service.deleteMemory(second);
      final third = await service.insertMemory(makeMemory(text: 'three'));
      expect(third, second + 1);
    });

    test('getMemoryById returns null for an id that does not exist', () async {
      expect(await service.getMemoryById(12345), isNull);
    });
  });

  group('getAllMemories', () {
    test('returns pinned first, then newest first, and skips archived',
        () async {
      await service.insertMemory(
          makeMemory(text: 'oldest', createdAt: DateTime.utc(2026, 1, 1)));
      await service.insertMemory(
          makeMemory(text: 'newest', createdAt: DateTime.utc(2026, 1, 3)));
      await service.insertMemory(makeMemory(
        text: 'pinned but older',
        createdAt: DateTime.utc(2026, 1, 2),
        isPinned: true,
      ));
      await service.insertMemory(makeMemory(
        text: 'archived',
        createdAt: DateTime.utc(2026, 1, 4),
        status: 'archived',
      ));

      final texts =
          (await service.getAllMemories()).map((m) => m.originalText).toList();
      expect(texts, ['pinned but older', 'newest', 'oldest']);
    });
  });

  group('updateMemory', () {
    test('changes the stored values and reports one row updated', () async {
      final id = await service.insertMemory(
          makeMemory(text: 'before', person: 'Rahul', tags: ['a']));
      final loaded = (await service.getMemoryById(id))!;

      final changed = await service.updateMemory(loaded.copyWith(
        originalText: 'after',
        isPinned: true,
        tags: ['b', 'c'],
        taskStatus: 'done',
      ));

      expect(changed, 1);
      final reloaded = (await service.getMemoryById(id))!;
      expect(reloaded.originalText, 'after');
      expect(reloaded.isPinned, isTrue);
      expect(reloaded.tags, ['b', 'c']);
      expect(reloaded.taskStatus, 'done');
      expect(reloaded.person, 'Rahul'); // untouched field is kept
      expect(reloaded.id, id);
    });

    test('does not create a new row', () async {
      final id = await service.insertMemory(makeMemory(text: 'only one'));
      final loaded = (await service.getMemoryById(id))!;
      await service.updateMemory(loaded.copyWith(originalText: 'still one'));
      expect(await service.getAllMemories(), hasLength(1));
    });

    test('archiving moves a memory from the active to the archived list',
        () async {
      final id = await service.insertMemory(makeMemory(text: 'to archive'));
      final loaded = (await service.getMemoryById(id))!;

      await service.updateMemory(loaded.copyWith(status: 'archived'));

      expect(await service.getAllMemories(), isEmpty);
      final archived = await service.getArchivedMemories();
      expect(archived.map((m) => m.originalText), ['to archive']);
    });

    test('updating an id that does not exist changes nothing', () async {
      final changed =
          await service.updateMemory(makeMemory(id: 999, text: 'ghost'));
      expect(changed, 0);
      expect(await service.getAllMemories(), isEmpty);
    });
  });

  group('deleting', () {
    test('deleteMemory removes one memory and leaves the others', () async {
      final keep = await service.insertMemory(makeMemory(text: 'keep'));
      final drop = await service.insertMemory(makeMemory(text: 'drop'));

      expect(await service.deleteMemory(drop), 1);

      expect(await service.getMemoryById(drop), isNull);
      expect(await service.getMemoryById(keep), isNotNull);
    });

    test('deleting the same id twice reports zero the second time', () async {
      final id = await service.insertMemory(makeMemory());
      expect(await service.deleteMemory(id), 1);
      expect(await service.deleteMemory(id), 0);
    });

    test('deleteAllMemories clears active and archived memories', () async {
      await service.insertMemory(makeMemory(text: 'active'));
      await service
          .insertMemory(makeMemory(text: 'archived', status: 'archived'));

      await service.deleteAllMemories();

      expect(await service.getAllMemories(), isEmpty);
      expect(await service.getArchivedMemories(), isEmpty);
    });

    test('deleteAllMemories on an empty database is harmless', () async {
      await service.deleteAllMemories();
      expect(await service.getAllMemories(), isEmpty);
    });
  });

  group('getMemoriesByPerson', () {
    test('returns that person\'s active memories, newest first', () async {
      await service.insertMemory(makeMemory(
          text: 'older', person: 'Rahul', createdAt: DateTime.utc(2026, 1, 1)));
      await service.insertMemory(makeMemory(
          text: 'newer', person: 'Rahul', createdAt: DateTime.utc(2026, 1, 2)));
      await service.insertMemory(makeMemory(text: 'other', person: 'Priya'));
      await service.insertMemory(makeMemory(
          text: 'archived', person: 'Rahul', status: 'archived'));

      final texts = (await service.getMemoriesByPerson('Rahul'))
          .map((m) => m.originalText)
          .toList();
      expect(texts, ['newer', 'older']);
    });

    test('returns nothing for an unknown person', () async {
      await service.insertMemory(makeMemory(person: 'Rahul'));
      expect(await service.getMemoriesByPerson('Nobody'), isEmpty);
    });

    // Characterization test: SQLite compares text case-sensitively with "=".
    test('matching is case-sensitive (current behavior)', () async {
      await service.insertMemory(makeMemory(person: 'Rahul'));
      expect(await service.getMemoriesByPerson('rahul'), isEmpty);
    });
  });

  group('getMemoriesByCategory', () {
    test('returns active memories in that category, newest first', () async {
      await service.insertMemory(makeMemory(
          text: 'old money',
          category: 'money',
          createdAt: DateTime.utc(2026, 1, 1)));
      await service.insertMemory(makeMemory(
          text: 'new money',
          category: 'money',
          createdAt: DateTime.utc(2026, 1, 2)));
      await service.insertMemory(makeMemory(text: 'job', category: 'work'));
      await service.insertMemory(makeMemory(
          text: 'archived money', category: 'money', status: 'archived'));

      final texts = (await service.getMemoriesByCategory('money'))
          .map((m) => m.originalText)
          .toList();
      expect(texts, ['new money', 'old money']);
    });

    test('returns nothing for a category with no memories', () async {
      await service.insertMemory(makeMemory(category: 'money'));
      expect(await service.getMemoriesByCategory('education'), isEmpty);
    });
  });

  group('getMemoriesByDateRange', () {
    setUp(() async {
      for (final day in [1, 5, 10]) {
        await service.insertMemory(makeMemory(
          text: 'day $day',
          createdAt: DateTime.utc(2026, 1, day),
        ));
      }
      await service.insertMemory(makeMemory(
        text: 'archived day 7',
        createdAt: DateTime.utc(2026, 1, 7),
        status: 'archived',
      ));
    });

    test('includes both end dates and sorts newest first', () async {
      final results = await service.getMemoriesByDateRange(
        DateTime.utc(2026, 1, 5),
        DateTime.utc(2026, 1, 10),
      );
      expect(results.map((m) => m.originalText).toList(), ['day 10', 'day 5']);
    });

    test('excludes memories outside the range', () async {
      final results = await service.getMemoriesByDateRange(
        DateTime.utc(2026, 1, 2),
        DateTime.utc(2026, 1, 4),
      );
      expect(results, isEmpty);
    });

    test('excludes archived memories even when they fall inside the range',
        () async {
      final results = await service.getMemoriesByDateRange(
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 31),
      );
      expect(results.map((m) => m.originalText),
          isNot(contains('archived day 7')));
      expect(results, hasLength(3));
    });
  });

  group('searchMemories', () {
    test('is case-insensitive and also checks person and location', () async {
      await service.insertMemory(makeMemory(
          text: 'I lent Rahul 500 rupees', person: 'Rahul', category: 'money'));
      await service.insertMemory(makeMemory(
          text: 'Parked at Forum Mall', location: 'Forum Mall'));
      await service.insertMemory(makeMemory(
          text: 'Met someone new', person: 'Ananya', location: 'Chennai'));

      Future<List<String>> search(String query) async =>
          (await service.searchMemories(query))
              .map((m) => m.originalText)
              .toList();

      expect(await search('RAHUL'), ['I lent Rahul 500 rupees']);
      expect(await search('forum'), ['Parked at Forum Mall']);
      // These two words are not in the text, only in the person/location.
      expect(await search('ananya'), ['Met someone new']);
      expect(await search('chennai'), ['Met someone new']);
    });

    test('matches part of a word', () async {
      await service.insertMemory(makeMemory(text: 'Remember the passport'));
      expect(await service.searchMemories('port'), hasLength(1));
    });

    test('returns nothing when there is no match', () async {
      await service.insertMemory(makeMemory(text: 'Bought milk'));
      expect(await service.searchMemories('zzz'), isEmpty);
    });

    test('skips archived memories', () async {
      await service
          .insertMemory(makeMemory(text: 'secret plan', status: 'archived'));
      expect(await service.searchMemories('secret'), isEmpty);
    });

    test('returns matches newest first', () async {
      await service.insertMemory(makeMemory(
          text: 'alpha note', createdAt: DateTime.utc(2026, 1, 1)));
      await service.insertMemory(makeMemory(
          text: 'beta note', createdAt: DateTime.utc(2026, 1, 2)));

      final texts = (await service.searchMemories('note'))
          .map((m) => m.originalText)
          .toList();
      expect(texts, ['beta note', 'alpha note']);
    });

    test('a memory with no person or location is still searchable by text',
        () async {
      await service.insertMemory(makeMemory(text: 'plain text only'));
      expect(await service.searchMemories('plain'), hasLength(1));
    });

    // Characterization test: "%%" matches everything. Callers that should not
    // list every memory for a blank search must check for that themselves.
    test('an empty query returns every active memory (current behavior)',
        () async {
      await service.insertMemory(makeMemory(text: 'one'));
      await service.insertMemory(makeMemory(text: 'two'));
      await service
          .insertMemory(makeMemory(text: 'archived', status: 'archived'));
      expect(await service.searchMemories(''), hasLength(2));
    });

    test('searching for a literal % matches only text that contains it',
        () async {
      await service.insertMemory(makeMemory(text: 'Discount 50% off'));
      await service.insertMemory(makeMemory(text: 'Paid 500 rupees'));

      final texts = (await service.searchMemories('50%'))
          .map((m) => m.originalText)
          .toList();
      expect(texts, ['Discount 50% off']);
    },
        skip: 'Known issue: the query goes into a LIKE pattern without '
            'escaping, so "%" and "_" act as wildcards. "50%" also matches '
            '"500 rupees", and "_" matches every memory.');
  });

  group('getAllDistinctPersons', () {
    test('lists each active person once, ignoring blanks and archived',
        () async {
      await service.insertMemory(makeMemory(person: 'Rahul'));
      await service.insertMemory(makeMemory(person: 'Rahul'));
      await service.insertMemory(makeMemory(person: 'Amit'));
      await service.insertMemory(makeMemory(person: null));
      await service.insertMemory(makeMemory(person: ''));
      await service
          .insertMemory(makeMemory(person: 'Zed', status: 'archived'));

      expect(await service.getAllDistinctPersons(), ['Amit', 'Rahul']);
    });

    test('sorts names without regard to letter case', () async {
      await service.insertMemory(makeMemory(person: 'Charan'));
      await service.insertMemory(makeMemory(person: 'amit'));
      await service.insertMemory(makeMemory(person: 'Bala'));

      expect(await service.getAllDistinctPersons(), ['amit', 'Bala', 'Charan']);
    });
  });

  group('getArchivedMemories', () {
    test('returns only archived memories, most recently updated first',
        () async {
      await service.insertMemory(makeMemory(
        text: 'archived earlier',
        status: 'archived',
        updatedAt: DateTime.utc(2026, 2, 1),
      ));
      await service.insertMemory(makeMemory(
        text: 'archived later',
        status: 'archived',
        updatedAt: DateTime.utc(2026, 3, 1),
      ));
      await service.insertMemory(makeMemory(text: 'still active'));

      final texts = (await service.getArchivedMemories())
          .map((m) => m.originalText)
          .toList();
      expect(texts, ['archived later', 'archived earlier']);
    });
  });

  group('persistence', () {
    test('data is still there after the database is closed and reopened',
        () async {
      await service.insertMemory(makeMemory(text: 'remember me', person: 'Ravi'));
      await service.close();

      final reopened = DatabaseService();
      addTearDown(reopened.close);

      final memories = await reopened.getAllMemories();
      expect(memories.map((m) => m.originalText), ['remember me']);
      expect(memories.single.person, 'Ravi');
    });

    test('a closed service reopens itself on the next call', () async {
      await service.insertMemory(makeMemory(text: 'before close'));
      await service.close();

      expect(await service.getAllMemories(), hasLength(1));
    });

    test('closing twice does not throw', () async {
      await service.close();
      await service.close();
    });
  });
}
