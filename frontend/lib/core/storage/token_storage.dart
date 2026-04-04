/// Platform-appropriate token persistence.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin read/write/delete interface for token storage.
abstract interface class TokenStorage {
  /// Returns the singleton appropriate for the current platform.
  static TokenStorage get instance => _instance;

  static final TokenStorage _instance = _resolve();

  static TokenStorage _resolve() {
    if (!kIsWeb && Platform.isMacOS) return const _PrefsStorage();
    return const _SecureStorage();
  }

  /// Read a value by [key].
  Future<String?> read(String key);

  /// Write [value] under [key].
  Future<void> write(String key, String value);

  /// Delete the entry for [key].
  Future<void> delete(String key);
}

/// Keychain / Keystore-backed storage (iOS, Android, web, etc.).
class _SecureStorage implements TokenStorage {
  const _SecureStorage();

  static const _store = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _store.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _store.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _store.delete(key: key);
}

/// SharedPreferences-backed storage for macOS (no signing required).
class _PrefsStorage implements TokenStorage {
  const _PrefsStorage();

  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
