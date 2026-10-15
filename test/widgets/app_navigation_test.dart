import 'package:did_i_tell_you/app.dart';
import 'package:did_i_tell_you/services/memory_service.dart';
import 'package:did_i_tell_you/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

Widget _wholeApp(MemoryService memories, SettingsService settings) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MemoryService>.value(value: memories),
      ChangeNotifierProvider<SettingsService>.value(value: settings),
    ],
    child: const MemoryApp(),
  );
}

Finder _tab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

// The Search tab's sort dropdown contains an IndexedStack of its own, so pick
// out the one that holds the four tabs.
int _selectedTab(WidgetTester tester) => tester
    .widget<IndexedStack>(find.byWidgetPredicate(
        (widget) => widget is IndexedStack && widget.children.length == 4))
    .index!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opens on the Home tab', (tester) async {
    final t = await makeService();
    useBigScreen(tester);
    await tester.pumpWidget(_wholeApp(t.service, SettingsService()));
    await tester.pumpAndSettle();

    expect(_selectedTab(tester), 0);
    expect(find.text('What would you like to remember?'), findsOneWidget);
  });

  testWidgets('the bottom bar switches between the four tabs', (tester) async {
    final t = await makeService();
    useBigScreen(tester);
    await tester.pumpWidget(_wholeApp(t.service, SettingsService()));
    await tester.pumpAndSettle();

    await tester.tap(_tab('Search'));
    await tester.pumpAndSettle();
    expect(_selectedTab(tester), 1);
    expect(find.text('Search your memories naturally'), findsOneWidget);

    await tester.tap(_tab('Timeline'));
    await tester.pumpAndSettle();
    expect(_selectedTab(tester), 2);
    expect(find.text('Your timeline will appear here'), findsOneWidget);

    await tester.tap(_tab('Settings'));
    await tester.pumpAndSettle();
    expect(_selectedTab(tester), 3);
    expect(find.text('Total Memories'), findsOneWidget);

    await tester.tap(_tab('Home'));
    await tester.pumpAndSettle();
    expect(_selectedTab(tester), 0);
  });

  testWidgets('a memory shows on Home and on the Timeline under "Today"',
      (tester) async {
    final t = await makeService([
      makeMemory(text: 'Parked at Forum Mall', createdAt: DateTime.now()),
    ]);
    useBigScreen(tester);
    await tester.pumpWidget(_wholeApp(t.service, SettingsService()));
    await tester.pumpAndSettle();
    expect(find.text('Parked at Forum Mall'), findsOneWidget);

    await tester.tap(_tab('Timeline'));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Parked at Forum Mall'), findsOneWidget);
  });

  testWidgets('dark mode switches the theme', (tester) async {
    final t = await makeService();
    final settings = SettingsService();
    useBigScreen(tester);
    await tester.pumpWidget(_wholeApp(t.service, settings));
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light);

    await settings.setDarkMode(true);
    await tester.pumpAndSettle();

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark);
  });

  testWidgets('with the app lock on, the lock screen replaces the app',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_lock': true});
    final t = await makeService();
    final settings = SettingsService();
    await settings.load();
    useBigScreen(tester);
    await tester.pumpWidget(_wholeApp(t.service, settings));
    await tester.pumpAndSettle();

    expect(find.text('Your memories are locked'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
