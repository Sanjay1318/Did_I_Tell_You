// End-to-end tests that run the real app, with a real database, on a phone or
// emulator:
//
//   flutter test integration_test
//
// Notifications are not initialised here: the Android permission pop-up it
// would open is outside Flutter and would stall the test.
import 'package:did_i_tell_you/app.dart';
import 'package:did_i_tell_you/screens/search_screen.dart';
import 'package:did_i_tell_you/services/database_service.dart';
import 'package:did_i_tell_you/services/memory_service.dart';
import 'package:did_i_tell_you/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

const _note = 'I lent Rahul 500 rupees';

/// Starts the app on a brand-new, empty database.
Future<DatabaseService> _freshDatabase() async {
  await deleteDatabase(p.join(await getDatabasesPath(), 'memory_app.db'));
  return DatabaseService();
}

Future<void> _launch(WidgetTester tester, DatabaseService database) async {
  await database.initDatabase();
  final memories = MemoryService(database);
  await memories.loadMemories();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MemoryService>.value(value: memories),
        ChangeNotifierProvider<SettingsService>(
            create: (_) => SettingsService()),
      ],
      child: const MemoryApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Waits (up to [timeout]) for [finder] to match. A real database answers in
/// real time, so a single pumpAndSettle can return before it has.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Taps "Save Memory". On a small phone screen the button can be below the
/// part of the list that is drawn, so scroll to it first.
Future<void> _tapSave(WidgetTester tester) async {
  final save = find.text('Save Memory');
  await tester.scrollUntilVisible(
    save,
    200,
    scrollable: find
        .descendant(
            of: find.byType(ListView), matching: find.byType(Scrollable))
        .first,
  );
  await tester.tap(save);
}

Finder _tab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add a memory, then find it by searching', (tester) async {
    final database = await _freshDatabase();
    await _launch(tester, database);
    expect(find.text('Your memories will appear here'), findsOneWidget);

    // Add the memory.
    await tester.tap(find.text('New memory'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, _note);
    await tester.pump();
    await _tapSave(tester);
    await _waitFor(tester, find.text('🧠 Memory saved!'));
    await tester.pumpAndSettle();

    // It is now listed on the home screen.
    expect(find.text(_note), findsOneWidget);

    // Search for it.
    await tester.tap(_tab('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rahul');
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();

    final inResults = find.descendant(
      of: find.byType(SearchScreen),
      matching: find.text(_note),
    );
    expect(inResults, findsOneWidget);
    expect(find.text('Found 1 memory.'), findsOneWidget);

    // A search that matches nothing says so.
    await tester.enterText(find.byType(TextField), 'zebra');
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();
    expect(find.text('No memories found'), findsOneWidget);

    await database.close();
  });

  testWidgets('a saved memory is still there after the app restarts',
      (tester) async {
    final first = await _freshDatabase();
    await _launch(tester, first);
    await tester.tap(find.text('New memory'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, _note);
    await tester.pump();
    await _tapSave(tester);
    await _waitFor(tester, find.text('🧠 Memory saved!'));
    await tester.pumpAndSettle();

    // "Close" the app and open it again on the same database file.
    await tester.pumpWidget(const SizedBox.shrink());
    await first.close();
    final second = DatabaseService();
    await _launch(tester, second);

    expect(find.text(_note), findsOneWidget);
    await second.close();
  });
}
