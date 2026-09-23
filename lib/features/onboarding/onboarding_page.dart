import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/lock/lock_controller.dart';

import '../../app/routes/app_routes.dart';
import '../../core/responsive/responsive.dart';
import '../wallet/wallet_controller.dart';

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
    if (err != null) return _toast(err);
    if (!_create && _mnemonic.text.trim().isEmpty) return _toast('invalid_phrase'.tr);
    setState(() => _busy = true);
    try {
      if (_create) {
        final mnemonic = await _wallet.createWallet(_password.text, strength: _strength);
        if (mounted) await _showBackup(mnemonic);
      } else {
        await _wallet.importWallet(_mnemonic.text, _password.text);
      }
      await _offerBiometric();
    Get.offAllNamed(Routes.home);
    } catch (e) {
      _toast(_msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// First run: offer fingerprint/face unlock so the password is typed once (owner's request 2026-09-23).
  Future<void> _offerBiometric() async {
    final lock = Get.find<LockController>();
    if (!await lock.biometricAvailable()) return;
    final yes = await Get.dialog<bool>(AlertDialog(
      content: Text('enable_biometric_q'.tr),
      actions: [
        TextButton(onPressed: () => Get.back<bool>(result: false), child: Text('later'.tr)),
        FilledButton(onPressed: () => Get.back<bool>(result: true), child: Text('enable'.tr)),
      ],
    ));
    if (yes == true) await lock.enableBiometric();
  }

  Future<void> _showBackup(String mnemonic) async {
    await Get.dialog<void>(
      AlertDialog(
        title: Text('backup_title'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('backup_warn'.tr),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(mnemonic, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.6)),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: mnemonic));
              _toast('copied'.tr);
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text('copy'.tr),
          ),
          FilledButton(
            onPressed: () {
              _wallet.confirmBackup();
              Get.back<void>();
            },
            child: Text('saved_it'.tr),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  String _msg(Object e) {
    final s = e is String ? e : e.toString().replaceFirst('Exception: ', '');
    // Controller throws translation keys for known cases.
    final known = {'invalid_phrase', 'incorrect_password'};
    return known.contains(s) ? s.tr : s;
  }

  void _toast(String m) => Get.snackbar('', m, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ContentColumn(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary],
                      ),
                    ),
                    child: Icon(Icons.account_balance_wallet, size: 40, color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
                const SizedBox(height: 16),
                Text('app_name'.tr, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('welcome_sub'.tr, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text('create_wallet'.tr)),
                    ButtonSegment(value: false, label: Text('import_wallet'.tr)),
                  ],
                  selected: {_create},
                  onSelectionChanged: (s) => setState(() => _create = s.first),
                ),
                if (_create) ...[
                  const SizedBox(height: 16),
                  Align(alignment: AlignmentDirectional.centerStart, child: Text('phrase_length'.tr, style: Theme.of(context).textTheme.labelMedium)),
                  const SizedBox(height: 6),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 128, label: Text('words_12'.tr)),
                      ButtonSegment(value: 256, label: Text('words_24'.tr)),
                    ],
                    selected: {_strength},
                    onSelectionChanged: (s) => setState(() => _strength = s.first),
                  ),
                ],
                const SizedBox(height: 20),
                if (!_create) ...[
                  TextField(
                    controller: _mnemonic,
                    minLines: 2,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: 'recovery_phrase'.tr, hintText: 'recovery_hint'.tr),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: 'password'.tr)),
                const SizedBox(height: 12),
                TextField(controller: _confirm, obscureText: true, decoration: InputDecoration(labelText: 'confirm_password'.tr)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_create ? Icons.add : Icons.download),
                  label: Text(_create ? 'create_wallet'.tr : 'import_wallet'.tr),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
