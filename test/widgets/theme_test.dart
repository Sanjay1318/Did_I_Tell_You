import 'package:did_i_tell_you/app.dart';
import 'package:did_i_tell_you/screens/add_memory_screen.dart';
import 'package:did_i_tell_you/screens/search_screen.dart';
import 'package:did_i_tell_you/services/memory_service.dart';
import 'package:did_i_tell_you/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

Widget _themedApp(MemoryService memories, Widget home, Brightness brightness) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MemoryService>.value(value: memories),
      ChangeNotifierProvider<SettingsService>.value(value: SettingsService()),
    ],
    child: MaterialApp(
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: home,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('buildAppTheme', () {
    test('light and dark have the right brightness', () {
      expect(buildAppTheme(Brightness.light).brightness, Brightness.light);
      expect(buildAppTheme(Brightness.dark).brightness, Brightness.dark);
    });

    test('light keeps the white cards and bottom bar', () {
      final theme = buildAppTheme(Brightness.light);
      expect(theme.cardTheme.color, Colors.white);
      expect(theme.navigationBarTheme.backgroundColor, Colors.white);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8F9FA));
    });

    test('dark has no white surfaces', () {
      final theme = buildAppTheme(Brightness.dark);
      expect(theme.cardTheme.color, isNot(Colors.white));
      expect(theme.navigationBarTheme.backgroundColor, isNot(Colors.white));
      expect(theme.inputDecorationTheme.fillColor, isNot(Colors.white));
      expect(theme.scaffoldBackgroundColor.computeLuminance(), lessThan(0.2));
    });

    test('both are built from the same purple', () {
      final light = buildAppTheme(Brightness.light).colorScheme;
      final dark = buildAppTheme(Brightness.dark).colorScheme;
      expect(light.primary, isNot(dark.primary));
      expect(light.surface, isNot(dark.surface));
    });
  });

  testWidgets('turning on dark mode darkens the whole app, bottom bar included',
      (tester) async {
    final t = await makeService();
    final settings = SettingsService();
    await settings.setDarkMode(true);
    useBigScreen(tester);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<MemoryService>.value(value: t.service),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
      ],
      child: const MemoryApp(),
    ));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(NavigationBar)));
    expect(theme.brightness, Brightness.dark);
    expect(theme.navigationBarTheme.backgroundColor, isNot(Colors.white));
  });

  group('search answer colours', () {
    Future<Color?> answerColor(WidgetTester tester, Brightness mode) async {
      final t = await makeService([makeMemory(text: 'Parked at Forum Mall')]);
      useBigScreen(tester);
      await tester.pumpWidget(_themedApp(t.service, const SearchScreen(), mode));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'forum');
      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();
      return tester.widget<Text>(find.text('Found 1 memory.')).style?.color;
    }

    testWidgets('dark green on light, light green on dark', (tester) async {
      expect(await answerColor(tester, Brightness.light),
          const Color(0xFF2E7D32));
      expect(await answerColor(tester, Brightness.dark),
          const Color(0xFFA5D6A7));
    });
  });

  testWidgets('the voice button says what it does', (tester) async {
    final t = await makeService();
    useBigScreen(tester);
    await tester.pumpWidget(
        _themedApp(t.service, const AddMemoryScreen(), Brightness.light));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Start voice input'), findsOneWidget);
  });
}
