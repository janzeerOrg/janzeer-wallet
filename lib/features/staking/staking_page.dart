import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/responsive/responsive.dart';
import '../wallet/wallet_controller.dart';

/// Delegate/undelegate, claim accrued reward, and register as a promoter — all client-signed.
class StakingPage extends StatefulWidget {
  const StakingPage({super.key});
  @override
  State<StakingPage> createState() => _StakingPageState();
}

class _StakingPageState extends State<StakingPage> {
  final _wallet = Get.find<WalletController>();
  final _delegateKey = TextEditingController();
  final _promoterKey = TextEditingController();
  String _busy = '';

  @override
  void dispose() {
    _delegateKey.dispose();
    _promoterKey.dispose();
    super.dispose();
  }

  bool _isKey(String k) => RegExp(r'^0[23][0-9a-fA-F]{64}$').hasMatch(k.trim());

  Future<void> _run(String tag, Future<void> Function() action, String okMsg) async {
    setState(() => _busy = tag);
    try {
      await action();
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
      appBar: AppBar(title: Text('staking'.tr)),
      body: SafeArea(
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Delegation
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('delegation'.tr, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Obx(() {
                        final d = _wallet.delegation.value;
                        if (d != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('delegating_to'.tr),
                              SelectableText('${d['nodeKey'] ?? d['promoterKey'] ?? ''}', style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _busy.isNotEmpty
                                    ? null
                                    : () => _run('undelegate', () => _wallet.undelegate('${d['nodeKey'] ?? d['promoterKey']}'), 'submitted'.tr),
                                icon: const Icon(Icons.link_off),
                                label: Text('undelegate'.tr),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            TextField(controller: _delegateKey, decoration: InputDecoration(labelText: 'promoter_key'.tr)),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _busy.isNotEmpty
                                  ? null
                                  : () => _isKey(_delegateKey.text)
                                      ? _run('delegate', () => _wallet.delegate(_delegateKey.text), 'submitted'.tr)
                                      : _toast('invalid_promoter_key'.tr),
                              icon: const Icon(Icons.how_to_vote),
                              label: Text('${'delegate'.tr} (${'fee'.tr} ${AppConfig.voteFeeFor})'),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              // Claim
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('rewards'.tr, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Obx(() => Text('${'accrued_reward'.tr}: ${_wallet.accruedReward.value}')),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _busy.isNotEmpty ? null : () => _run('claim', _wallet.claimReward, 'submitted'.tr),
                        icon: const Icon(Icons.download),
                        label: Text('claim'.tr),
                      ),
                    ],
                  ),
                ),
              ),
              // Register
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('become_promoter'.tr, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextField(controller: _promoterKey, decoration: InputDecoration(labelText: 'promoter_key'.tr))),
                        TextButton(onPressed: () => _promoterKey.text = _wallet.publicKey, child: Text('use_my_key'.tr)),
                      ]),
                      const SizedBox(height: 8),
                      Text('${'fee'.tr} ${AppConfig.promoterFee} · ${AppConfig.promoterStake}', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _busy.isNotEmpty
                            ? null
                            : () => _isKey(_promoterKey.text)
                                ? _run('register', () => _wallet.registerPromoter(_promoterKey.text), 'submitted'.tr)
                                : _toast('invalid_promoter_key'.tr),
                        icon: const Icon(Icons.campaign),
                        label: Text('register'.tr),
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
