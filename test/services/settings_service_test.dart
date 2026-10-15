import 'package:did_i_tell_you/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('both settings start switched off', () {
    final settings = SettingsService();
    expect(settings.darkMode, isFalse);
    expect(settings.appLockEnabled, isFalse);
  });

  group('load', () {
    test('keeps the defaults when nothing was saved', () async {
      final settings = SettingsService();
      await settings.load();
      expect(settings.darkMode, isFalse);
      expect(settings.appLockEnabled, isFalse);
    });

    test('reads values saved earlier', () async {
      SharedPreferences.setMockInitialValues(
          {'dark_mode': true, 'app_lock': true});
      final settings = SettingsService();
      await settings.load();
      expect(settings.darkMode, isTrue);
      expect(settings.appLockEnabled, isTrue);
    });

    test('reads each setting independently', () async {
      SharedPreferences.setMockInitialValues({'dark_mode': true});
      final settings = SettingsService();
      await settings.load();
      expect(settings.darkMode, isTrue);
      expect(settings.appLockEnabled, isFalse);
    });

    test('tells listeners', () async {
      final settings = SettingsService();
      var calls = 0;
      settings.addListener(() => calls++);
      await settings.load();
      expect(calls, 1);
    });
  });

  group('setDarkMode', () {
    test('changes the value at once and tells listeners', () async {
      final settings = SettingsService();
      var calls = 0;
      settings.addListener(() => calls++);

      final done = settings.setDarkMode(true);
      expect(settings.darkMode, isTrue); // before the save finishes
      await done;

      expect(calls, 1);
    });

    test('is remembered by a new service after a restart', () async {
      await SettingsService().setDarkMode(true);

      final afterRestart = SettingsService();
      await afterRestart.load();

      expect(afterRestart.darkMode, isTrue);
      expect(afterRestart.appLockEnabled, isFalse);
    });

    test('can be switched back off', () async {
      final settings = SettingsService();
      await settings.setDarkMode(true);
      await settings.setDarkMode(false);

      final afterRestart = SettingsService();
      await afterRestart.load();
      expect(afterRestart.darkMode, isFalse);
    });
  });

  group('setAppLockEnabled', () {
    test('changes the value at once and tells listeners', () async {
      final settings = SettingsService();
      var calls = 0;
      settings.addListener(() => calls++);

      final done = settings.setAppLockEnabled(true);
      expect(settings.appLockEnabled, isTrue);
      await done;

      expect(calls, 1);
    });

    test('is remembered by a new service after a restart', () async {
      await SettingsService().setAppLockEnabled(true);

      final afterRestart = SettingsService();
      await afterRestart.load();

      expect(afterRestart.appLockEnabled, isTrue);
      expect(afterRestart.darkMode, isFalse);
    });

    test('does not disturb the dark mode setting', () async {
      final settings = SettingsService();
      await settings.setDarkMode(true);
      await settings.setAppLockEnabled(true);
      await settings.setAppLockEnabled(false);

      final afterRestart = SettingsService();
      await afterRestart.load();
      expect(afterRestart.darkMode, isTrue);
      expect(afterRestart.appLockEnabled, isFalse);
    });
  });
}
