import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/responsive/responsive.dart';
import '../wallet/wallet_controller.dart';

/// Password unlock (when no app-lock is set): decrypts the vault with the wallet password.
class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key});
  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final _wallet = Get.find<WalletController>();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_password.text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _wallet.unlock(_password.text);
      Get.offAllNamed(Routes.home);
    } catch (e) {
      final s = e is String ? e : e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('', s == 'incorrect_password' ? 'incorrect_password'.tr : s,
          snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forget() {
    Get.dialog<void>(AlertDialog(
      content: Text('forget_confirm'.tr),
      actions: [
        TextButton(onPressed: () => Get.back<void>(), child: Text('lock'.tr)),
        FilledButton(
          onPressed: () {
            _wallet.forget();
            Get.back<void>();
            Get.offAllNamed(Routes.onboarding);
          },
          child: Text('forget_wallet'.tr),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ContentColumn(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                Text('locked'.tr, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                Text(_wallet.address.value, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'password'.tr),
                  onSubmitted: (_) => _unlock(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(Icons.lock_open),
                  label: Text('unlock'.tr),
                ),
                TextButton(onPressed: _forget, child: Text('forget_wallet'.tr)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
