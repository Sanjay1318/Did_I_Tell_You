import 'package:did_i_tell_you/screens/add_memory_screen.dart';
import 'package:did_i_tell_you/screens/all_memories_screen.dart';
import 'package:did_i_tell_you/screens/home_screen.dart';
import 'package:did_i_tell_you/screens/memory_detail_screen.dart';
import 'package:did_i_tell_you/screens/search_screen.dart';
import 'package:did_i_tell_you/widgets/memory_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

void main() {
  testWidgets('with no memories it invites the user to add one',
      (tester) async {
    final t = await makeService();
    await showScreen(tester, const HomeScreen(), memories: t.service);

    expect(find.text('What would you like to remember?'), findsOneWidget);
    expect(find.text('Ask your memory'), findsOneWidget);
    expect(find.text('Capture a memory by text, voice, or photo'),
        findsOneWidget);
    expect(find.text('New memory'), findsOneWidget);
    expect(find.text('Your memories will appear here'), findsOneWidget);
    expect(find.byType(MemoryCard), findsNothing);
    expect(find.text('Follow-ups'), findsNothing);
  });

  testWidgets('greets the user', (tester) async {
    final t = await makeService();
    await showScreen(tester, const HomeScreen(), memories: t.service);

    expect(find.textContaining('Good '), findsOneWidget);
    final greeting = tester.widget<Text>(find.textContaining('Good ')).data;
    expect(['Good morning', 'Good afternoon', 'Good evening'],
        contains(greeting));
  });

  testWidgets('shows only the three newest memories', (tester) async {
    final t = await makeService([
      for (var i = 1; i <= 5; i++)
        makeMemory(text: 'memory $i', createdAt: DateTime.utc(2026, 1, i)),
    ]);
    await showScreen(tester, const HomeScreen(), memories: t.service);

    expect(find.byType(MemoryCard), findsNWidgets(3));
    expect(find.text('memory 5'), findsOneWidget);
    expect(find.text('memory 4'), findsOneWidget);
    expect(find.text('memory 3'), findsOneWidget);
    expect(find.text('memory 2'), findsNothing);
    expect(find.text('memory 1'), findsNothing);
    expect(find.text('Your memories will appear here'), findsNothing);
  });

  testWidgets('a pinned memory is shown among the newest', (tester) async {
    final t = await makeService([
      makeMemory(text: 'old pinned', createdAt: DateTime.utc(2025, 1, 1), isPinned: true),
      for (var i = 1; i <= 3; i++)
        makeMemory(text: 'memory $i', createdAt: DateTime.utc(2026, 1, i)),
    ]);
    await showScreen(tester, const HomeScreen(), memories: t.service);

    expect(find.text('old pinned'), findsOneWidget);
    expect(find.text('memory 1'), findsNothing);
  });

  group('follow-ups', () {
    testWidgets('lists pending follow-ups with the person', (tester) async {
      final t = await makeService([
        makeMemory(
          text: "I'll send the resume to Ravi tomorrow",
          taskAction: 'send the resume',
          taskStatus: 'pending',
          person: 'Ravi',
        ),
      ]);
      await showScreen(tester, const HomeScreen(), memories: t.service);

      expect(find.text('Follow-ups'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // the count badge
      expect(find.text('send the resume'), findsOneWidget);
      expect(find.text('With Ravi'), findsOneWidget);
    });

    testWidgets('says "Pending" when there is no person', (tester) async {
      final t = await makeService([
        makeMemory(
            text: "I'll renew my passport",
            taskAction: 'renew my passport',
            taskStatus: 'pending'),
      ]);
      await showScreen(tester, const HomeScreen(), memories: t.service);

      expect(find.text('renew my passport'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('falls back to the memory text when there is no action',
        (tester) async {
      final t = await makeService([
        makeMemory(text: 'Something to do', taskStatus: 'pending'),
      ]);
      await showScreen(tester, const HomeScreen(), memories: t.service);

      // Once in the follow-up row and once in the recent list.
      expect(find.text('Something to do'), findsNWidgets(2));
    });

    testWidgets('shows at most two', (tester) async {
      final t = await makeService([
        for (var i = 1; i <= 3; i++)
          makeMemory(
            text: "I'll do job $i",
            taskAction: 'do job $i',
            taskStatus: 'pending',
            createdAt: DateTime.utc(2026, 1, i),
          ),
      ]);
      await showScreen(tester, const HomeScreen(), memories: t.service);

      expect(find.text('2'), findsOneWidget);
      expect(find.text('do job 3'), findsOneWidget);
      expect(find.text('do job 2'), findsOneWidget);
      expect(find.text('do job 1'), findsNothing);
    });

    testWidgets('completed and non-follow-up memories are not listed',
        (tester) async {
      final t = await makeService([
        makeMemory(
            text: 'done already',
            taskAction: 'done thing',
            taskStatus: 'completed'),
        makeMemory(text: 'ordinary note'),
      ]);
      await showScreen(tester, const HomeScreen(), memories: t.service);

      expect(find.text('Follow-ups'), findsNothing);
      expect(find.text('done thing'), findsNothing);
    });

    testWidgets('tapping one opens the memory', (tester) async {
      final t = await makeService([
        makeMemory(
            text: "I'll call the bank",
            taskAction: 'call the bank',
            taskStatus: 'pending'),
      ]);
      await showScreen(tester, const HomeScreen(), memories: t.service);

      await tester.tap(find.text('call the bank'));
      await tester.pumpAndSettle();

      expect(find.byType(MemoryDetailScreen), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('the New memory button opens the add screen', (tester) async {
      final t = await makeService();
      await showScreen(tester, const HomeScreen(), memories: t.service);

      await tester.tap(find.text('New memory'));
      await tester.pumpAndSettle();

      expect(find.byType(AddMemoryScreen), findsOneWidget);
    });

    testWidgets('the capture card opens the add screen', (tester) async {
      final t = await makeService();
      await showScreen(tester, const HomeScreen(), memories: t.service);

      await tester.tap(find.text('Capture a memory by text, voice, or photo'));
      await tester.pumpAndSettle();

      expect(find.byType(AddMemoryScreen), findsOneWidget);
    });

    testWidgets('"Ask your memory" opens search', (tester) async {
      final t = await makeService();
      await showScreen(tester, const HomeScreen(), memories: t.service);

      await tester.tap(find.text('Ask your memory'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('"View all" opens the full list', (tester) async {
      final t = await makeService();
      await showScreen(tester, const HomeScreen(), memories: t.service);

      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();

      expect(find.byType(AllMemoriesScreen), findsOneWidget);
    });

    testWidgets('tapping a recent memory opens it', (tester) async {
      final t = await makeService([makeMemory(text: 'Parked at Forum Mall')]);
      await showScreen(tester, const HomeScreen(), memories: t.service);

      await tester.tap(find.text('Parked at Forum Mall'));
      await tester.pumpAndSettle();

      expect(find.byType(MemoryDetailScreen), findsOneWidget);
    });
  });

  testWidgets('updates when a memory is added', (tester) async {
    final t = await makeService();
    await showScreen(tester, const HomeScreen(), memories: t.service);
    expect(find.text('Your memories will appear here'), findsOneWidget);

    await t.service.addMemory('Brand new thought');
    await tester.pump();

    expect(find.text('Brand new thought'), findsOneWidget);
    expect(find.text('Your memories will appear here'), findsNothing);
  });
}
