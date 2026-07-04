import 'package:flutter/foundation.dart' show compute;
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/crypto/janzeer_crypto.dart' as jc;
import '../../core/crypto/vault.dart';
import '../../core/network/node_api.dart';
import '../../core/storage/secure_store.dart';

/// The wallet's core state + actions. Non-custodial: the mnemonic/private key live only in memory while
/// unlocked; only the password-encrypted vault is persisted. Mirrors j_frontend/src/store/WalletStore.js.
class WalletController extends GetxController {
  late NodeApi _api;

  final RxBool hasVault = false.obs;
  final RxBool unlocked = false.obs;
  final RxString address = ''.obs;
  String _pub = '';
  String _priv = '';

  final RxString balance = '0'.obs;
  final RxInt nonce = 0.obs;
  final RxBool loading = false.obs;

  /// Shown once after creation so the user can write it down; cleared on confirm.
  String? backupMnemonic;

  @override
  void onInit() {
    super.onInit();
    _api = NodeApi(SecureStore.nodeUrl);
    hasVault.value = SecureStore.vault != null;
    address.value = SecureStore.address;
  }

  /// Rebuild the API client after the node URL changes (Settings).
  void rebuildApi() => _api = NodeApi(SecureStore.nodeUrl);

  /// Apply a derived account. Keys come back from the derivation isolate as a plain {priv,pub,address} map.
  void _setAccount(Map<String, String> a) {
    address.value = a['address']!;
    _pub = a['pub']!;
    _priv = a['priv']!;
    unlocked.value = true;
  }

  Future<String> createWallet(String password, {int strength = 128}) async {
    final mnemonic = jc.generateMnemonic(strength: strength);
    // Derivation (PBKDF2-SHA512 + EC) and vault sealing (250k-iter PBKDF2) run on background isolates via
    // compute() so the UI thread — and its button spinner — stay responsive. (wallet freeze fix)
    _setAccount(await compute(jc.deriveAccountIsolate, mnemonic));
    SecureStore.vault = await compute(vaultEncryptIsolate, [mnemonic, password]);
    SecureStore.address = address.value;
    hasVault.value = true;
    backupMnemonic = mnemonic;
    await reload();
    return mnemonic;
  }

  Future<void> importWallet(String mnemonic, String password) async {
    final phrase = mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (!jc.validateMnemonic(phrase)) throw 'invalid_phrase';
    _setAccount(await compute(jc.deriveAccountIsolate, phrase));
    SecureStore.vault = await compute(vaultEncryptIsolate, [phrase, password]);
    SecureStore.address = address.value;
    hasVault.value = true;
    await reload();
  }

  Future<void> unlock(String password) async {
    final v = SecureStore.vault;
    if (v == null) throw 'No wallet';
    final String mnemonic;
    try {
      // 250k-iter PBKDF2 decrypt on a background isolate; a wrong password throws (GCM auth failure).
      mnemonic = await compute(vaultDecryptIsolate, [v, password]);
    } catch (_) {
      throw 'incorrect_password';
    }
    _setAccount(await compute(jc.deriveAccountIsolate, mnemonic));
    await reload();
  }

  void lock() {
    _priv = '';
    _pub = '';
    unlocked.value = false;
    backupMnemonic = null;
  }

  void forget() {
    lock();
    SecureStore.clearWallet();
    hasVault.value = false;
    address.value = '';
    balance.value = '0';
    nonce.value = 0;
  }

  void confirmBackup() => backupMnemonic = null;

  Future<void> reload() async {
    if (address.value.isEmpty) return;
    loading.value = true;
    try {
      balance.value = await _api.getBalance(address.value);
      nonce.value = await _api.getNonce(address.value);
    } finally {
      loading.value = false;
    }
  }

  void _ensureUnlocked() {
    if (!unlocked.value) throw 'Wallet is locked';
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> sendTransfer({required String recipientAddress, required String amount, String? fee, String? data}) async {
    _ensureUnlocked();
    final nonce = await _api.getNonce(address.value);
    // ECDSA signing runs on a background isolate so Send doesn't block the UI thread. (wallet freeze fix)
    final body = await compute(jc.buildSignedTransferIsolate, <String, Object?>{
      'networkId': AppConfig.networkId,
      'timestamp': _now,
      'fee': (fee == null || fee.trim().isEmpty) ? AppConfig.minimumFee : fee,
      'nonce': nonce,
      'senderAddress': address.value,
      'publicKey': _pub,
      'recipientAddress': recipientAddress.trim(),
      'amount': amount,
      'data': (data != null && data.isNotEmpty) ? data : null,
      'privHex': _priv,
    });
    await _api.postTransfer(body);
    await reload();
  }

  /// Register `promoterKey` as a validator, paying the non-refundable deposit. No voting — registration admits.
  Future<void> registerPromoter(String promoterKey) async {
    _ensureUnlocked();
    final nonce = await _api.getNonce(address.value);
    final body = await compute(jc.buildSignedPromoterIsolate, <String, Object?>{
      'networkId': AppConfig.networkId,
      'timestamp': _now, 'fee': AppConfig.promoterFee, 'nonce': nonce,
      'senderAddress': address.value, 'publicKey': _pub, 'amount': AppConfig.promoterDeposit,
      'promoterKey': promoterKey.trim(), 'privHex': _priv,
    });
    await _api.postPromoter(body);
    await reload();
  }

  /// Gracefully retire the validator `promoterKey` (removed next epoch; deposit stays non-refundable).
  Future<void> exitPromoter(String promoterKey) async {
    _ensureUnlocked();
    final nonce = await _api.getNonce(address.value);
    final body = await compute(jc.buildSignedExitPromoterIsolate, <String, Object?>{
      'networkId': AppConfig.networkId,
      'timestamp': _now, 'fee': AppConfig.minimumFee, 'nonce': nonce,
      'senderAddress': address.value, 'publicKey': _pub,
      'promoterKey': promoterKey.trim(), 'privHex': _priv,
    });
    await _api.postExitPromoter(body);
    await reload();
  }

  Future<Map<String, dynamic>> recentTransfers() => _api.getTransfers(address.value);
  Future<Map<String, dynamic>> promoters() => _api.getPromoters();

  /// Verify a password against the stored vault (used to enable an app-lock, which caches the password).
  /// Runs the 250k-iter PBKDF2 on a background isolate so it never blocks the UI. (wallet freeze fix)
  Future<bool> checkPassword(String password) async {
    final v = SecureStore.vault;
    if (v == null) return false;
    try {
      await compute(vaultDecryptIsolate, [v, password]);
      return true;
    } catch (_) {
      return false;
    }
  }

  String get publicKey => _pub;
}
