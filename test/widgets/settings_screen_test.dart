import 'package:did_i_tell_you/screens/archived_memories_screen.dart';
import 'package:did_i_tell_you/screens/settings_screen.dart';
import 'package:did_i_tell_you/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

// Sharing an export file and picking a backup file open the phone's own
// screens, so exporting and importing stay on the manual checklist. The pure
// file-building and file-reading logic is covered in export_service_test.dart.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows how many memories are stored', (tester) async {
    final t = await makeService([makeMemory(), makeMemory(), makeMemory()]);
    await showScreen(tester, const SettingsScreen(), memories: t.service);

    expect(find.text('3 memories stored'), findsOneWidget);
  });

  testWidgets('the dark mode switch changes the setting', (tester) async {
    final t = await makeService();
    final settings = SettingsService();
    await showScreen(tester, const SettingsScreen(),
        memories: t.service, settings: settings);

    await tester.tap(find.text('Dark mode'));
    await tester.pump();
    expect(settings.darkMode, isTrue);

    await tester.tap(find.text('Dark mode'));
    await tester.pump();
    expect(settings.darkMode, isFalse);
  });

  testWidgets('the app lock switch changes the setting', (tester) async {
    final t = await makeService();
    final settings = SettingsService();
    await showScreen(tester, const SettingsScreen(),
        memories: t.service, settings: settings);

    await tester.tap(find.text('App lock'));
    await tester.pump();

    expect(settings.appLockEnabled, isTrue);
    expect(settings.darkMode, isFalse);
  });

  testWidgets('switches show the saved settings', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'dark_mode': true, 'app_lock': false});
    final t = await makeService();
    final settings = SettingsService();
    await settings.load();
    await showScreen(tester, const SettingsScreen(),
        memories: t.service, settings: settings);

    final switches =
        tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    expect(switches.map((s) => s.value), [true, false]);
  });

  testWidgets('"Archived memories" opens the archive', (tester) async {
    final t = await makeService();
    await showScreen(tester, const SettingsScreen(), memories: t.service);

    await tester.tap(find.text('Archived memories'));
    await tester.pumpAndSettle();

    expect(find.byType(ArchivedMemoriesScreen), findsOneWidget);
  });

  group('delete all memories', () {
    testWidgets('asks first, and "Cancel" keeps everything', (tester) async {
      final t = await makeService([makeMemory(), makeMemory()]);
      await showScreen(tester, const SettingsScreen(), memories: t.service);

      await tester.tap(find.text('Delete All Memories'));
      await tester.pumpAndSettle();
      expect(find.text('Delete all memories?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(t.service.memories, hasLength(2));
      expect(find.text('All memories deleted.'), findsNothing);
    });

    testWidgets('confirming deletes everything and says so', (tester) async {
      final t = await makeService([makeMemory(), makeMemory()]);
      await showScreen(tester, const SettingsScreen(), memories: t.service);

      await tester.tap(find.text('Delete All Memories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete All'));
      await tester.pumpAndSettle();

      expect(t.service.memories, isEmpty);
      expect(t.db.rows, isEmpty);
      expect(find.text('All memories deleted.'), findsOneWidget);
      expect(find.text('0 memories stored'), findsOneWidget);
    });

    testWidgets('a failure is reported and nothing is lost', (tester) async {
      final t = await makeService([makeMemory()]);
      await showScreen(tester, const SettingsScreen(), memories: t.service);
      t.db.failWrites = true;

      await tester.tap(find.text('Delete All Memories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete All'));
      await tester.pumpAndSettle();

      expect(find.text('Could not delete memories. Please try again.'),
          findsOneWidget);
      expect(t.service.memories, hasLength(1));
    });
  });
}
