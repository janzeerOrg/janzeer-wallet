import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/lock/lock_controller.dart';
import '../../core/responsive/adaptive_scaffold.dart';
import '../../core/theme/jz_tokens.dart';
import '../../core/ui/jz.dart';
import '../settings/settings_page.dart';
import '../wallet/wallet_controller.dart';
import 'wallet_home.dart';

/// The authenticated shell: Wallet / Settings (owner's decision 2026-09-23: no explorer in the wallet app — wallet,
/// tokens and validator only; the explorer lives on the website). Top bar: brand mark + title, the network badge
/// (Mainnet / Testnet) and Lock.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _bodies = [WalletHome(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    final w = Get.find<WalletController>();
    final c = JzColors.of(context);
    final titles = ['wallet'.tr, 'settings'.tr];
    return AdaptiveScaffold(
      title: titles[_index],
      leading: const Padding(padding: EdgeInsetsDirectional.only(start: 16), child: JzMark(size: 26)),
      actions: [
        Obx(() {
          final id = w.networkId.value;
          final main = id == 'janzeer';
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: JzTag(main ? 'mainnet'.tr : (id.isEmpty ? '…' : 'testnet'.tr), kind: main ? JzTagKind.ok : JzTagKind.pending, icon: Icons.circle),
          );
        }),
        IconButton(
          tooltip: 'lock_now'.tr,
          icon: Icon(Icons.lock_outline, color: c.muted),
          onPressed: () {
            w.lock();
            Get.offAllNamed(Get.find<LockController>().enabled ? Routes.lock : Routes.unlock);
          },
        ),
      ],
      selectedIndex: _index,
      onSelect: (i) => setState(() => _index = i),
      destinations: [
        AdaptiveDestination(Icons.account_balance_wallet_outlined, 'wallet'.tr),
        AdaptiveDestination(Icons.settings_outlined, 'settings'.tr),
      ],
      body: _bodies[_index],
    );
  }
}
