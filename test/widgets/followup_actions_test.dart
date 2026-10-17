import 'package:did_i_tell_you/models/memory.dart';
import 'package:did_i_tell_you/screens/home_screen.dart';
import 'package:did_i_tell_you/screens/memory_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

DateTime _ahead(int days) => DateTime.now().add(Duration(days: days));
DateTime _ago(int days) => DateTime.now().subtract(Duration(days: days));

void main() {
  group('home screen follow-ups', () {
    testWidgets('marks an overdue follow-up and lists it first',
        (tester) async {
      final t = await makeService([
        makeMemory(
            text: 'newest',
            taskAction: 'newest task',
            taskStatus: 'pending',
            person: 'Priya',
            createdAt: DateTime.utc(2026, 1, 3)),
        makeMemory(
            text: 'middle',
            taskAction: 'middle task',
            taskStatus: 'pending',
            createdAt: DateTime.utc(2026, 1, 2)),
        makeMemory(
            text: 'oldest',
            taskAction: 'late task',
            taskStatus: 'pending',
            person: 'Ravi',
            reminderAt: _ago(2).toIso8601String(),
            createdAt: DateTime.utc(2026, 1, 1)),
      ]);
      await showScreen(tester, const HomeScreen(), memories: t.service);

      expect(find.text('Overdue · With Ravi'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('With Priya'), findsOneWidget);
      // Only two follow-ups fit; the overdue one displaces the middle one.
      expect(find.text('middle task'), findsNothing);
      expect(tester.getTopLeft(find.text('late task')).dy,
          lessThan(tester.getTopLeft(find.text('newest task')).dy));
    });

    testWidgets('shows plain "Overdue" when there is no person',
        (tester) async {
      final t = await makeService([
        makeMemory(
            text: 'x',
            taskAction: 'renew passport',
            taskStatus: 'pending',
            reminderAt: _ago(1).toIso8601String()),
      ]);
      await showScreen(tester, const HomeScreen(), memories: t.service);

      expect(find.text('Overdue · Pending'), findsOneWidget);
    });

    testWidgets('a follow-up with a future reminder is not marked',
        (tester) async {
      final t = await makeService([
        makeMemory(
            text: 'x',
            taskAction: 'renew passport',
            taskStatus: 'pending',
            reminderAt: _ahead(1).toIso8601String()),
      ]);
      await showScreen(tester, const HomeScreen(), memories: t.service);

      expect(find.text('Pending'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('memory detail: snooze and repeat', () {
    Future<({FakeDatabaseService db, FakeReminderService reminders})> open(
        WidgetTester tester, Memory memory) async {
      final t = await makeService([memory]);
      await openScreen(
        tester,
        MemoryDetailScreen(memory: t.service.memories.single),
        memories: t.service,
      );
      return (db: t.db, reminders: t.reminders);
    }

    testWidgets('a plain note has no snooze or repeat button',
        (tester) async {
      await open(tester, makeMemory(id: 1, text: 'just a note'));
      expect(find.text('Snooze'), findsNothing);
      expect(find.text('Does not repeat'), findsNothing);
    });

    testWidgets('snooze for an hour sets a reminder about an hour away',
        (tester) async {
      final t = await open(
          tester,
          makeMemory(
              id: 1,
              text: "I'll call the bank",
              taskAction: 'call the bank',
              taskStatus: 'pending'));
      expect(find.text('Add reminder'), findsOneWidget);

      await tester.tap(find.text('Snooze'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In 1 hour'));
      await tester.pumpAndSettle();

      expect(find.text('Change reminder'), findsOneWidget);
      final saved = DateTime.parse(t.db.rows.single.reminderAt!);
      final minutes = saved.difference(DateTime.now()).inMinutes;
      expect(minutes, inInclusiveRange(58, 60));
      expect(t.reminders.scheduled.single.time, saved);
    });

    testWidgets('snooze until tomorrow sets 9:00 tomorrow', (tester) async {
      final t = await open(
          tester,
          makeMemory(
              id: 1,
              text: "I'll call the bank",
              taskAction: 'call the bank',
              taskStatus: 'pending'));

      await tester.tap(find.text('Snooze'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow at 9:00'));
      await tester.pumpAndSettle();

      final saved = DateTime.parse(t.db.rows.single.reminderAt!);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(saved.day, tomorrow.day);
      expect(saved.hour, 9);
      expect(saved.minute, 0);
    });

    testWidgets('dismissing the snooze dialog changes nothing', (tester) async {
      final t = await open(
          tester,
          makeMemory(
              id: 1,
              text: "I'll call the bank",
              taskAction: 'call the bank',
              taskStatus: 'pending'));

      await tester.tap(find.text('Snooze'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // outside the dialog
      await tester.pumpAndSettle();

      expect(t.db.rows.single.reminderAt, isNull);
      expect(t.reminders.scheduled, isEmpty);
    });

    testWidgets('a reminder can be set to repeat, then set back to once',
        (tester) async {
      final when = _ahead(2);
      final t = await open(
          tester,
          makeMemory(
              id: 1, text: 'Water the plants', reminderAt: when.toIso8601String()));

      await tester.tap(find.text('Does not repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every week'));
      await tester.pumpAndSettle();

      expect(t.db.rows.single.recurrence, 'weekly');
      expect(t.reminders.scheduled.last.repeat, 'weekly');
      expect(find.text('Every week'), findsOneWidget); // the button now

      await tester.tap(find.text('Every week'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Does not repeat'));
      await tester.pumpAndSettle();

      expect(t.db.rows.single.recurrence, isNull);
      expect(t.reminders.scheduled.last.repeat, isNull);
      expect(find.text('Does not repeat'), findsOneWidget);
    });

    testWidgets('the repeat button only appears once there is a reminder',
        (tester) async {
      await open(
          tester,
          makeMemory(
              id: 1,
              text: "I'll call the bank",
              taskAction: 'call the bank',
              taskStatus: 'pending'));

      expect(find.text('Snooze'), findsOneWidget);
      expect(find.text('Does not repeat'), findsNothing);
    });
  });
}
