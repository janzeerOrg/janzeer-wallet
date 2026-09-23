import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/jz_tokens.dart';
import '../../core/ui/jz.dart';
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
      jzToast(s == 'incorrect_password' ? 'incorrect_password'.tr : s, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forget() {
    Get.dialog<void>(AlertDialog(
      title: Text('forget_wallet'.tr),
      content: Text('forget_confirm'.tr),
      actions: [
        TextButton(onPressed: () => Get.back<void>(), child: Text('cancel'.tr)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: JzColors.of(context).danger, foregroundColor: Colors.white),
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
    final c = JzColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: ContentColumn(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: JzMark(size: 64)),
                gap16,
                Text('locked'.tr, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                gap8,
                Center(child: JzAddressPill(_wallet.address.value)),
                gap24,
                JzCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofocus: true,
                      decoration: InputDecoration(hintText: 'password'.tr, prefixIcon: const Icon(Icons.lock_outline, size: 20)),
                      onSubmitted: (_) => _unlock(),
                    ),
                    gap12,
                    JzPrimaryButton(label: 'unlock'.tr, icon: Icons.lock_open_rounded, busy: _busy, onPressed: _busy ? null : _unlock),
                  ]),
                ),
                gap12,
                TextButton(onPressed: _forget, child: Text('forget_wallet'.tr, style: TextStyle(color: c.faint))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
