import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes/app_routes.dart';
import '../../core/config/app_config.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/lock/lock_controller.dart';
import '../../core/storage/secure_store.dart';
import '../../core/theme/jz_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/ui/jz.dart';
import '../onboarding/onboarding_page.dart';
import '../wallet/wallet_controller.dart';

/// Settings: Security (app lock), Backup (recovery phrase after the password), Network (node), Language, Theme,
/// About, and the way to forget the wallet on this device.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
    final c = JzColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(JzSpace.s4),
      children: [
        _Section(
          title: 'security'.tr,
          icon: Icons.shield_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('app_lock_sub'.tr, style: TextStyle(fontSize: 12.5, color: c.muted)),
            gap8,
            Obx(() => SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'none', label: Text('lock_none'.tr), icon: const Icon(Icons.password, size: 16)),
                    ButtonSegment(value: 'pin', label: Text('lock_pin'.tr), icon: const Icon(Icons.pin_outlined, size: 16)),
                    ButtonSegment(value: 'biometric', label: Text('lock_biometric'.tr), icon: const Icon(Icons.fingerprint, size: 16)),
                  ],
                  selected: {lock.mode.value},
                  onSelectionChanged: (s) => _changeLock(context, s.first, lock, wallet),
                )),
          ]),
        ),
        gap12,
        _Section(
          title: 'backup'.tr,
          icon: Icons.key_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('never_share'.tr, style: TextStyle(fontSize: 12.5, color: c.muted)),
            gap8,
            JzGhostButton(label: 'show_phrase'.tr, icon: Icons.visibility_outlined, onPressed: () => _showPhrase(wallet)),
          ]),
        ),
        gap12,
        _Section(
          title: 'network'.tr,
          icon: Icons.hub_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: Text('${'mainnet'.tr} · ${'default_node'.tr}'),
                selected: _nodeCtrl.text == AppConfig.defaultNodeUrl,
                onSelected: (_) => setState(() => _nodeCtrl.text = AppConfig.defaultNodeUrl),
              ),
              ChoiceChip(label: Text('custom_node'.tr), selected: _nodeCtrl.text != AppConfig.defaultNodeUrl, onSelected: (_) {}),
            ]),
            gap12,
            TextField(
              controller: _nodeCtrl,
              autocorrect: false,
              style: const TextStyle(fontFamily: kMono, fontSize: 13),
              decoration: InputDecoration(hintText: AppConfig.defaultNodeUrl, prefixIcon: const Icon(Icons.link, size: 18)),
              onChanged: (_) => setState(() {}),
            ),
            gap8,
            Obx(() {
              final id = wallet.networkId.value;
              return Row(children: [
                JzTag(id.isEmpty ? 'node_unreachable'.tr : 'node_ok'.tr, kind: id.isEmpty ? JzTagKind.danger : JzTagKind.ok, icon: Icons.circle),
                const SizedBox(width: 8),
                Expanded(child: JzMono(id.isEmpty ? '' : '${'network_id'.tr}: $id${id == 'janzeer' ? '' : '  (${'testnet'.tr})'}', size: 12)),
              ]);
            }),
            gap12,
            JzPrimaryButton(
              label: 'save'.tr,
              icon: Icons.save_outlined,
              onPressed: () {
                SecureStore.nodeUrl = _nodeCtrl.text.trim();
                setState(() => _nodeCtrl.text = SecureStore.nodeUrl);
                wallet.rebuildApi();
                wallet.reload();
                jzToast('node_saved'.tr);
              },
            ),
          ]),
        ),
        gap12,
        _Section(
          title: 'language'.tr,
          icon: Icons.translate,
          child: Obx(() => SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'ar', label: Text('العربية')),
                ],
                selected: {locale.code.value},
                onSelectionChanged: (s) => locale.setLocale(s.first),
              )),
        ),
        gap12,
        _Section(
          title: 'theme'.tr,
          icon: Icons.dark_mode_outlined,
          child: Obx(() => SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, label: Text('theme_dark'.tr), icon: const Icon(Icons.dark_mode_outlined, size: 16)),
                  ButtonSegment(value: false, label: Text('theme_light'.tr), icon: const Icon(Icons.light_mode_outlined, size: 16)),
                ],
                selected: {theme.isDark.value},
                onSelectionChanged: (s) => theme.setDark(s.first),
              )),
        ),
        gap12,
        _Section(
          title: 'about'.tr,
          icon: Icons.info_outline,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            JzKv('version'.tr, AppConfig.appVersion, mono: true),
            JzKv('app_name'.tr, 'janzeer.org'),
            gap8,
            JzGhostButton(label: 'open_explorer'.tr, icon: Icons.open_in_new, onPressed: () => launchUrl(Uri.parse(AppConfig.explorerUrl), mode: LaunchMode.externalApplication)),
          ]),
        ),
        gap16,
        JzGhostButton(label: 'forget_wallet'.tr, icon: Icons.delete_outline, danger: true, onPressed: () => _forget(wallet, lock)),
        gap8,
        Text('forget_sub'.tr, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.faint)),
        gap24,
      ],
    );
  }

  Future<void> _showPhrase(WalletController wallet) async {
    final password = await _askPassword();
    if (password == null) return;
    final mnemonic = await wallet.revealMnemonic(password);
    if (mnemonic == null) return jzToast('incorrect_password'.tr, error: true);
    if (!mounted) return;
    var hidden = true;
    await Get.dialog<void>(StatefulBuilder(builder: (ctx, setD) {
      return AlertDialog(
        title: Text('recovery_phrase'.tr),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SeedGrid(words: mnemonic.split(' '), hidden: hidden),
            gap8,
            TextButton.icon(
              onPressed: () => setD(() => hidden = !hidden),
              icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
              label: Text(hidden ? 'reveal'.tr : 'hide'.tr),
            ),
            Text('never_share'.tr, style: TextStyle(fontSize: 12, color: JzColors.of(ctx).danger)),
          ]),
        ),
        actions: [FilledButton(onPressed: () => Get.back<void>(), child: Text('done'.tr))],
      );
    }));
  }

  Future<String?> _askPassword({String? extraLabel, TextEditingController? extra}) async {
    final password = TextEditingController();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('password'.tr),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: password, obscureText: true, autofocus: true, decoration: InputDecoration(hintText: 'password'.tr)),
        if (extra != null) ...[
          gap12,
          TextField(controller: extra, obscureText: true, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: extraLabel)),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Get.back<bool>(result: false), child: Text('cancel'.tr)),
        FilledButton(onPressed: () => Get.back<bool>(result: true), child: Text('save'.tr)),
      ],
    ));
    if (ok != true || password.text.isEmpty) return null;
    return password.text;
  }

  Future<void> _changeLock(BuildContext context, String target, LockController lock, WalletController wallet) async {
    if (target == 'none') {
      lock.disable();
      return;
    }
    // Enabling a lock requires the wallet password (proof of ownership; the unlocked keys are then cached behind the lock).
    final pin = TextEditingController();
    final password = await _askPassword(extraLabel: target == 'pin' ? 'enter_pin'.tr : null, extra: target == 'pin' ? pin : null);
    if (password == null) return;
    if (!await wallet.checkPassword(password)) return jzToast('incorrect_password'.tr, error: true);
    if (target == 'pin') {
      if (pin.text.length < 4) return jzToast('enter_pin'.tr, error: true);
      await lock.enablePin(pin.text);
    } else {
      if (!await lock.biometricAvailable()) return jzToast('lock_biometric'.tr, error: true);
      await lock.enableBiometric();
    }
  }

  void _forget(WalletController wallet, LockController lock) {
    Get.dialog<void>(AlertDialog(
      title: Text('forget_wallet'.tr),
      content: Text('forget_confirm'.tr),
      actions: [
        TextButton(onPressed: () => Get.back<void>(), child: Text('cancel'.tr)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: JzColors.of(context).danger, foregroundColor: Colors.white),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return JzCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
          child: Row(children: [Icon(icon, size: 18, color: c.muted), const SizedBox(width: 10), Text(title, style: Theme.of(context).textTheme.titleSmall)]),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ]),
    );
  }
}
