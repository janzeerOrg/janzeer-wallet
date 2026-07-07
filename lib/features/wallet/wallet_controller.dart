import 'dart:async';

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

  // Multi-asset: token balances joined with their definitions ({ tokenId, symbol, name, decimals, balance }),
  // and the token registry (definitions) for the mint/burn/transfer token picker.
  final RxList<Map<String, dynamic>> tokenBalances = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> tokens = <Map<String, dynamic>>[].obs;

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
    // Don't block the unlock on a network round-trip — the account is ready, navigate now and let the
    // balance/nonce/token lists populate reactively in the background (reload is resilient). Fixes the
    // "unlock button freezes" wait, especially against a slow node. (reload is now parallel + best-effort.)
    unawaited(reload());
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
    tokenBalances.clear();
    tokens.clear();
  }

  void confirmBackup() => backupMnemonic = null;

  Future<void> reload() async {
    if (address.value.isEmpty) return;
    loading.value = true;
    try {
      // Fetch balance + nonce in PARALLEL (not sequentially) so a refresh — and the unlock that awaits it —
      // isn't gated on two round-trips back to back. Best-effort: a slow/unreachable node must never crash
      // the app or wedge the UI (the token calls are further isolated in _reloadTokens).
      final core = await Future.wait([
        _api.getBalance(address.value),
        _api.getNonce(address.value),
      ]);
      balance.value = core[0] as String;
      nonce.value = core[1] as int;
      await _reloadTokens();
    } catch (_) {
      /* balances stay as-is; the next manual refresh retries */
    } finally {
      loading.value = false;
    }
  }

  /// Fetch token balances + the registry (in parallel), then join so each balance carries its symbol/decimals.
  /// Resilient on its own: the token endpoints must not break/block the core balance+nonce refresh or unlock.
  Future<void> _reloadTokens() async {
    try {
      final res = await Future.wait([
        _api.getTokenBalances(address.value),
        _api.getTokens(),
      ]);
      final tb = res[0];
      final reg = res[1];
      final regList = ((reg['list'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    tokens.assignAll(regList);
    final defs = {for (final t in regList) t['tokenId'] as String: t};
    tokenBalances.assignAll(((tb['list'] as List?) ?? []).map((e) {
      final b = Map<String, dynamic>.from(e as Map);
      final d = defs[b['tokenId']] ?? const {};
      return <String, dynamic>{
        'tokenId': b['tokenId'],
        'balance': '${b['balance']}',
        'symbol': d['symbol'] ?? '',
        'name': d['name'] ?? '',
        'decimals': d['decimals'] ?? 0,
      };
    }).toList());
    } catch (_) {
      /* token view is best-effort — leave the last-known lists in place */
    }
  }

  /// Refresh balance/nonce WITHOUT letting a failure surface. Used after a transaction is already broadcast:
  /// the send has succeeded, so a follow-up reload timeout must not be reported as a failed send (which used
  /// to leave the form filled and show a false error). (send-field fix)
  Future<void> _reloadQuietly() async {
    try {
      await reload();
    } catch (_) {
      /* balance/nonce will catch up on the next manual refresh */
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
    await _reloadQuietly();
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
    await _reloadQuietly();
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
    await _reloadQuietly();
  }

  /// Build, sign (background isolate) and submit a TokenTx. `cap`/`amount` are INTEGER BASE-UNIT decimal
  /// strings (already scaled by the token's decimals — the UI converts human input). CREATE pays the exact
  /// tokenCreateFee; other ops pay minimumFee (native coin). Returns the created tx payload.
  Future<dynamic> submitToken({
    required int op,
    String tokenId = '',
    String symbol = '',
    String name = '',
    int decimals = 0,
    String? cap,
    String? amount,
    String? recipient,
    String? fee,
  }) async {
    _ensureUnlocked();
    final n = await _api.getNonce(address.value);
    final feeStr = (fee == null || fee.trim().isEmpty)
        ? (op == jc.TokenOp.create ? AppConfig.tokenCreateFee : AppConfig.minimumFee)
        : fee;
    final body = await compute(jc.buildSignedTokenTxIsolate, <String, Object?>{
      'networkId': AppConfig.networkId,
      'timestamp': _now, 'fee': feeStr, 'nonce': n,
      'senderAddress': address.value, 'publicKey': _pub,
      'op': op, 'tokenId': tokenId, 'symbol': symbol, 'name': name, 'decimals': decimals,
      'cap': cap, 'amount': amount, 'recipient': recipient, 'privHex': _priv,
    });
    final res = await _api.postToken(body);
    await _reloadQuietly();
    return res;
  }

  Future<dynamic> createToken({required String symbol, required String name, required int decimals, required String cap, String initialSupply = '0'}) =>
      submitToken(op: jc.TokenOp.create, symbol: symbol, name: name, decimals: decimals, cap: cap, amount: initialSupply);
  Future<dynamic> mintToken({required String tokenId, required String amount}) =>
      submitToken(op: jc.TokenOp.mint, tokenId: tokenId, amount: amount);
  Future<dynamic> burnToken({required String tokenId, required String amount}) =>
      submitToken(op: jc.TokenOp.burn, tokenId: tokenId, amount: amount);
  Future<dynamic> setTokenCap({required String tokenId, required String cap}) =>
      submitToken(op: jc.TokenOp.setcap, tokenId: tokenId, cap: cap);
  Future<dynamic> transferToken({required String tokenId, required String amount, required String recipient}) =>
      submitToken(op: jc.TokenOp.transfer, tokenId: tokenId, amount: amount, recipient: recipient);

  Future<Map<String, dynamic>> recentTransfers() => _api.getTransfers(address.value);
  Future<Map<String, dynamic>> promoters() => _api.getPromoters();

  /// This wallet's transfers (confirmed or pending), paginated — for the home activity list.
  Future<Map<String, dynamic>> myTransfers({int page = 0, int size = 10, bool unconfirmed = false}) =>
      _api.getAddressTransfers(address.value, page: page, size: size, unconfirmed: unconfirmed);

  // Network-wide explorer reads (used by the Explorer tab).
  Future<Map<String, dynamic>> networkInfo() => _api.getInfo();
  Future<Map<String, dynamic>> latestBlocks({int size = 12}) => _api.getBlocks(size: size);
  Future<Map<String, dynamic>> latestTransfers({int size = 15}) => _api.getRecentTransfers(size: size);
  Future<Map<String, dynamic>> pendingTransfers({int size = 30}) => _api.getPendingTransfers(size: size);

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
