import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Encrypted vault: the wallet mnemonic at rest, sealed with the user's password. AES-256-GCM with a
/// PBKDF2-HMAC-SHA256 (250k iters) key — mirrors the web wallet's vault.js. The plaintext mnemonic never
/// persists; decryption requires the password and GCM auth fails loudly on a wrong one. Stored inside
/// get_secure_storage (which is itself encrypted at rest) for defence in depth. Non-custodial: never sent
/// to the node.
class Vault {
  static const int _iterations = 250000;
  static final Random _rng = Random.secure();

  static Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _rng.nextInt(256);
    }
    return b;
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))..init(Pbkdf2Parameters(salt, _iterations, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Seal [secret] (the mnemonic) under [password]. Returns a JSON-safe blob to persist.
  static Map<String, dynamic> encrypt(String secret, String password) {
    final salt = _randomBytes(16);
    final iv = _randomBytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(_deriveKey(password, salt)), 128, iv, Uint8List(0)));
    final ct = cipher.process(Uint8List.fromList(utf8.encode(secret)));
    return {'v': 1, 'salt': base64.encode(salt), 'iv': base64.encode(iv), 'ct': base64.encode(ct)};
  }

  /// Open a vault blob with [password]. Throws (GCM auth failure) if the password is wrong or data tampered.
  static String decrypt(Map<String, dynamic> vault, String password) {
    final salt = base64.decode(vault['salt'] as String);
    final iv = base64.decode(vault['iv'] as String);
    final ct = base64.decode(vault['ct'] as String);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(_deriveKey(password, salt)), 128, iv, Uint8List(0)));
    return utf8.decode(cipher.process(ct));
  }
}
