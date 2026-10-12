import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const _darkModeKey = 'dark_mode';
  static const _appLockKey = 'app_lock';
  bool _darkMode = false;
  bool _appLockEnabled = false;

  bool get darkMode => _darkMode;
  bool get appLockEnabled => _appLockEnabled;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _darkMode = preferences.getBool(_darkModeKey) ?? false;
    _appLockEnabled = preferences.getBool(_appLockKey) ?? false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_darkModeKey, value);
  }

  Future<void> setAppLockEnabled(bool value) async {
    _appLockEnabled = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_appLockKey, value);
  }
}
