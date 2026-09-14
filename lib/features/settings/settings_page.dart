import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/lock/lock_controller.dart';
import '../../core/storage/secure_store.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/theme_presets.dart';
import '../wallet/wallet_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Owned by state (not recreated every build, and disposed properly). (settings polish)
  final _nodeCtrl = TextEditingController(text: SecureStore.nodeUrl);

  @override
  void dispose() {
    _nodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>();
    final locale = Get.find<LocaleController>();
    final lock = Get.find<LockController>();
    final wallet = Get.find<WalletController>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Language
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('language'.tr, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Obx(() => SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('English')),
                        ButtonSegment(value: 'ar', label: Text('العربية')),
                      ],
                      selected: {locale.code.value},
                      onSelectionChanged: (s) => locale.setLocale(s.first),
                    )),
              ],
            ),
          ),
        ),
        // Theme
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('theme'.tr, style: Theme.of(context).textTheme.titleMedium),
                Obx(() => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('dark_mode'.tr),
                      value: theme.isDark.value,
                      onChanged: theme.setDark,
                    )),
                Text('color_preset'.tr),
                const SizedBox(height: 8),
                Obx(() => Wrap(
                      spacing: 8,
                      children: [
                        for (var i = 0; i < kThemePresets.length; i++)
                          ChoiceChip(
                            label: Text(kThemePresets[i].name),
                            avatar: CircleAvatar(backgroundColor: kThemePresets[i].seed, radius: 8),
                            selected: theme.presetIndex.value == i,
                            onSelected: (_) => theme.setPreset(i),
                          ),
                      ],
                    )),
              ],
            ),
          ),
        ),
        // App lock
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('app_lock'.tr, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Obx(() => SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'none', label: Text('lock_none'.tr)),
                        ButtonSegment(value: 'pin', label: Text('lock_pin'.tr)),
                        ButtonSegment(value: 'biometric', label: Text('lock_biometric'.tr)),
                      ],
                      selected: {lock.mode.value},
                      onSelectionChanged: (s) => _changeLock(context, s.first, lock, wallet),
                    )),
              ],
            ),
          ),
        ),
        // Node URL
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('node_url'.tr, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(controller: _nodeCtrl, decoration: const InputDecoration(hintText: 'http://host:7019/api/v1/')),
                const SizedBox(height: 6),
                Obx(() => Text('${'network_id'.tr}: ${wallet.networkId.value}'
                    '${wallet.networkId.value == 'janzeer' ? '' : '  (${'testnet'.tr})'}',
                    style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () {
                    SecureStore.nodeUrl = _nodeCtrl.text.trim();
                    wallet.rebuildApi();
                    wallet.reload();
                    Get.snackbar('', 'save'.tr, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
                  },
                  child: Text('save'.tr),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _forget(wallet, lock),
          icon: const Icon(Icons.delete_outline),
          label: Text('forget_wallet'.tr),
          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
        ),
      ],
    );
  }

  Future<void> _changeLock(BuildContext context, String target, LockController lock, WalletController wallet) async {
    if (target == 'none') {
      lock.disable();
      return;
    }
    // Enabling a lock requires the wallet password (to cache it behind the lock).
    final password = TextEditingController();
    final pin = TextEditingController();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text(target == 'pin' ? 'set_pin'.tr : 'app_lock'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: 'password'.tr)),
          if (target == 'pin')
            TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'enter_pin'.tr)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back<bool>(result: false), child: Text('lock_none'.tr)),
        FilledButton(onPressed: () => Get.back<bool>(result: true), child: Text('save'.tr)),
      ],
    ));
    if (ok != true) return;
    if (!await wallet.checkPassword(password.text)) {
      Get.snackbar('', 'incorrect_password'.tr, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      return;
    }
    if (target == 'pin') {
      if (pin.text.isEmpty) return;
      await lock.enablePin(pin.text, password.text);
    } else {
      if (!await lock.biometricAvailable()) {
        Get.snackbar('', 'lock_biometric'.tr, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
        return;
      }
      await lock.enableBiometric(password.text);
    }
  }

  void _forget(WalletController wallet, LockController lock) {
    Get.dialog<void>(AlertDialog(
      content: Text('forget_confirm'.tr),
      actions: [
        TextButton(onPressed: () => Get.back<void>(), child: Text('lock_none'.tr)),
        FilledButton(
          onPressed: () {
            lock.disable();
            wallet.forget();
            Get.back<void>();
            Get.offAllNamed(Routes.onboarding);
          },
          child: Text('forget_wallet'.tr),
        ),
      ],
    ));
  }
}
