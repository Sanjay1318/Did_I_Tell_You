import 'package:did_i_tell_you/models/memory.dart';
import 'package:did_i_tell_you/screens/memory_detail_screen.dart';
import 'package:did_i_tell_you/screens/search_screen.dart';
import 'package:did_i_tell_you/widgets/memory_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

// Reading the answer aloud needs the phone's speech engine, so the speaker
// button stays on the manual checklist.
List<Memory> _seed() => [
      makeMemory(
        text: 'I lent Rahul 500 rupees',
        category: 'money',
        person: 'Rahul',
        amount: 500,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      makeMemory(
        text: 'Priya owes me 200 rupees',
        category: 'money',
        person: 'Priya',
        amount: 200,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      makeMemory(
        text: 'Parked at Forum Mall',
        category: 'places',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

Finder searchButton() => find.widgetWithText(FilledButton, 'Search');

List<String> shownTexts(WidgetTester tester) => tester
    .widgetList<MemoryCard>(find.byType(MemoryCard))
    .map((card) => card.memory.originalText)
    .toList();

void main() {
  testWidgets('starts with a hint and no results', (tester) async {
    final t = await makeService(_seed());
    await showScreen(tester, const SearchScreen(), memories: t.service);

    expect(find.text('Search your memories naturally'), findsOneWidget);
    expect(find.byType(MemoryCard), findsNothing);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Newest'), findsOneWidget);
  });

  testWidgets('"who owes me" lists who owes what and shows the matching memories',
      (tester) async {
    final t = await makeService(_seed());
    await showScreen(tester, const SearchScreen(), memories: t.service);

    await tester.enterText(find.byType(TextField), 'Who owes me money?');
    await tester.tap(searchButton());
    await tester.pumpAndSettle();

    expect(find.textContaining('Rahul owes you ₹500'), findsOneWidget);
    expect(find.textContaining('Priya owes you ₹200'), findsOneWidget);
    expect(shownTexts(tester),
        ['I lent Rahul 500 rupees', 'Priya owes me 200 rupees']);
    expect(find.text('💡'), findsOneWidget);
  });

  testWidgets('pressing the keyboard\'s search key also searches',
      (tester) async {
    final t = await makeService(_seed());
    await showScreen(tester, const SearchScreen(), memories: t.service);

    await tester.enterText(find.byType(TextField), 'forum');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(shownTexts(tester), ['Parked at Forum Mall']);
  });

  testWidgets('a plain word searches the text and counts the results',
      (tester) async {
    final t = await makeService(_seed());
    await showScreen(tester, const SearchScreen(), memories: t.service);

    await tester.enterText(find.byType(TextField), 'forum');
    await tester.tap(searchButton());
    await tester.pumpAndSettle();

    expect(find.text('Found 1 memory.'), findsOneWidget);
    expect(shownTexts(tester), ['Parked at Forum Mall']);
  });

  testWidgets('says so when nothing matches', (tester) async {
    final t = await makeService(_seed());
    await showScreen(tester, const SearchScreen(), memories: t.service);

    await tester.enterText(find.byType(TextField), 'zebra');
    await tester.tap(searchButton());
    await tester.pumpAndSettle();

    expect(find.text('No memories found'), findsOneWidget);
    expect(find.byType(MemoryCard), findsNothing);
    expect(find.text('💡'), findsNothing);
  });

  testWidgets('an empty search lists everything, newest first',
      (tester) async {
    final t = await makeService(_seed());
    await showScreen(tester, const SearchScreen(), memories: t.service);

    await tester.tap(searchButton());
    await tester.pumpAndSettle();

    expect(find.text('Found 3 memories.'), findsOneWidget);
    expect(shownTexts(tester), [
      'Parked at Forum Mall',
      'I lent Rahul 500 rupees',
      'Priya owes me 200 rupees',
    ]);
  });

  testWidgets('searching an empty app shows "No memories found"',
      (tester) async {
    final t = await makeService();
    await showScreen(tester, const SearchScreen(), memories: t.service);

    await tester.tap(searchButton());
    await tester.pumpAndSettle();

    expect(find.text('No memories found'), findsOneWidget);
  });

  testWidgets('a question opened with a ready-made query runs at once',
      (tester) async {
    final t = await makeService(_seed());
    await showScreen(tester, const SearchScreen(initialQuery: 'forum'),
        memories: t.service);

    expect(shownTexts(tester), ['Parked at Forum Mall']);
    expect(find.widgetWithText(TextField, 'forum'), findsOneWidget);
  });

  testWidgets('a new search replaces the old results', (tester) async {
    final t = await makeService(_seed());
    await showScreen(tester, const SearchScreen(), memories: t.service);

    await tester.enterText(find.byType(TextField), 'forum');
    await tester.tap(searchButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'priya');
    await tester.tap(searchButton());
    await tester.pumpAndSettle();

    expect(shownTexts(tester), ['Priya owes me 200 rupees']);
  });

  testWidgets('tapping a result opens the memory', (tester) async {
    final t = await makeService(_seed());
    await showScreen(tester, const SearchScreen(), memories: t.service);

    await tester.enterText(find.byType(TextField), 'forum');
    await tester.tap(searchButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parked at Forum Mall'));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryDetailScreen), findsOneWidget);
  });

  group('sorting', () {
    Future<void> sortBy(WidgetTester tester, String label) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('oldest first', (tester) async {
      final t = await makeService(_seed());
      await showScreen(tester, const SearchScreen(), memories: t.service);

      await sortBy(tester, 'Oldest');

      expect(shownTexts(tester), [
        'Priya owes me 200 rupees',
        'I lent Rahul 500 rupees',
        'Parked at Forum Mall',
      ]);
    });

    testWidgets('highest amount first, memories without an amount last',
        (tester) async {
      final t = await makeService(_seed());
      await showScreen(tester, const SearchScreen(), memories: t.service);

      await sortBy(tester, 'Amount: high to low');

      expect(shownTexts(tester), [
        'I lent Rahul 500 rupees',
        'Priya owes me 200 rupees',
        'Parked at Forum Mall',
      ]);
    });

    testWidgets('lowest amount first, memories without an amount last',
        (tester) async {
      final t = await makeService(_seed());
      await showScreen(tester, const SearchScreen(), memories: t.service);

      await sortBy(tester, 'Amount: low to high');

      expect(shownTexts(tester), [
        'Priya owes me 200 rupees',
        'I lent Rahul 500 rupees',
        'Parked at Forum Mall',
      ]);
    });
  });

  group('filters', () {
    testWidgets('a minimum amount hides smaller and missing amounts',
        (tester) async {
      final t = await makeService(_seed());
      await showScreen(tester, const SearchScreen(), memories: t.service);

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Minimum amount'), '300');
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(shownTexts(tester), ['I lent Rahul 500 rupees']);
      expect(find.text('Filters active'), findsOneWidget);
    });

    testWidgets('a maximum amount hides larger and missing amounts',
        (tester) async {
      final t = await makeService(_seed());
      await showScreen(tester, const SearchScreen(), memories: t.service);

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Maximum amount'), '300');
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(shownTexts(tester), ['Priya owes me 200 rupees']);
    });
  });
}
