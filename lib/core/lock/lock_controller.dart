import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

import '../storage/secure_store.dart';
import '../../features/wallet/wallet_controller.dart';

/// App-lock: an optional gate on top of the password-encrypted vault. Modes: 'none' | 'pin' | 'biometric'.
///
/// When a lock is set, the UNLOCKED ACCOUNT (private key, public key, address) is kept in the encrypted store and
/// released by PIN/biometric, so unlocking is instant. The old design cached the vault PASSWORD and re-ran the
/// vault's 250,000-round PBKDF2 plus the key derivation on every unlock — 7–8 s on a phone (online test 2026-09-23).
/// The password-sealed vault remains the backup of record; the password is still needed to show the seed phrase,
/// to enable a lock (proof of ownership) and when no lock is set.
class LockController extends GetxController {
  final LocalAuthentication _auth = LocalAuthentication();
  final RxString mode = SecureStore.lockMode.obs;

  bool get enabled => mode.value != 'none';

  /// True at launch when a lock is set and a vault exists (the app should show the lock screen).
  bool get shouldLock => enabled && SecureStore.vault != null;

  Future<bool> biometricAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Cache the unlocked account for the lock to release. Callers prove ownership first (Settings verifies the
  /// password with `checkPassword`; onboarding has just sealed the vault with it).
  Future<bool> _arm(String modeName, {String? pin}) async {
    final wallet = Get.find<WalletController>();
    final keys = wallet.sessionKeys();
    if (keys == null) return false;
    SecureStore.cachedKeys = keys;
    SecureStore.pin = pin;
    SecureStore.cachedPassword = null; // never keep the password around any more
    SecureStore.lockMode = modeName;
    mode.value = modeName;
    return true;
  }

  Future<bool> enablePin(String pin) => _arm('pin', pin: pin);

  Future<bool> enableBiometric() => _arm('biometric');

  void disable() {
    SecureStore.lockMode = 'none';
    SecureStore.cachedKeys = null;
    SecureStore.pin = null;
    SecureStore.cachedPassword = null;
    SecureStore.pinFails = 0;
    SecureStore.pinLockedUntil = 0;
    mode.value = 'none';
  }

  /// Release the cached account. Falls back to the legacy cached-password path for wallets locked before this
  /// version (one slow unlock, then re-armed with the keys).
  Future<bool> _release() async {
    final wallet = Get.find<WalletController>();
    final keys = SecureStore.cachedKeys;
    if (keys != null) {
      wallet.restoreSession(keys);
      return true;
    }
    final legacy = SecureStore.cachedPassword;
    if (legacy == null) return false;
    final password = mode.value == 'pin' ? legacy.substring(legacy.indexOf(' ') + 1) : legacy;
    await wallet.unlock(password);
    SecureStore.cachedKeys = wallet.sessionKeys();
    if (mode.value == 'pin') SecureStore.pin = legacy.substring(0, legacy.indexOf(' '));
    SecureStore.cachedPassword = null;
    return true;
  }

  /// Wrong PINs allowed before a wait is imposed, and before the PIN lock is removed altogether.
  static const int pinFreeTries = 5;
  static const int pinMaxTries = 10;

  /// Unlock with a PIN. Returns false on a wrong PIN.
  ///
  /// The PIN does not encrypt the cached account — it only gates it — so guessing must be made expensive: after
  /// [pinFreeTries] wrong PINs each further attempt waits (30 s, doubling, up to 15 min; the wait survives a restart),
  /// and after [pinMaxTries] the cached account is erased and only the wallet PASSWORD opens the vault again
  /// (review 2026-11-11: there was no limit at all). Throws the `pin_wait` message while a wait is running and
  /// `lock_no_session` once the PIN lock has been removed.
  Future<bool> unlockWithPin(String pin) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final until = SecureStore.pinLockedUntil;
    if (until > now) throw 'pin_wait'.trParams({'s': '${((until - now) / 1000).ceil()}'});
    final stored = SecureStore.pin ?? SecureStore.cachedPassword?.split(' ').first;
    if (stored == null || stored != pin) {
      final fails = SecureStore.pinFails + 1;
      SecureStore.pinFails = fails;
      if (fails >= pinMaxTries) {
        disable(); // erases the cached account and the PIN; the password-sealed vault is untouched
        throw 'lock_no_session';
      }
      if (fails >= pinFreeTries) {
        final waitS = (30 * (1 << (fails - pinFreeTries))).clamp(30, 900);
        SecureStore.pinLockedUntil = now + waitS * 1000;
      }
      return false;
    }
    SecureStore.pinFails = 0;
    SecureStore.pinLockedUntil = 0;
    return _release();
  }

  /// Prompt biometrics, then release the account. Throws a readable message when the prompt cannot be shown
  /// (no enrolled biometrics, plugin/platform error) so the lock screen can say so instead of doing nothing.
  Future<bool> unlockWithBiometric() async {
    final bool ok;
    try {
      ok = await _auth.authenticate(
        localizedReason: 'Unlock your wallet',
        biometricOnly: true,
      );
    } catch (e) {
      throw e.toString().replaceFirst('Exception: ', '');
    }
    if (!ok) return false;
    if (!await _release()) throw 'lock_no_session';
    return true;
  }
}
