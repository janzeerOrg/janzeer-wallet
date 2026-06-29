import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../wallet/wallet_controller.dart';

/// Wallet tab: balance / accrued / nonce, address with copy, and quick actions (Send/Receive/Stake).
class WalletHome extends StatelessWidget {
  const WalletHome({super.key});

  @override
  Widget build(BuildContext context) {
    final w = Get.find<WalletController>();
    return RefreshIndicator(
      onRefresh: w.reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('balance'.tr, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Obx(() => Text(w.balance.value,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 16),
                  Obx(() => Row(
                        children: [
                          Expanded(
                            child: SelectableText(w.address.value,
                                style: Theme.of(context).textTheme.bodySmall, maxLines: 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: w.address.value));
                              Get.snackbar('', 'copy_address'.tr, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
                            },
                          ),
                        ],
                      )),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _stat(context, 'accrued_reward'.tr, () => w.accruedReward.value),
              const SizedBox(width: 12),
              _stat(context, 'next_nonce'.tr, () => '${w.nonce.value}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: FilledButton.icon(onPressed: () => Get.toNamed(Routes.send), icon: const Icon(Icons.send), label: Text('send'.tr))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.tonalIcon(onPressed: () => Get.toNamed(Routes.receive), icon: const Icon(Icons.qr_code), label: Text('receive'.tr))),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => Get.toNamed(Routes.staking), icon: const Icon(Icons.bolt), label: Text('staking'.tr)),
          const SizedBox(height: 8),
          Obx(() => w.loading.value ? const LinearProgressIndicator() : const SizedBox.shrink()),
          Center(
            child: TextButton.icon(onPressed: w.reload, icon: const Icon(Icons.refresh), label: Text('refresh'.tr)),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String Function() value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Obx(() => Text(value(), style: Theme.of(context).textTheme.titleLarge)),
            ],
          ),
        ),
      ),
    );
  }
}
