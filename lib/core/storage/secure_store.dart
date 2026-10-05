import 'dart:convert';

import 'package:get_secure_storage/get_secure_storage.dart';

import '../config/app_config.dart';

/// Encrypted-at-rest key/value store (get_secure_storage). Holds the password-encrypted vault blob and
/// non-secret prefs (theme, locale, node URL, lock mode). The vault is ALSO password-encrypted on top of
/// this (defence in depth) — see `package:janzeer_sdk/vault.dart`.
class SecureStore {
  static final GetSecureStorage _box = GetSecureStorage();

  static Future<void> init() => GetSecureStorage.init();

  static const _kVault = 'vault';
  static const _kAddress = 'address';
  static const _kPhraseStored = 'phraseStored';
  static const _kThemePreset = 'themePreset';
  static const _kThemeDark = 'themeDark';
  static const _kLocale = 'locale';
  static const _kNodeUrl = 'nodeUrl';
  static const _kLockMode = 'lockMode';
  static const _kCachedPassword = 'cachedPassword';
  static const _kCachedKeys = 'cachedKeys';
  static const _kHideBalance = 'hideBalance';
  static const _kPin = 'pin';
  static const _kLastUpdateCheck = 'lastUpdateCheck';
  static const _kDismissedUpdate = 'dismissedUpdate';

  // Vault (password-sealed secret: the recovery phrase when the user chose to keep it on the device, otherwise
  // only the private key as `priv:<hex>`) + the public address (shown while locked).
  static Map<String, dynamic>? get vault {
    final raw = _box.read(_kVault);
    return raw == null ? null : jsonDecode(raw as String) as Map<String, dynamic>;
  }

  static set vault(Map<String, dynamic>? v) =>
      v == null ? _box.remove(_kVault) : _box.write(_kVault, jsonEncode(v));

  /// Whether the vault holds the recovery PHRASE (the user opted in, or the wallet was made before 1.2.4, when it was
  /// always kept). False = the vault holds the private key only and the app cannot show the phrase.
  static bool get phraseStored => _box.read(_kPhraseStored) as bool? ?? (_box.read(_kVault) != null);
  static set phraseStored(bool v) => _box.write(_kPhraseStored, v);

  static String get address => _box.read(_kAddress) as String? ?? '';
  static set address(String v) => _box.write(_kAddress, v);

  // Update check (core/update): when the manifest was last read, and the version the user answered "later" to.
  static int get lastUpdateCheck => _box.read(_kLastUpdateCheck) as int? ?? 0;
  static set lastUpdateCheck(int v) => _box.write(_kLastUpdateCheck, v);
  static String get dismissedUpdate => _box.read(_kDismissedUpdate) as String? ?? '';
  static set dismissedUpdate(String v) => _box.write(_kDismissedUpdate, v);

  // Prefs
  static int get themePreset => _box.read(_kThemePreset) as int? ?? 0;
  static set themePreset(int v) => _box.write(_kThemePreset, v);

  /// Balance and amounts shown as •••• (the eye on the hero; owner's request 2026-09-24).
  static bool get hideBalance => _box.read(_kHideBalance) as bool? ?? false;
  static set hideBalance(bool v) => _box.write(_kHideBalance, v);
  static bool get themeDark => _box.read(_kThemeDark) as bool? ?? true;   // dark by default, like the explorer
  static set themeDark(bool v) => _box.write(_kThemeDark, v);

  static String get locale => _box.read(_kLocale) as String? ?? 'en';
  static set locale(String v) => _box.write(_kLocale, v);

  static String get nodeUrl {
    final v = normalizeNodeUrl(_box.read(_kNodeUrl) as String? ?? AppConfig.defaultNodeUrl);
    return AppConfig.legacyDefaultNodeUrls.contains(v) ? AppConfig.defaultNodeUrl : v; // an old default follows the new one
  }
  static set nodeUrl(String v) => _box.write(_kNodeUrl, normalizeNodeUrl(v));

  /// A public host is always https (a typed `http://node1.janzeer.org/…` hit nginx's 301 and every POST failed —
  /// online test 2026-09-23); loopback / private / .local hosts keep their scheme (dev nets, emulator 10.0.2.2).
  static String normalizeNodeUrl(String raw) {
    var v = raw.trim();
    if (v.isEmpty) return AppConfig.defaultNodeUrl;
    if (!v.contains('://')) v = 'https://$v';
    final u = Uri.tryParse(v);
    if (u == null) return v;
    final h = u.host;
    final private = h == 'localhost' ||
        h.endsWith('.local') ||
        RegExp(r'^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)').hasMatch(h) ||
        h == '::1';
    final scheme = (u.scheme == 'http' && !private) ? 'https' : u.scheme;
    var out = u.replace(scheme: scheme).toString();
    if (!out.endsWith('/')) out += '/';
    return out;
  }

  /// App-lock mode: 'none' | 'pin' | 'biometric'.
  static String get lockMode => _box.read(_kLockMode) as String? ?? 'none';
  static set lockMode(String v) => _box.write(_kLockMode, v);

  /// The vault password cached behind the app-lock (so the user doesn't retype it each launch). Only set
  /// when an app-lock is enabled; cleared when the lock is removed. PIN is stored here too (as the lock).
  static String? get cachedPassword => _box.read(_kCachedPassword) as String?;
  static set cachedPassword(String? v) =>
      v == null ? _box.remove(_kCachedPassword) : _box.write(_kCachedPassword, v);

  /// The unlocked account {priv, pub, address} behind the app-lock (PIN/biometric): releasing it is instant, while
  /// the password path re-runs the vault's 250k-round PBKDF2 + derivation (7–8 s on a phone — online test 2026-09-23).
  /// The store itself is encrypted at rest; the vault (password-sealed) stays the backup of record.
  static Map<String, String>? get cachedKeys {
    final raw = _box.read(_kCachedKeys);
    return raw == null ? null : Map<String, String>.from(jsonDecode(raw as String) as Map);
  }
  static set cachedKeys(Map<String, String>? v) =>
      v == null ? _box.remove(_kCachedKeys) : _box.write(_kCachedKeys, jsonEncode(v));
  static String? get pin => _box.read(_kPin) as String?;
  static set pin(String? v) => v == null ? _box.remove(_kPin) : _box.write(_kPin, v);
  static void clearWallet() {
    _box.remove(_kVault);
    _box.remove(_kAddress);
    _box.remove(_kPhraseStored);
    _box.remove(_kCachedPassword);
    _box.remove(_kCachedKeys);
    _box.remove(_kPin);
    _box.remove(_kLockMode);
  }
}
