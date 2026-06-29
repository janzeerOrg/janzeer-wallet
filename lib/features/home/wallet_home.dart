import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/format.dart';
import '../wallet/wallet_controller.dart';

/// Wallet tab: a hero balance card, accrued/nonce stats, and quick actions (Send/Receive/Stake).
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
          _BalanceHero(w: w),
          const SizedBox(height: 4),
          Row(
            children: [
              _stat(context, 'accrued_reward'.tr, () => '${prettyAmount(w.accruedReward.value)} ${AppConfig.unit}'),
              const SizedBox(width: 12),
              _stat(context, 'next_nonce'.tr, () => '${w.nonce.value}'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _ActionButton(icon: Icons.north_east, label: 'send'.tr, onTap: () => Get.toNamed(Routes.send))),
              const SizedBox(width: 12),
              Expanded(child: _ActionButton(icon: Icons.south_west, label: 'receive'.tr, tonal: true, onTap: () => Get.toNamed(Routes.receive))),
              const SizedBox(width: 12),
              Expanded(child: _ActionButton(icon: Icons.bolt, label: 'staking'.tr, tonal: true, onTap: () => Get.toNamed(Routes.staking))),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() => w.loading.value
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
              : const SizedBox.shrink()),
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
              const SizedBox(height: 6),
              Obx(() => Text(value(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.w});
  final WalletController w;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('balance'.tr, style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85), fontWeight: FontWeight.w500)),
              Obx(() => w.loading.value
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary))
                  : InkWell(onTap: w.reload, child: Icon(Icons.refresh, size: 20, color: scheme.onPrimary))),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() => RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: prettyAmount(w.balance.value),
                    style: TextStyle(color: scheme.onPrimary, fontSize: 34, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: '  ${AppConfig.unit}',
                    style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ]),
              )),
          const SizedBox(height: 18),
          Obx(() => InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: w.address.value));
                  Get.snackbar('', 'copy_address'.tr, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(shortHash(w.address.value, head: 10, tail: 8), style: TextStyle(color: scheme.onPrimary, fontFamily: 'monospace'))),
                      Icon(Icons.copy, size: 16, color: scheme.onPrimary),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.tonal = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = tonal ? scheme.secondaryContainer : scheme.primaryContainer;
    final fg = tonal ? scheme.onSecondaryContainer : scheme.onPrimaryContainer;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: fg),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
