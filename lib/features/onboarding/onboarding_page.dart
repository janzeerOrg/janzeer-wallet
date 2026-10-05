import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/lock/lock_controller.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/jz_tokens.dart';
import '../../core/ui/jz.dart';
import '../wallet/wallet_controller.dart';

/// First run: create a wallet (12/24 words) or restore one. The seed phrase is shown ONCE as a numbered grid,
/// hidden by default; then biometrics are offered so the password is typed once. Keeping the phrase on the device
/// is a switch that is OFF by default (owner, 2026-10-05): without it the app holds only the signing key.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _wallet = Get.find<WalletController>();
  bool _create = true;
  bool _busy = false;
  int _strength = 128; // 128 = 12 words, 256 = 24 words
  final _mnemonic = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPw = false;
  bool _keepPhrase = false; // keep the recovery phrase on this device (viewable later in Settings)

  @override
  void dispose() {
    _mnemonic.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validatePassword() {
    if (_password.text.length < 8) return 'password_too_short'.tr;
    if (_password.text != _confirm.text) return 'passwords_mismatch'.tr;
    return null;
  }

  Future<void> _submit() async {
    final err = _validatePassword();
    if (err != null) return jzToast(err, error: true);
    if (!_create && _mnemonic.text.trim().isEmpty) return jzToast('invalid_phrase'.tr, error: true);
    setState(() => _busy = true);
    try {
      if (_create) {
        final mnemonic = await _wallet.createWallet(_password.text, strength: _strength, keepPhrase: _keepPhrase);
        if (mounted) await _showBackup(mnemonic, kept: _keepPhrase);
      } else {
        await _wallet.importWallet(_mnemonic.text, _password.text, keepPhrase: _keepPhrase);
      }
      await _offerBiometric();
      Get.offAllNamed(Routes.home);
    } catch (e) {
      jzToast(_msg(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// First run: offer fingerprint/face unlock so the password is typed once (owner's request 2026-09-23).
  Future<void> _offerBiometric() async {
    final lock = Get.find<LockController>();
    if (!await lock.biometricAvailable()) return;
    if (!mounted) return;
    final accent = JzColors.of(context).accent;
    final yes = await Get.dialog<bool>(AlertDialog(
      title: Row(children: [Icon(Icons.fingerprint, color: accent), const SizedBox(width: 10), Text('lock_biometric'.tr)]),
      content: Text('enable_biometric_q'.tr),
      actions: [
        TextButton(onPressed: () => Get.back<bool>(result: false), child: Text('later'.tr)),
        FilledButton(onPressed: () => Get.back<bool>(result: true), child: Text('enable'.tr)),
      ],
    ));
    if (yes == true) await lock.enableBiometric();
  }

  /// The words, once. When they are NOT kept on the device this is the only time the app can show them, so the
  /// button stays off until the user has revealed them and ticked that they are written down.
  Future<void> _showBackup(String mnemonic, {required bool kept}) async {
    final words = mnemonic.split(' ');
    var hidden = true;
    var seen = false;
    var confirmed = kept;
    await Get.dialog<void>(
      StatefulBuilder(builder: (ctx, setD) {
        final c = JzColors.of(ctx);
        return AlertDialog(
          title: Text('backup_title'.tr),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('write_down'.tr, style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.45)),
              if (!kept) ...[
                gap8,
                Text('backup_once'.tr, style: TextStyle(fontSize: 13, color: c.danger, height: 1.45, fontWeight: FontWeight.w600)),
              ],
              gap12,
              SeedGrid(words: words, hidden: hidden),
              gap8,
              Row(children: [
                TextButton.icon(
                  onPressed: () => setD(() {
                    hidden = !hidden;
                    seen = true;
                  }),
                  icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  label: Text(hidden ? 'reveal'.tr : 'hide'.tr),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: mnemonic));
                    jzToast('copied'.tr);
                    setD(() => seen = true);
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text('copy'.tr),
                ),
              ]),
              Text('never_share'.tr, style: TextStyle(fontSize: 12, color: c.danger)),
              if (!kept)
                CheckboxListTile(
                  value: confirmed,
                  onChanged: seen ? (v) => setD(() => confirmed = v ?? false) : null,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('backup_confirm'.tr, style: TextStyle(fontSize: 13, color: c.text, height: 1.4)),
                ),
            ]),
          ),
          actions: [
            JzPrimaryButton(
              label: 'saved_it'.tr,
              icon: Icons.check,
              onPressed: confirmed
                  ? () {
                      _wallet.confirmBackup();
                      Get.back<void>();
                    }
                  : null,
            ),
          ],
        );
      }),
      barrierDismissible: false,
    );
  }

  String _msg(Object e) {
    final s = e is String ? e : e.toString().replaceFirst('Exception: ', '');
    const known = {'invalid_phrase', 'incorrect_password'};
    return known.contains(s) ? s.tr : s;
  }

  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: ContentColumn(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: JzMark(size: 72)),
                gap16,
                Text('app_name'.tr, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 26)),
                gap8,
                Text('welcome_create'.tr, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.5)),
                gap24,
                JzTabs(
                  tabs: [(Icons.add_circle_outline, 'create_wallet'.tr), (Icons.restore, 'import_wallet'.tr)],
                  index: _create ? 0 : 1,
                  onChanged: (i) => setState(() => _create = i == 0),
                ),
                gap16,
                JzCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_create)
                      JzField(
                        label: 'phrase_length'.tr,
                        child: SegmentedButton<int>(
                          segments: [ButtonSegment(value: 128, label: Text('words_12'.tr)), ButtonSegment(value: 256, label: Text('words_24'.tr))],
                          selected: {_strength},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) => setState(() => _strength = s.first),
                        ),
                      )
                    else
                      JzField(
                        label: 'recovery_phrase'.tr,
                        child: TextField(
                          controller: _mnemonic,
                          minLines: 3,
                          maxLines: 4,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: const TextStyle(fontFamily: kMono, fontSize: 13.5, height: 1.5),
                          decoration: InputDecoration(hintText: 'recovery_hint'.tr),
                        ),
                      ),
                    gap16,
                    JzField(
                      label: 'set_password'.tr,
                      child: TextField(
                        controller: _password,
                        obscureText: !_showPw,
                        decoration: InputDecoration(
                          hintText: 'password'.tr,
                          suffixIcon: IconButton(icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), onPressed: () => setState(() => _showPw = !_showPw)),
                        ),
                      ),
                    ),
                    gap12,
                    TextField(controller: _confirm, obscureText: !_showPw, decoration: InputDecoration(hintText: 'confirm_password'.tr)),
                    gap8,
                    Text('password_hint'.tr, style: TextStyle(fontSize: 12, color: c.faint)),
                    gap8,
                    // a plain row, not a ListTile: the card paints its own background and a ListTile's ink needs a Material
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('keep_phrase'.tr, style: TextStyle(fontSize: 13.5, color: c.text, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text((_keepPhrase ? 'keep_phrase_on' : 'keep_phrase_off').tr, style: TextStyle(fontSize: 12, color: _keepPhrase ? c.danger : c.faint, height: 1.4)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Switch(value: _keepPhrase, onChanged: _busy ? null : (v) => setState(() => _keepPhrase = v)),
                    ]),
                  ]),
                ),
                gap16,
                JzPrimaryButton(
                  label: _busy ? 'securing'.tr : (_create ? 'create_wallet'.tr : 'import_wallet'.tr),
                  icon: _create ? Icons.add : Icons.download_rounded,
                  busy: _busy,
                  onPressed: _busy ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The seed phrase as numbered pills that flow to the next line — every word is shown in full (3 fixed columns cut
/// the long ones, owner 2026-09-24). Blurred until revealed.
class SeedGrid extends StatelessWidget {
  const SeedGrid({super.key, required this.words, this.hidden = false});
  final List<String> words;
  final bool hidden;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.surface2, borderRadius: JzRadius.rSm, border: Border.all(color: c.border)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < words.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: c.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${i + 1}', style: TextStyle(fontSize: 10.5, color: c.faint, fontFamily: kMono, fontFeatures: kTabular)),
                  const SizedBox(width: 6),
                  Text(hidden ? '••••••' : words[i], style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text, fontFamily: kMono)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
