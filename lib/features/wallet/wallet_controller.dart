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

  void _setAccount(jc.Account a) {
    address.value = a.address;
    _pub = a.pubHex;
    _priv = a.privHex;
    unlocked.value = true;
  }

  Future<String> createWallet(String password) async {
    final mnemonic = jc.generateMnemonic();
    _setAccount(jc.accountFromMnemonic(mnemonic));
    SecureStore.vault = Vault.encrypt(mnemonic, password);
    SecureStore.address = address.value;
    hasVault.value = true;
    backupMnemonic = mnemonic;
    await reload();
    return mnemonic;
  }

  Future<void> importWallet(String mnemonic, String password) async {
    final phrase = mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (!jc.validateMnemonic(phrase)) throw 'invalid_phrase';
    _setAccount(jc.accountFromMnemonic(phrase));
    SecureStore.vault = Vault.encrypt(phrase, password);
    SecureStore.address = address.value;
    hasVault.value = true;
    await reload();
  }

  Future<void> unlock(String password) async {
    final v = SecureStore.vault;
    if (v == null) throw 'No wallet';
    final String mnemonic;
    try {
      mnemonic = Vault.decrypt(v, password);
    } catch (_) {
      throw 'incorrect_password';
    }
    _setAccount(jc.accountFromMnemonic(mnemonic));
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
    final body = jc.buildSignedTransfer(
      networkId: AppConfig.networkId,
      timestamp: _now,
      fee: (fee == null || fee.trim().isEmpty) ? AppConfig.minimumFee : fee,
      nonce: await _api.getNonce(address.value),
      senderAddress: address.value,
      publicKey: _pub,
      recipientAddress: recipientAddress.trim(),
      amount: amount,
      data: (data != null && data.isNotEmpty) ? data : null,
      privHex: _priv,
    );
    await _api.postTransfer(body);
    await reload();
  }

  /// Register `promoterKey` as a validator, paying the non-refundable deposit. No voting — registration admits.
  Future<void> registerPromoter(String promoterKey) async {
    _ensureUnlocked();
    final body = jc.buildSignedPromoter(
      networkId: AppConfig.networkId,
      timestamp: _now, fee: AppConfig.promoterFee, nonce: await _api.getNonce(address.value),
      senderAddress: address.value, publicKey: _pub, amount: AppConfig.promoterDeposit,
      promoterKey: promoterKey.trim(), privHex: _priv,
    );
    await _api.postPromoter(body);
    await reload();
  }

  /// Gracefully retire the validator `promoterKey` (removed next epoch; deposit stays non-refundable).
  Future<void> exitPromoter(String promoterKey) async {
    _ensureUnlocked();
    final body = jc.buildSignedExitPromoter(
      networkId: AppConfig.networkId,
      timestamp: _now, fee: AppConfig.minimumFee, nonce: await _api.getNonce(address.value),
      senderAddress: address.value, publicKey: _pub,
      promoterKey: promoterKey.trim(), privHex: _priv,
    );
    await _api.postExitPromoter(body);
    await reload();
  }

  Future<Map<String, dynamic>> recentTransfers() => _api.getTransfers(address.value);
  Future<Map<String, dynamic>> promoters() => _api.getPromoters();

  /// Verify a password against the stored vault (used to enable an app-lock, which caches the password).
  bool checkPassword(String password) {
    final v = SecureStore.vault;
    if (v == null) return false;
    try {
      Vault.decrypt(v, password);
      return true;
    } catch (_) {
      return false;
    }
  }

  String get publicKey => _pub;
}
