import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/responsive/responsive.dart';
import '../wallet/wallet_controller.dart';

/// Register as a validator (non-refundable deposit) or gracefully exit — all client-signed. No delegation or
/// reward claiming: staking was removed (registration alone admits a validator; block rewards go 100% to the
/// producer). Mirrors j_frontend's Validator panel.
class ValidatorPage extends StatefulWidget {
  const ValidatorPage({super.key});
  @override
  State<ValidatorPage> createState() => _ValidatorPageState();
}

class _ValidatorPageState extends State<ValidatorPage> {
  final _wallet = Get.find<WalletController>();
  final _registerKey = TextEditingController();
  final _exitKey = TextEditingController();
  String _busy = '';

  @override
  void dispose() {
    _registerKey.dispose();
    _exitKey.dispose();
    super.dispose();
  }

  bool _isKey(String k) => RegExp(r'^0[23][0-9a-fA-F]{64}$').hasMatch(k.trim());

  Future<void> _run(String tag, Future<void> Function() action, String okMsg, {VoidCallback? onOk}) async {
    setState(() => _busy = tag);
    try {
      await action();
      onOk?.call(); // clear the key field on success (this page doesn't pop). (send-field fix)
      _toast(okMsg);
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  void _toast(String m) => Get.snackbar('', m, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('validator'.tr)),
      body: SafeArea(
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Register validator
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('become_validator'.tr, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextField(controller: _registerKey, decoration: InputDecoration(labelText: 'validator_key'.tr))),
                        TextButton(onPressed: () => _registerKey.text = _wallet.publicKey, child: Text('use_my_key'.tr)),
                      ]),
                      const SizedBox(height: 8),
                      Text('${'fee'.tr} ${AppConfig.promoterFee} · ${'deposit'.tr} ${AppConfig.promoterDeposit} (${'non_refundable'.tr})',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _busy.isNotEmpty
                            ? null
                            : () => _isKey(_registerKey.text)
                                ? _run('register', () => _wallet.registerPromoter(_registerKey.text), 'submitted'.tr, onOk: _registerKey.clear)
                                : _toast('invalid_validator_key'.tr),
                        icon: const Icon(Icons.campaign),
                        label: Text('register'.tr),
                      ),
                    ],
                  ),
                ),
              ),
              // Exit validator
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('retire_validator'.tr, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextField(controller: _exitKey, decoration: InputDecoration(labelText: 'validator_key'.tr))),
                        TextButton(onPressed: () => _exitKey.text = _wallet.publicKey, child: Text('use_my_key'.tr)),
                      ]),
                      const SizedBox(height: 8),
                      Text('exit_hint'.tr, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy.isNotEmpty
                            ? null
                            : () => _isKey(_exitKey.text)
                                ? _run('exit', () => _wallet.exitPromoter(_exitKey.text), 'submitted'.tr, onOk: _exitKey.clear)
                                : _toast('invalid_validator_key'.tr),
                        icon: const Icon(Icons.logout),
                        label: Text('exit'.tr),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
