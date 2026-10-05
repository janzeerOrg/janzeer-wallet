import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes/app_routes.dart';
import '../../core/update/update_controller.dart';
import '../../core/update/update_widgets.dart';
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
  final _nodeFocus = FocusNode();
  bool _custom = SecureStore.nodeUrl != AppConfig.defaultNodeUrl;

  @override
  void dispose() {
    _nodeCtrl.dispose();
    _nodeFocus.dispose();
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
          // the phrase is on the device only when the user chose so (or the wallet predates 1.2.4): show / remove it
          child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (wallet.phraseStored.value) ...[
                  Text('never_share'.tr, style: TextStyle(fontSize: 12.5, color: c.muted)),
                  gap8,
                  JzGhostButton(label: 'show_phrase'.tr, icon: Icons.visibility_outlined, onPressed: () => _showPhrase(wallet)),
                  gap8,
                  JzGhostButton(label: 'remove_phrase'.tr, icon: Icons.delete_outline, danger: true, onPressed: () => _removePhrase(wallet)),
                ] else
                  Text('phrase_not_stored'.tr, style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.45)),
              ])),
        ),
        gap12,
        _Section(
          title: 'network'.tr,
          icon: Icons.hub_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: Text('${'mainnet'.tr} · ${'default_node'.tr}'),
                selected: !_custom,
                onSelected: (_) => setState(() {
                  _custom = false;
                  _nodeCtrl.text = AppConfig.defaultNodeUrl;
                }),
              ),
              ChoiceChip(
                label: Text('custom_node'.tr),
                selected: _custom,
                onSelected: (_) {
                  setState(() {
                    _custom = true;
                    if (_nodeCtrl.text == AppConfig.defaultNodeUrl) _nodeCtrl.clear();
                  });
                  _nodeFocus.requestFocus();
                },
              ),
            ]),
            gap12,
            TextField(
              controller: _nodeCtrl,
              focusNode: _nodeFocus,
              autocorrect: false,
              style: const TextStyle(fontFamily: kMono, fontSize: 13),
              decoration: InputDecoration(hintText: AppConfig.defaultNodeUrl, prefixIcon: const Icon(Icons.link, size: 18)),
              onChanged: (v) => setState(() => _custom = v.trim() != AppConfig.defaultNodeUrl),
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
            gap8,
            Obx(() {
              final u = Get.find<UpdateController>();
              final has = u.available.value != null;
              return JzGhostButton(
                label: u.checking.value ? 'checking'.tr : (has ? 'update_available'.trParams({'v': u.available.value!.version}) : 'check_updates'.tr),
                icon: has ? Icons.system_update_alt_rounded : Icons.refresh,
                onPressed: u.checking.value
                    ? null
                    : () async {
                        if (has) return showUpdateDialog(context);
                        final r = await u.check(force: true);
                        if (!context.mounted) return;
                        if (r == true) return showUpdateDialog(context);
                        jzToast(r == false ? 'up_to_date'.tr : 'update_check_failed'.tr, error: r == null);
                      },
              );
            }),
            gap8,
            JzGhostButton(label: 'announcements'.tr, icon: Icons.campaign_outlined, onPressed: () => launchUrl(Uri.parse(AppConfig.channelUrl), mode: LaunchMode.externalApplication)),
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

  /// One dialog: password → (PBKDF2 on an isolate) → the words in the same dialog. Two chained dialogs
  /// (password, then a second one) sometimes never showed the second on Android until the app repainted
  /// (owner, 2026-09-24).
  Future<void> _showPhrase(WalletController wallet) async {
    final password = TextEditingController();
    String? mnemonic;
    var busy = false;
    var hidden = true;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final c = JzColors.of(ctx);
        Future<void> reveal() async {
          if (password.text.isEmpty || busy) return;
          setD(() {
            busy = true;
            error = null;
          });
          final m = await wallet.revealMnemonic(password.text);
          setD(() {
            busy = false;
            if (m == null) {
              error = 'incorrect_password'.tr;
            } else {
              mnemonic = m;
            }
          });
        }

        return AlertDialog(
          title: Text('recovery_phrase'.tr),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (mnemonic == null) ...[
                TextField(
                  controller: password,
                  obscureText: true,
                  autofocus: true,
                  enabled: !busy,
                  decoration: InputDecoration(hintText: 'password'.tr, errorText: error),
                  onSubmitted: (_) => reveal(),
                ),
                gap12,
                JzPrimaryButton(label: 'reveal'.tr, icon: Icons.visibility_outlined, busy: busy, onPressed: busy ? null : reveal),
              ] else ...[
                SeedGrid(words: mnemonic!.split(' '), hidden: hidden),
                gap8,
                TextButton.icon(
                  onPressed: () => setD(() => hidden = !hidden),
                  icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  label: Text(hidden ? 'reveal'.tr : 'hide'.tr),
                ),
                Text('never_share'.tr, style: TextStyle(fontSize: 12, color: c.danger)),
              ],
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(mnemonic == null ? 'cancel'.tr : 'done'.tr))],
        );
      }),
    );
    password.dispose();
  }

  /// Stop keeping the phrase on this device: explain, ask for the password, re-seal the vault with the key alone.
  Future<void> _removePhrase(WalletController wallet) async {
    final password = TextEditingController();
    var busy = false;
    String? error;
    final removed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final c = JzColors.of(ctx);
        Future<void> go() async {
          if (password.text.isEmpty || busy) return;
          setD(() {
            busy = true;
            error = null;
          });
          final ok = await wallet.removeStoredPhrase(password.text);
          if (ok) {
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          } else {
            setD(() {
              busy = false;
              error = 'incorrect_password'.tr;
            });
          }
        }

        return AlertDialog(
          title: Text('remove_phrase'.tr),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('remove_phrase_q'.tr, style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.45)),
              gap12,
              TextField(
                controller: password,
                obscureText: true,
                enabled: !busy,
                decoration: InputDecoration(hintText: 'password'.tr, errorText: error),
                onSubmitted: (_) => go(),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.of(ctx).pop(false), child: Text('cancel'.tr)),
            FilledButton(onPressed: busy ? null : go, child: Text(busy ? 'securing'.tr : 'remove'.tr)),
          ],
        );
      }),
    );
    password.dispose();
    if (removed == true) jzToast('phrase_removed'.tr);
  }

  Future<String?> _askPassword({String? extraLabel, TextEditingController? extra}) async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
      title: Text('password'.tr),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: password, obscureText: true, autofocus: true, decoration: InputDecoration(hintText: 'password'.tr)),
        if (extra != null) ...[
          gap12,
          TextField(controller: extra, obscureText: true, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: extraLabel)),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('cancel'.tr)),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('save'.tr)),
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
