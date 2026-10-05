// What the device keeps of a wallet (owner, 2026-10-05): by default ONLY the signing key, sealed with the password —
// the recovery phrase is shown once and never stored. Keeping the phrase is a choice at create/import, and can be
// undone later. Wallets made before 1.2.4 (phrase always kept) keep working and keep their backup.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:janzeer_sdk/crypto.dart' as jc;
import 'package:janzeer_sdk/vault.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:wallet/core/storage/secure_store.dart';
import 'package:wallet/features/wallet/wallet_controller.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

/// The real controller without the node: no client, no reload.
class _OfflineWallet extends WalletController {
  @override
  // ignore: must_call_super
  void onInit() {
    hasVault.value = SecureStore.vault != null;
    address.value = SecureStore.address;
    phraseStored.value = hasVault.value && SecureStore.phraseStored;
  }

  @override
  Future<void> reload() async {}
}

const _phrase = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _address = '0x06e1c0fa9955a700876f8cb0acc7f13fba9fb8ba';
const _password = 'correct horse battery';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('wallet_phrase_test');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
    await SecureStore.init();
  });
  tearDownAll(() => dir.deleteSync(recursive: true));
  setUp(SecureStore.clearWallet);

  _OfflineWallet wallet() => _OfflineWallet()..onInit();

  test('default: the vault holds the key only, the phrase cannot be shown', () async {
    final w = wallet();
    await w.importWallet(_phrase, _password);
    expect(w.address.value, _address);
    expect(w.phraseStored.value, isFalse);
    expect(SecureStore.phraseStored, isFalse);
    final secret = Vault.decrypt(SecureStore.vault!, _password);
    expect(secret.startsWith(kPrivVaultPrefix), isTrue, reason: 'no recovery phrase at rest');
    expect(secret.contains('abandon'), isFalse);
    expect(jc.accountFromPrivateKey(secret.substring(kPrivVaultPrefix.length)).address, _address);
    expect(await w.revealMnemonic(_password), isNull);

    w.lock();
    expect(w.unlocked.value, isFalse);
    await w.unlock(_password);
    expect(w.unlocked.value, isTrue);
    expect(w.address.value, _address);
    expect(w.sessionKeys()!['priv'], secret.substring(kPrivVaultPrefix.length));
    w.lock();
    await expectLater(w.unlock('wrong password'), throwsA('incorrect_password'));
  });

  test('a new wallet shows its phrase once and keeps only the key', () async {
    final w = wallet();
    final mnemonic = await w.createWallet(_password);
    expect(mnemonic.split(' ').length, 12);
    expect(w.backupMnemonic, mnemonic);
    expect(Vault.decrypt(SecureStore.vault!, _password).startsWith(kPrivVaultPrefix), isTrue);
    expect(w.address.value, jc.accountFromMnemonic(mnemonic).address);
    w.confirmBackup();
    expect(w.backupMnemonic, isNull);
  });

  test('opt-in: the phrase is kept, shown after the password, and can be removed', () async {
    final w = wallet();
    await w.importWallet(_phrase, _password, keepPhrase: true);
    expect(w.phraseStored.value, isTrue);
    expect(await w.revealMnemonic(_password), _phrase);
    expect(await w.revealMnemonic('wrong password'), isNull);

    expect(await w.removeStoredPhrase('wrong password'), isFalse);
    expect(w.phraseStored.value, isTrue, reason: 'a wrong password changes nothing');
    expect(await w.revealMnemonic(_password), _phrase);

    expect(await w.removeStoredPhrase(_password), isTrue);
    expect(w.phraseStored.value, isFalse);
    expect(SecureStore.phraseStored, isFalse);
    expect(await w.revealMnemonic(_password), isNull);
    expect(Vault.decrypt(SecureStore.vault!, _password).contains('abandon'), isFalse);
    w.lock();
    await w.unlock(_password);
    expect(w.address.value, _address, reason: 'the same wallet, still unlockable with the same password');
  });

  test('a wallet from before 1.2.4 keeps its phrase and its backup screen', () async {
    SecureStore.vault = Vault.encrypt(_phrase, _password);        // what 1.2.3 stored: the phrase, no flag
    SecureStore.address = _address;
    final w = wallet();
    expect(w.hasVault.value, isTrue);
    expect(w.phraseStored.value, isTrue);
    await w.unlock(_password);
    expect(w.address.value, _address);
    expect(await w.revealMnemonic(_password), _phrase);
    expect(await w.removeStoredPhrase(_password), isTrue);
    expect(wallet().phraseStored.value, isFalse, reason: 'the choice survives a restart');
  });

  test('forgetting the wallet clears the flag with it', () async {
    final w = wallet();
    await w.importWallet(_phrase, _password, keepPhrase: true);
    w.forget();
    expect(SecureStore.vault, isNull);
    expect(wallet().phraseStored.value, isFalse);
  });
}
