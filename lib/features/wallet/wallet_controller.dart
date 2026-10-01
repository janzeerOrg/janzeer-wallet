import 'dart:async';

import 'package:flutter/foundation.dart' show compute;
import 'package:get/get.dart';

import 'package:janzeer_sdk/crypto.dart' as jc;
import 'package:janzeer_sdk/janzeer_sdk.dart' show JanzeerClient, JanzeerException, toPlainNumbers;
import 'package:janzeer_sdk/vault.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/secure_store.dart';

/// The wallet's core state + actions. Non-custodial: the mnemonic/private key live only in memory while
/// unlocked; only the password-encrypted vault is persisted. Mirrors j_frontend/src/store/WalletStore.js.
///
/// Crypto and node transport come from `janzeer_sdk` (the official SDK; the app used to carry its own copies).
/// Screens still consume the raw JSON shapes (`Map`s with numbers), so the reads go through [_map], which turns
/// the SDK's lossless tree back into `jsonDecode` values; the typed client methods are the way forward.
class WalletController extends GetxController {
  late JanzeerClient _api;

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

  /// Validators registered BY this wallet address: { nodeKey, active } — `active` = in the current epoch's producer
  /// set. `null` until the first successful read, so the Validator tab can tell "none" from "not loaded yet".
  final Rxn<List<Map<String, dynamic>>> myValidators = Rxn<List<Map<String, dynamic>>>();

  /// Shown once after creation so the user can write it down; cleared on confirm.
  String? backupMnemonic;

  /// The node's `consensus.network-id` (GET info) — signed into every transaction, so the same app works on the
  /// mainnet ("janzeer") and on a testnet ("janzeer-testnet"). Falls back to [AppConfig.networkId] on an older node.
  final networkId = AppConfig.networkId.obs;

  /// True when the node runs a testnet faucet (`POST /api/v1/faucet`).
  final hasFaucet = false.obs;

  /// Bumped by every reload (pull-to-refresh, after a send/speed-up) — the activity list re-fetches on it. The
  /// list used to load once and only refresh on a screen change (owner, 2026-09-24).
  final activityTick = 0.obs;

  /// Privacy eye: balance and amounts rendered as •••• everywhere.
  final hideBalance = SecureStore.hideBalance.obs;
  void toggleHideBalance() {
    hideBalance.value = !hideBalance.value;
    SecureStore.hideBalance = hideBalance.value;
  }

  @override
  void onInit() {
    super.onInit();
    _api = _client();
    hasVault.value = SecureStore.vault != null;
    address.value = SecureStore.address;
    _loadNodeInfo();
  }

  /// Rebuild the API client after the node URL changes (Settings).
  void rebuildApi() {
    _api.close();
    _api = _client();
    _loadNodeInfo();
  }

  Future<void> _loadNodeInfo() async {
    try {
      final info = await _api.info();
      networkId.value = info.networkId;
      hasFaucet.value = info.faucet;
    } catch (_) {
      networkId.value = AppConfig.networkId;
      hasFaucet.value = false;
    }
  }

  /// Testnet faucet drip to this wallet's address; returns the transfer hash.
  Future<String> requestFaucet() async {
    final res = await _guard(() => _api.post('faucet', {'address': address.value}).then(toPlainNumbers));
    return (res as Map)['hash'] as String;
  }

  // Bounded timeout: a wrong/unreachable node URL must surface in seconds, not hang the spinner. (wallet freeze fix)
  static JanzeerClient _client() => JanzeerClient(SecureStore.nodeUrl, timeout: const Duration(seconds: 15));

