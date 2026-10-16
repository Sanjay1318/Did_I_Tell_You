import 'package:did_i_tell_you/screens/all_memories_screen.dart';
import 'package:did_i_tell_you/screens/memory_detail_screen.dart';
import 'package:did_i_tell_you/services/category_classifier.dart';
import 'package:did_i_tell_you/widgets/memory_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

final _seed = [
  makeMemory(
      text: 'I lent Rahul 500 rupees',
      person: 'Rahul',
      category: 'money',
      createdAt: DateTime.utc(2026, 1, 3)),
  makeMemory(
      text: 'Priya owes me 200 rupees',
      person: 'Priya',
      category: 'money',
      createdAt: DateTime.utc(2026, 1, 2)),
  makeMemory(
      text: 'Parked at Forum Mall',
      category: 'places',
      createdAt: DateTime.utc(2026, 1, 1)),
];

Future<void> _pick(WidgetTester tester, int dropdown, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<String?>).at(dropdown));
  await tester.pumpAndSettle();
  // The closed dropdown also builds every item, so the open menu's copy is
  // the last one in the tree.
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

String _categoryItem(String category) =>
    '${CategoryClassifier.getCategoryIcon(category)} '
    '${CategoryClassifier.getCategoryLabel(category)}';

void main() {
  testWidgets('shows every memory and the count to begin with',
      (tester) async {
    final t = await makeService(_seed);
    await showScreen(tester, const AllMemoriesScreen(), memories: t.service);

    expect(find.byType(MemoryCard), findsNWidgets(3));
    expect(find.text('3 memories'), findsOneWidget);
    expect(find.byTooltip('Clear filters'), findsNothing);
  });

  testWidgets('filters by category', (tester) async {
    final t = await makeService(_seed);
    await showScreen(tester, const AllMemoriesScreen(), memories: t.service);

    await _pick(tester, 0, _categoryItem('places'));

    expect(find.byType(MemoryCard), findsOneWidget);
    expect(find.text('Parked at Forum Mall'), findsOneWidget);
    expect(find.text('1 memory'), findsOneWidget);
    expect(find.byTooltip('Clear filters'), findsOneWidget);
  });

  testWidgets('filters by person', (tester) async {
    final t = await makeService(_seed);
    await showScreen(tester, const AllMemoriesScreen(), memories: t.service);

    await _pick(tester, 1, 'Priya');

    expect(find.byType(MemoryCard), findsOneWidget);
    expect(find.text('Priya owes me 200 rupees'), findsOneWidget);
    expect(find.text('1 memory'), findsOneWidget);
  });

  testWidgets('category and person filters combine', (tester) async {
    final t = await makeService(_seed);
    await showScreen(tester, const AllMemoriesScreen(), memories: t.service);

    await _pick(tester, 0, _categoryItem('money'));
    expect(find.text('2 memories'), findsOneWidget);
    await _pick(tester, 1, 'Rahul');

    expect(find.byType(MemoryCard), findsOneWidget);
    expect(find.text('I lent Rahul 500 rupees'), findsOneWidget);
  });

  testWidgets('a filter with no matches shows the empty message',
      (tester) async {
    final t = await makeService(_seed);
    await showScreen(tester, const AllMemoriesScreen(), memories: t.service);

    await _pick(tester, 0, _categoryItem('places'));
    await _pick(tester, 1, 'Rahul');

    expect(find.byType(MemoryCard), findsNothing);
    expect(find.text('No memories found'), findsOneWidget);
    expect(find.text('Try changing the filters above'), findsOneWidget);
    expect(find.text('0 memories'), findsOneWidget);
  });

  testWidgets('clear filters brings every memory back', (tester) async {
    final t = await makeService(_seed);
    await showScreen(tester, const AllMemoriesScreen(), memories: t.service);
    await _pick(tester, 0, _categoryItem('places'));

    await tester.tap(find.byTooltip('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryCard), findsNWidgets(3));
    expect(find.byTooltip('Clear filters'), findsNothing);
  });

  testWidgets('tapping a memory opens its details', (tester) async {
    final t = await makeService(_seed);
    await showScreen(tester, const AllMemoriesScreen(), memories: t.service);

    await tester.tap(find.text('Parked at Forum Mall'));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryDetailScreen), findsOneWidget);
  });
}
