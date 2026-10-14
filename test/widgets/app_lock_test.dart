import 'package:did_i_tell_you/services/settings_service.dart';
import 'package:did_i_tell_you/widgets/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The real unlock screen of the phone cannot be driven from a test, so these
// tests replace it with a stand-in that says yes, no, or fails. Whether the
// device's own fingerprint / PIN prompt appears stays on the manual checklist.
const _secret = 'SECRET CONTENT';

Widget _app(SettingsService settings, {Authenticator? authenticator}) {
  return ChangeNotifierProvider<SettingsService>.value(
    value: settings,
    child: MaterialApp(
      home: AppLock(authenticator: authenticator, child: const Text(_secret)),
    ),
  );
}

Future<SettingsService> _settings({required bool lockOn}) async {
  SharedPreferences.setMockInitialValues({'app_lock': lockOn});
  final settings = SettingsService();
  await settings.load();
  return settings;
}

void main() {
  testWidgets('shows the content when the lock is switched off',
      (tester) async {
    var asked = 0;
    final settings = await _settings(lockOn: false);

    await tester.pumpWidget(_app(settings, authenticator: () async {
      asked++;
      return true;
    }));

    expect(find.text(_secret), findsOneWidget);
    expect(find.text('Your memories are locked'), findsNothing);
    expect(asked, 0);
  });

  testWidgets('hides the content behind a lock screen when switched on',
      (tester) async {
    final settings = await _settings(lockOn: true);

    await tester.pumpWidget(_app(settings, authenticator: () async => true));

    expect(find.text(_secret), findsNothing);
    expect(find.text('Your memories are locked'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Use your device screen lock to continue.'), findsNothing);
  });

  testWidgets('does not ask for authentication until Unlock is pressed',
      (tester) async {
    var asked = 0;
    final settings = await _settings(lockOn: true);

    await tester.pumpWidget(_app(settings, authenticator: () async {
      asked++;
      return true;
    }));
    await tester.pump();

    expect(asked, 0);
  });

  testWidgets('a successful unlock shows the content', (tester) async {
    var asked = 0;
    final settings = await _settings(lockOn: true);
    await tester.pumpWidget(_app(settings, authenticator: () async {
      asked++;
      return true;
    }));

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(asked, 1);
    expect(find.text(_secret), findsOneWidget);
    expect(find.text('Your memories are locked'), findsNothing);
  });

  testWidgets('a refused unlock stays locked and shows a hint',
      (tester) async {
    final settings = await _settings(lockOn: true);
    await tester.pumpWidget(_app(settings, authenticator: () async => false));

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text(_secret), findsNothing);
    expect(find.text('Your memories are locked'), findsOneWidget);
    expect(find.text('Use your device screen lock to continue.'),
        findsOneWidget);
  });

  testWidgets('an error while authenticating stays locked and shows the hint',
      (tester) async {
    final settings = await _settings(lockOn: true);
    await tester.pumpWidget(_app(settings,
        authenticator: () async => throw StateError('no screen lock set')));

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text(_secret), findsNothing);
    expect(find.text('Use your device screen lock to continue.'),
        findsOneWidget);
  });

  testWidgets('you can try again after a refusal', (tester) async {
    final answers = [false, true];
    final settings = await _settings(lockOn: true);
    await tester.pumpWidget(
        _app(settings, authenticator: () async => answers.removeAt(0)));

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text(_secret), findsNothing);

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text(_secret), findsOneWidget);
  });

  testWidgets('switching the lock on later locks the screen', (tester) async {
    final settings = await _settings(lockOn: false);
    await tester.pumpWidget(_app(settings, authenticator: () async => true));
    expect(find.text(_secret), findsOneWidget);

    await settings.setAppLockEnabled(true);
    await tester.pump();

    expect(find.text(_secret), findsNothing);
    expect(find.text('Your memories are locked'), findsOneWidget);
  });

  testWidgets('switching the lock off shows the content again',
      (tester) async {
    final settings = await _settings(lockOn: true);
    await tester.pumpWidget(_app(settings, authenticator: () async => false));
    expect(find.text(_secret), findsNothing);

    await settings.setAppLockEnabled(false);
    await tester.pump();

    expect(find.text(_secret), findsOneWidget);
  });

  testWidgets('once unlocked it stays unlocked when other settings change',
      (tester) async {
    final settings = await _settings(lockOn: true);
    await tester.pumpWidget(_app(settings, authenticator: () async => true));
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    await settings.setDarkMode(true);
    await tester.pump();

    expect(find.text(_secret), findsOneWidget);
  });
}
