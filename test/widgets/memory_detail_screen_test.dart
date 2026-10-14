import 'package:did_i_tell_you/models/memory.dart';
import 'package:did_i_tell_you/screens/memory_detail_screen.dart';
import 'package:did_i_tell_you/services/memory_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

// Setting a reminder uses the date and time pickers, and attachments use the
// camera and gallery; those stay on the manual checklist.
Memory _loan() => makeMemory(
      id: 1,
      text: 'I lent Rahul 500 rupees',
      category: 'money',
      person: 'Rahul',
      amount: 500,
      location: 'Cafe',
      tags: ['loan'],
      taskAction: 'collect the money',
      taskStatus: 'pending',
      recurrence: 'monthly',
      createdAt: DateTime(2026, 1, 15),
    );

Future<({FakeDatabaseService db, MemoryService service})> _open(
  WidgetTester tester,
  Memory memory, {
  bool failWrites = false,
}) async {
  final t = await makeService([memory]);
  await openScreen(
    tester,
    MemoryDetailScreen(memory: t.service.memories.single),
    memories: t.service,
  );
  t.db.failWrites = failWrites;
  return (db: t.db, service: t.service);
}

Future<void> _menu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('Memory actions'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  group('what it shows', () {
    testWidgets('the memory and everything found in it', (tester) async {
      await _open(tester, _loan());

      expect(find.text('I lent Rahul 500 rupees'), findsOneWidget);
      expect(find.text('Money'), findsNWidgets(3)); // title, chip, info row
      expect(find.text('#loan'), findsOneWidget);
      expect(find.text('Rahul'), findsOneWidget);
      expect(find.text('₹500.0'), findsOneWidget);
      expect(find.text('Cafe'), findsOneWidget);
      expect(find.text('January 15, 2026'), findsNWidgets(2)); // top and "Created"
      expect(find.text('View all memories about Rahul'), findsOneWidget);
    });

    testWidgets('"Not detected" for anything that was not found',
        (tester) async {
      await _open(tester, makeMemory(id: 1, text: 'A plain note'));

      expect(find.text('Not detected'), findsNWidgets(4));
      expect(find.textContaining('View all memories about'), findsNothing);
      expect(find.text('General'), findsNWidgets(3));
    });

    testWidgets('shows the extracted date', (tester) async {
      await _open(
        tester,
        makeMemory(id: 1, extractedDate: DateTime(2026, 3, 1).toIso8601String()),
      );
      expect(find.text('March 1, 2026'), findsOneWidget);
    });

    testWidgets('shows how recent a new memory is', (tester) async {
      await _open(tester, makeMemory(id: 1, createdAt: DateTime.now()));
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('has no tag chips or follow-up card when there are none',
        (tester) async {
      await _open(tester, makeMemory(id: 1));

      expect(find.byType(Chip), findsNothing);
      expect(find.text('Pending follow-up'), findsNothing);
      expect(find.text('Attachments'), findsNothing);
    });

    testWidgets('offers "Add reminder" or "Change reminder"', (tester) async {
      await _open(tester, makeMemory(id: 1));
      expect(find.text('Add reminder'), findsOneWidget);
    });

    testWidgets('offers "Change reminder" when one is set', (tester) async {
      await _open(
        tester,
        makeMemory(id: 1, reminderAt: DateTime(2030, 1, 1).toIso8601String()),
      );
      expect(find.text('Change reminder'), findsOneWidget);
    });
  });

  group('follow-up', () {
    testWidgets('can be completed and reopened', (tester) async {
      final t = await _open(tester, _loan());
      expect(find.text('collect the money'), findsOneWidget);
      expect(find.text('Pending follow-up'), findsOneWidget);

      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Reopen'), findsOneWidget);
      expect(t.service.memories.single.taskStatus, 'completed');
      expect(t.db.rows.single.taskStatus, 'completed');

      await tester.tap(find.text('Reopen'));
      await tester.pumpAndSettle();

      expect(find.text('Pending follow-up'), findsOneWidget);
      expect(t.service.memories.single.taskStatus, 'pending');
    });
  });

  group('money', () {
    testWidgets('can be marked settled and open again', (tester) async {
      final t = await _open(tester, _loan());

      await tester.tap(find.text('Mark as settled'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as open'), findsOneWidget);
      expect(t.service.memories.single.moneyStatus, 'settled');

      await tester.tap(find.text('Mark as open'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as settled'), findsOneWidget);
      expect(t.service.memories.single.moneyStatus, 'open');
    });

    testWidgets('is not offered for other categories', (tester) async {
      await _open(tester, makeMemory(id: 1, category: 'places'));
      expect(find.text('Mark as settled'), findsNothing);
    });
  });

  group('menu', () {
    testWidgets('pin and unpin', (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Pin memory');
      expect(t.service.memories.single.isPinned, isTrue);

      await tester.tap(find.byTooltip('Memory actions'));
      await tester.pumpAndSettle();
      expect(find.text('Unpin memory'), findsOneWidget);
      await tester.tap(find.text('Unpin memory'));
      await tester.pumpAndSettle();
      expect(t.service.memories.single.isPinned, isFalse);
    });

    testWidgets('archive closes the screen and moves it out of the list',
        (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Archive memory');

      expect(find.byType(MemoryDetailScreen), findsNothing);
      expect(t.service.memories, isEmpty);
      expect(await t.service.getArchivedMemories(), hasLength(1));
    });

    testWidgets('delete asks first, and "Cancel" keeps the memory',
        (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Delete memory');
      expect(find.text('Delete this memory?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(MemoryDetailScreen), findsOneWidget);
      expect(t.service.memories, hasLength(1));
    });

    testWidgets('delete removes the memory and closes the screen',
        (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Delete memory');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(MemoryDetailScreen), findsNothing);
      expect(t.service.memories, isEmpty);
      expect(t.db.rows, isEmpty);
    });
  });

  group('editing the text', () {
    testWidgets('saves the new text and re-reads the details', (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Edit memory');
      await tester.enterText(find.byType(TextField), 'Paid Priya 200 rupees');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Paid Priya 200 rupees'), findsOneWidget);
      expect(find.text('Priya'), findsOneWidget);
      expect(t.service.memories.single.originalText, 'Paid Priya 200 rupees');
      expect(t.service.memories.single.person, 'Priya');
    });

    testWidgets('"Cancel" leaves the text unchanged', (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Edit memory');
      await tester.enterText(find.byType(TextField), 'something else');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('I lent Rahul 500 rupees'), findsOneWidget);
      expect(t.service.memories.single.originalText, 'I lent Rahul 500 rupees');
    });

    testWidgets('empty text is not saved', (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Edit memory');
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget); // still editing
      expect(t.service.memories.single.originalText, 'I lent Rahul 500 rupees');
    });

    testWidgets('a failed save shows an error and keeps editing',
        (tester) async {
      final t = await _open(tester, _loan(), failWrites: true);

      await _menu(tester, 'Edit memory');
      await tester.enterText(find.byType(TextField), 'new text');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Could not save changes. Please try again.'),
          findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(t.service.memories.single.originalText, 'I lent Rahul 500 rupees');
    });
  });

  group('editing the tags', () {
    testWidgets('saves a cleaned-up list and leaves the rest alone',
        (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Edit tags');
      expect(find.widgetWithText(TextField, 'loan'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'a, b, , a');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('#a'), findsOneWidget);
      expect(find.text('#b'), findsOneWidget);
      expect(find.text('#loan'), findsNothing);
      final saved = t.service.memories.single;
      expect(saved.tags, ['a', 'b']);
      expect(saved.originalText, 'I lent Rahul 500 rupees');
      expect(saved.taskStatus, 'pending');
    });

    testWidgets('all tags can be removed', (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Edit tags');
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(t.service.memories.single.tags, isEmpty);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('"Cancel" changes nothing', (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Edit tags');
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(t.service.memories.single.tags, ['loan']);
    });
  });

  group('correcting the details', () {
    // Fields in the dialog, in order: person, amount, date, location.
    Future<void> typeInto(WidgetTester tester, int field, String text) =>
        tester.enterText(find.byType(TextField).at(field), text);

    testWidgets('the person can be cleared', (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Correct details');
      await typeInto(tester, 0, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(t.service.memories.single.person, isNull);
      expect(t.db.rows.single.person, isNull);
      expect(find.text('Not detected'), findsWidgets);
      expect(find.textContaining('View all memories about'), findsNothing);
    });

    testWidgets('clearing details does not lose tags, follow-up or recurrence',
        (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Correct details');
      await typeInto(tester, 0, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = t.db.rows.single;
      expect(saved.tags, ['loan']);
      expect(saved.taskAction, 'collect the money');
      expect(saved.taskStatus, 'pending');
      expect(saved.recurrence, 'monthly');
      expect(find.text('#loan'), findsOneWidget);
      expect(find.text('Pending follow-up'), findsOneWidget);
    });

    testWidgets('the person, amount and location can be changed',
        (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Correct details');
      await typeInto(tester, 0, 'Meena');
      await typeInto(tester, 1, '750');
      await typeInto(tester, 3, 'Office');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = t.service.memories.single;
      expect(saved.person, 'Meena');
      expect(saved.amount, 750.0);
      expect(saved.location, 'Office');
      expect(saved.originalText, 'I lent Rahul 500 rupees');
      expect(saved.category, 'money');
    });

    testWidgets('the amount can be cleared', (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Correct details');
      await typeInto(tester, 1, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(t.service.memories.single.amount, isNull);
    });

    testWidgets('a valid date is saved', (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Correct details');
      await typeInto(tester, 2, '2026-03-01');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final date = DateTime.parse(t.service.memories.single.extractedDate!);
      expect([date.year, date.month, date.day], [2026, 3, 1]);
      expect(find.text('March 1, 2026'), findsOneWidget);
    });

    testWidgets('an invalid date is refused and nothing is saved',
        (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Correct details');
      await typeInto(tester, 0, 'Meena');
      await typeInto(tester, 2, 'next tuesday');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Use YYYY-MM-DD for the date.'), findsOneWidget);
      expect(t.service.memories.single.person, 'Rahul');
    });

    testWidgets('"Cancel" changes nothing', (tester) async {
      final t = await _open(tester, _loan());

      await _menu(tester, 'Correct details');
      await typeInto(tester, 0, 'Meena');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(t.service.memories.single.person, 'Rahul');
    });
  });
}