  /// Run a node call; SDK exceptions become plain `Exception(message)` so the screens' `replaceFirst('Exception: ', '')`
  /// keeps showing the node's text (typed handling can move into the screens later).
  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on JanzeerException catch (e) {
      throw Exception(e.message);
    }
  }

  /// A paged/object payload in the legacy `jsonDecode` shape (`total`, `list`, …); `empty` for a 404.
  Future<Map<String, dynamic>> _map(String path, {Map<String, Object?>? query, Map<String, dynamic> empty = const {'total': 0, 'list': []}}) =>
      _guard(() async {
        final v = await _api.get(path, query: query, notFound: null);
        return v == null ? Map<String, dynamic>.from(empty) : Map<String, dynamic>.from(toPlainNumbers(v) as Map);
      });

  /// Apply a derived account. Keys come back from the derivation isolate as a plain {priv,pub,address} map.
  void _setAccount(Map<String, String> a) {
    address.value = a['address']!;
    _pub = a['pub']!;
    _priv = a['priv']!;
    unlocked.value = true;
  }

  /// The unlocked account for the app-lock cache (see SecureStore.cachedKeys); null while locked.
  Map<String, String>? sessionKeys() =>
      unlocked.value ? {'priv': _priv, 'pub': _pub, 'address': address.value} : null;

  /// Instant unlock from the app-lock cache: no vault decryption, no derivation.
  void restoreSession(Map<String, String> keys) {
    _setAccount(keys);
    unawaited(reload());
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
    myValidators.value = null;
  }

  void confirmBackup() => backupMnemonic = null;

  Future<void> reload() async {
    activityTick.value++;
    if (address.value.isEmpty) return;
    loading.value = true;
    try {
      // Fetch balance + nonce in PARALLEL (not sequentially) so a refresh — and the unlock that awaits it —
      // isn't gated on two round-trips back to back. Best-effort: a slow/unreachable node must never crash
      // the app or wedge the UI (the token calls are further isolated in _reloadTokens).
      final core = await Future.wait<Object>([
        _api.balance(address.value),
        _api.nonce(address.value),
      ]);
      balance.value = core[0] as String;
      nonce.value = core[1] as int;
      await Future.wait([if (AppConfig.tokensEnabled) _reloadTokens(), _reloadValidators()]);
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
        _map('tokens/balances/${address.value}', query: {'size': 100}),
        _map('tokens', query: {'size': 100}),
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

  /// Which validators did this address register, and are they producing? Best-effort like the token view.
  Future<void> _reloadValidators() async {
    try {
      final me = address.value.toLowerCase();
      final res = await Future.wait([
        _map('validators', query: {'size': 200}),
        _map('validators/active', query: {'size': 100}),
      ]);
      final active = {for (final e in (res[1]['list'] as List? ?? [])) '${(e as Map)['nodeKey']}'.toLowerCase()};
      myValidators.value = [
        for (final e in (res[0]['list'] as List? ?? []))
          if ('${(e as Map)['address']}'.toLowerCase() == me)
            {'nodeKey': '${e['nodeKey']}', 'active': active.contains('${e['nodeKey']}'.toLowerCase())},
      ];
    } catch (_) {
      /* keep the last-known status */
    }
  }

  /// Refresh balance/nonce WITHOUT letting a failure surface. Used after a transaction is already broadcast:
  /// the send has succeeded, so a follow-up reload timeout must not be reported as a failed send (which used
  /// to leave the form filled and show a false error). (send-field fix)
  Future<void> _reloadQuietly() async {
    activityTick.value++;
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

  /// Signs and submits a transfer; returns the tx hash the node accepted (for the Sent screen / explorer link).
  Future<String?> sendTransfer({required String recipientAddress, required String amount, String? fee, String? data}) async {
    _ensureUnlocked();
    final nonce = await _guard(() => _api.nonce(address.value));
    // ECDSA signing runs on a background isolate so Send doesn't block the UI thread. (wallet freeze fix)
    final body = await compute(jc.buildSignedTransferIsolate, <String, Object?>{
      'networkId': networkId.value,
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
    final r = await _guard(() => _api.post('transactions/transfers', body));
    await _reloadQuietly();
    return r is Map ? (r['hash'] ?? body['hash'])?.toString() : body['hash']?.toString();
  }

  /// Speed up a PENDING transfer: the SAME transfer (recipient, amount, memo, NONCE) signed again with a strictly higher
  /// fee. The node keeps the higher payer and drops the other, so only the new fee is charged. `tx` is a row of the
  /// pending list; `tx['nonce']` is reported by node 0.1.0+.
  Future<void> speedUpTransfer(Map<String, dynamic> tx, String newFee) async {
    _ensureUnlocked();
    final nonce = tx['nonce'];
    if (nonce == null) throw 'speed_up_unsupported'.tr;
    if (!((double.tryParse(newFee) ?? 0) > (double.tryParse('${tx['fee']}') ?? 0))) throw 'speed_up_fee_low'.tr;
    final memo = tx['data'];
    final body = await compute(jc.buildSignedTransferIsolate, <String, Object?>{
      'networkId': networkId.value,
      'timestamp': _now,
      'fee': newFee.trim(),
      'nonce': (nonce as num).toInt(),
      'senderAddress': address.value,
      'publicKey': _pub,
      'recipientAddress': '${tx['recipientAddress']}',
      'amount': '${tx['amount']}',
      'data': (memo is String && memo.isNotEmpty) ? memo : null,
      'privHex': _priv,
    });
    await _guard(() => _api.post('transactions/transfers', body));
    await _reloadQuietly();
  }

  /// Register `promoterKey` as a validator, paying the non-refundable deposit. No voting — registration admits.
  Future<void> registerPromoter(String promoterKey) async {
    _ensureUnlocked();
    final nonce = await _guard(() => _api.nonce(address.value));
    final body = await compute(jc.buildSignedPromoterIsolate, <String, Object?>{
      'networkId': networkId.value,
      'timestamp': _now, 'fee': AppConfig.promoterFee, 'nonce': nonce,
      'senderAddress': address.value, 'publicKey': _pub, 'amount': AppConfig.promoterDeposit,
      'promoterKey': promoterKey.trim(), 'privHex': _priv,
    });
    await _guard(() => _api.post('transactions/validators', body)); // the SDK body already carries `validatorKey`
    await _reloadQuietly();
  }

  /// Gracefully retire the validator `promoterKey` (removed next epoch; deposit stays non-refundable).
  Future<void> exitPromoter(String promoterKey) async {
    _ensureUnlocked();
    final nonce = await _guard(() => _api.nonce(address.value));
    final body = await compute(jc.buildSignedExitPromoterIsolate, <String, Object?>{
      'networkId': networkId.value,
      'timestamp': _now, 'fee': AppConfig.minimumFee, 'nonce': nonce,
      'senderAddress': address.value, 'publicKey': _pub,
      'promoterKey': promoterKey.trim(), 'privHex': _priv,
    });
    await _guard(() => _api.post('transactions/exit-validators', body));
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
    final n = await _guard(() => _api.nonce(address.value));
    final feeStr = (fee == null || fee.trim().isEmpty)
        ? (op == jc.TokenOp.create ? AppConfig.tokenCreateFee : AppConfig.minimumFee)
        : fee;
    final body = await compute(jc.buildSignedTokenTxIsolate, <String, Object?>{
      'networkId': networkId.value,
      'timestamp': _now, 'fee': feeStr, 'nonce': n,
      'senderAddress': address.value, 'publicKey': _pub,
      'op': op, 'tokenId': tokenId, 'symbol': symbol, 'name': name, 'decimals': decimals,
      'cap': cap, 'amount': amount, 'recipient': recipient, 'privHex': _priv,
    });
    final res = await _guard(() => _api.post('transactions/tokens', body).then(toPlainNumbers));
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

  Future<Map<String, dynamic>> recentTransfers() => _map('transactions/transfers', query: {'address': address.value, 'size': 15});

  /// Registered validators (the old client asked a non-existent `promoters` path and always showed an empty list).
  Future<Map<String, dynamic>> promoters() => _map('validators', query: {'size': 20});

  /// This wallet's transfers (confirmed or pending), paginated — for the home activity list.
  Future<Map<String, dynamic>> myTransfers({int page = 0, int size = 10, bool unconfirmed = false}) =>
      _map('transactions/transfers', query: {'address': address.value, 'page': page, 'size': size, 'unconfirmed': unconfirmed ? true : null}, empty: const {'total': 0, 'list': [], 'page': 0, 'totalPages': 0});

  // Network-wide explorer reads (used by the Explorer tab).
  Future<Map<String, dynamic>> networkInfo() => _map('explorer/info', empty: const {});
  Future<Map<String, dynamic>> latestBlocks({int size = 12}) => _map('blocks/main', query: {'size': size});
  Future<Map<String, dynamic>> latestTransfers({int size = 15}) => _map('transactions/transfers', query: {'size': size});
  Future<Map<String, dynamic>> pendingTransfers({int size = 30}) => _map('transactions/transfers', query: {'unconfirmed': true, 'size': size});

  /// Verify a password against the stored vault (used to enable an app-lock, which caches the password).
  /// Runs the 250k-iter PBKDF2 on a background isolate so it never blocks the UI. (wallet freeze fix)
  /// The seed phrase for Settings → Backup, after the password (one 250k-round PBKDF2 on an isolate).
  Future<String?> revealMnemonic(String password) async {
    final v = SecureStore.vault;
    if (v == null) return null;
    try {
      return await compute(vaultDecryptIsolate, [v, password]);
    } catch (_) {
      return null;
    }
  }

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
