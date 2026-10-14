import 'package:did_i_tell_you/services/memory_service.dart';
import 'package:did_i_tell_you/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Makes the test window big enough that nothing is scrolled out of view.
void useBigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Wraps [child] in the app's providers and a MaterialApp.
Widget appAround(
  Widget child, {
  required MemoryService memories,
  SettingsService? settings,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MemoryService>.value(value: memories),
      ChangeNotifierProvider<SettingsService>.value(
          value: settings ?? SettingsService()),
    ],
    child: MaterialApp(home: child),
  );
}

/// Shows [screen] as a page opened from a plain home page, so screens that
/// close themselves with Navigator.pop behave as they do in the app.
Future<void> openScreen(
  WidgetTester tester,
  Widget screen, {
  required MemoryService memories,
  SettingsService? settings,
}) async {
  useBigScreen(tester);
  await tester.pumpWidget(appAround(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => screen),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    memories: memories,
    settings: settings,
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Shows [screen] directly as the home page.
Future<void> showScreen(
  WidgetTester tester,
  Widget screen, {
  required MemoryService memories,
  SettingsService? settings,
}) async {
  useBigScreen(tester);
  await tester.pumpWidget(
      appAround(screen, memories: memories, settings: settings));
  await tester.pumpAndSettle();
}

/// The "Save Memory"-style button that holds [label], whatever its subtype.
ButtonStyleButton buttonWithLabel(WidgetTester tester, String label) {
  return tester.widget<ButtonStyleButton>(find.ancestor(
    of: find.text(label),
    matching: find.bySubtype<ButtonStyleButton>(),
  ));
}
