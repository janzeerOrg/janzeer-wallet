import 'dart:convert';

import 'package:get_secure_storage/get_secure_storage.dart';

import '../config/app_config.dart';

/// Encrypted-at-rest key/value store (get_secure_storage). Holds the password-encrypted vault blob and
/// non-secret prefs (theme, locale, node URL, lock mode). The vault is ALSO password-encrypted on top of
/// this (defence in depth) — see [core/crypto/vault.dart].
class SecureStore {
  static final GetSecureStorage _box = GetSecureStorage();

  static Future<void> init() => GetSecureStorage.init();

  static const _kVault = 'vault';
  static const _kAddress = 'address';
  static const _kThemePreset = 'themePreset';
  static const _kThemeDark = 'themeDark';
  static const _kLocale = 'locale';
  static const _kNodeUrl = 'nodeUrl';
  static const _kLockMode = 'lockMode';
  static const _kCachedPassword = 'cachedPassword';

  // Vault (encrypted mnemonic blob) + the public address (shown while locked).
  static Map<String, dynamic>? get vault {
    final raw = _box.read(_kVault);
    return raw == null ? null : jsonDecode(raw as String) as Map<String, dynamic>;
  }

  static set vault(Map<String, dynamic>? v) =>
      v == null ? _box.remove(_kVault) : _box.write(_kVault, jsonEncode(v));

  static String get address => _box.read(_kAddress) as String? ?? '';
  static set address(String v) => _box.write(_kAddress, v);

  // Prefs
  static int get themePreset => _box.read(_kThemePreset) as int? ?? 0;
  static set themePreset(int v) => _box.write(_kThemePreset, v);

  static bool get themeDark => _box.read(_kThemeDark) as bool? ?? false;
  static set themeDark(bool v) => _box.write(_kThemeDark, v);

  static String get locale => _box.read(_kLocale) as String? ?? 'en';
  static set locale(String v) => _box.write(_kLocale, v);

  static String get nodeUrl => _box.read(_kNodeUrl) as String? ?? AppConfig.defaultNodeUrl;
  static set nodeUrl(String v) => _box.write(_kNodeUrl, v);

  /// App-lock mode: 'none' | 'pin' | 'biometric'.
  static String get lockMode => _box.read(_kLockMode) as String? ?? 'none';
  static set lockMode(String v) => _box.write(_kLockMode, v);

  /// The vault password cached behind the app-lock (so the user doesn't retype it each launch). Only set
  /// when an app-lock is enabled; cleared when the lock is removed. PIN is stored here too (as the lock).
  static String? get cachedPassword => _box.read(_kCachedPassword) as String?;
  static set cachedPassword(String? v) =>
      v == null ? _box.remove(_kCachedPassword) : _box.write(_kCachedPassword, v);

  static void clearWallet() {
    _box.remove(_kVault);
    _box.remove(_kAddress);
    _box.remove(_kCachedPassword);
    _box.remove(_kLockMode);
  }
}
