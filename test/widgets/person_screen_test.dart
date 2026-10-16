import 'package:did_i_tell_you/screens/memory_detail_screen.dart';
import 'package:did_i_tell_you/screens/person_screen.dart';
import 'package:did_i_tell_you/widgets/memory_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

void main() {
  testWidgets('shows only this person\'s memories, matching any letter case',
      (tester) async {
    final t = await makeService([
      makeMemory(
          text: 'I lent Rahul 500 rupees',
          person: 'Rahul',
          category: 'money',
          createdAt: DateTime.utc(2026, 1, 1)),
      makeMemory(
          text: 'rahul likes tea',
          person: 'rahul',
          category: 'people',
          createdAt: DateTime.utc(2026, 1, 2)),
      makeMemory(text: 'Priya owes me 200 rupees', person: 'Priya'),
      makeMemory(text: 'Parked at Forum Mall'),
    ]);
    await showScreen(tester, const PersonScreen(personName: 'Rahul'),
        memories: t.service);

    expect(find.text('2 memories'), findsOneWidget);
    expect(find.byType(MemoryCard), findsNWidgets(2));
    expect(find.text('I lent Rahul 500 rupees'), findsOneWidget);
    expect(find.text('rahul likes tea'), findsOneWidget);
    expect(find.text('Priya owes me 200 rupees'), findsNothing);
    expect(find.text('Parked at Forum Mall'), findsNothing);
  });

  testWidgets('lists the newest memory first', (tester) async {
    final t = await makeService([
      makeMemory(
          text: 'older note', person: 'Rahul', createdAt: DateTime.utc(2026, 1, 1)),
      makeMemory(
          text: 'newer note', person: 'Rahul', createdAt: DateTime.utc(2026, 1, 2)),
    ]);
    await showScreen(tester, const PersonScreen(personName: 'Rahul'),
        memories: t.service);

    expect(tester.getTopLeft(find.text('newer note')).dy,
        lessThan(tester.getTopLeft(find.text('older note')).dy));
  });

  testWidgets('counts the memories in each category', (tester) async {
    final t = await makeService([
      makeMemory(text: 'a', person: 'Rahul', category: 'money'),
      makeMemory(text: 'b', person: 'Rahul', category: 'money'),
      makeMemory(text: 'c', person: 'Rahul', category: 'people'),
    ]);
    await showScreen(tester, const PersonScreen(personName: 'Rahul'),
        memories: t.service);

    expect(find.text('📂 Categories'), findsOneWidget);
    expect(find.text('Money (2)'), findsOneWidget);
    expect(find.text('People (1)'), findsOneWidget);
  });

  testWidgets('a person with no memories gets a friendly note',
      (tester) async {
    final t = await makeService([makeMemory(text: 'x', person: 'Priya')]);
    await showScreen(tester, const PersonScreen(personName: 'Zed'),
        memories: t.service);

    expect(find.text('0 memories'), findsOneWidget);
    expect(find.text('No memories about Zed yet.'), findsOneWidget);
    expect(find.text('📂 Categories'), findsNothing);
    expect(find.byType(MemoryCard), findsNothing);
  });

  testWidgets('shows the first letter of the name in the avatar',
      (tester) async {
    final t = await makeService();
    await showScreen(tester, const PersonScreen(personName: 'zed'),
        memories: t.service);

    expect(find.text('Z'), findsOneWidget);
  });

  testWidgets('tapping a memory opens its details', (tester) async {
    final t = await makeService([
      makeMemory(text: 'I lent Rahul 500 rupees', person: 'Rahul'),
    ]);
    await showScreen(tester, const PersonScreen(personName: 'Rahul'),
        memories: t.service);

    await tester.tap(find.text('I lent Rahul 500 rupees'));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryDetailScreen), findsOneWidget);
  });
}
