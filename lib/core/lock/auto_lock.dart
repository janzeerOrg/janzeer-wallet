import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../features/wallet/wallet_controller.dart';
import '../storage/secure_store.dart';

/// Locks the wallet when the app comes back after [timeout] in the background (or hidden/minimised on desktop).
///
/// Before this the lock screen appeared only at a cold start: an app left in the background for days opened straight
/// onto the unlocked wallet (review 2026-11-11). On return the in-memory keys are wiped and the user lands on the
/// app-lock (PIN/biometric) when one is set, else on the password screen.
class AutoLock extends GetxService with WidgetsBindingObserver {
  static const Duration timeout = Duration(minutes: 5);
  DateTime? _leftAt;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _leftAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final left = _leftAt;
    _leftAt = null;
    if (left == null || DateTime.now().difference(left) < timeout) return;
    if (SecureStore.vault == null || !Get.isRegistered<WalletController>()) return;
    final wallet = Get.find<WalletController>();
    if (!wallet.unlocked.value) return;
    wallet.lock();
    Get.offAllNamed(SecureStore.lockMode != 'none' ? Routes.lock : Routes.unlock);
  }
}
