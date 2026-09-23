import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/responsive/adaptive_scaffold.dart';
import '../settings/settings_page.dart';
import 'wallet_home.dart';

/// The authenticated shell: Wallet / Settings (owner's decision 2026-09-23: no explorer in the wallet app —
/// wallet, tokens and validator only; the explorer lives on the website), in a responsive nav (bottom bar on mobile,
/// rail on tablet, extended rail on desktop).
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
    final titles = ['wallet'.tr, 'settings'.tr];
    return AdaptiveScaffold(
      title: titles[_index],
      selectedIndex: _index,
      onSelect: (i) => setState(() => _index = i),
      destinations: [
        AdaptiveDestination(Icons.account_balance_wallet, 'wallet'.tr),
        AdaptiveDestination(Icons.settings, 'settings'.tr),
      ],
      body: _bodies[_index],
    );
  }
}
