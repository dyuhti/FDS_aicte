import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class FixedClock implements Clock {
  FixedClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

abstract interface class LocalStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}

class MemoryLocalStorage implements LocalStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();
}

class SharedPreferencesLocalStorage implements LocalStorage {
  SharedPreferencesLocalStorage(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesLocalStorage> create() async =>
      SharedPreferencesLocalStorage(await SharedPreferences.getInstance());

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _preferences.remove(key);
  }

  @override
  Future<void> clear() async {
    await _preferences.clear();
  }
}

Future<Map<String, dynamic>?> readJson(
  LocalStorage storage,
  String key,
) async {
  final raw = await storage.read(key);
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw);
  return decoded is Map<String, dynamic> ? decoded : null;
}

abstract interface class AuthService {
  Future<bool> authenticate(String userId, String password);
  Future<void> signOut();
}

class DemoAuthService implements AuthService {
  const DemoAuthService();

  @override
  Future<bool> authenticate(String userId, String password) async =>
      userId == 'officer-123' && password == 'demo-password';

  @override
  Future<void> signOut() async {}
}