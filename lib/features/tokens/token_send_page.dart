import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/jz_tokens.dart';
import '../../core/ui/jz.dart';
import '../../core/utils/format.dart';
import '../send/qr_scan_page.dart';
import '../wallet/wallet_controller.dart';

/// Send a JZT-1 token you hold: pick the token, recipient (paste · scan), amount with Max → review → sign → "Sent".
/// The everyday half of the token feature (owner, 2026-11-09: "a tab for send/receive, not create/mint"); the issuer
/// operations stay on [TokensPage]. Amounts are typed in human units and scaled by the token's decimals here.
class TokenSendPage extends StatefulWidget {
  const TokenSendPage({super.key, this.initialTokenId});
  final String? initialTokenId;
  @override
  State<TokenSendPage> createState() => _TokenSendPageState();
}

class _TokenSendPageState extends State<TokenSendPage> {
  final _wallet = Get.find<WalletController>();
  String? _tokenId;
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tokenId = widget.initialTokenId ?? (_wallet.tokenBalances.isNotEmpty ? '${_wallet.tokenBalances.first['tokenId']}' : null);
  }

  @override
  void dispose() {
    _recipient.dispose();
    _amount.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _token {
    for (final t in _wallet.tokenBalances) {
      if (t['tokenId'] == _tokenId) return t;
    }
    return null;
  }

  /// null = the token's definition is unknown (never guess 0: amounts would be scaled wrongly)
  int? get _decimalsOrNull => (_token?['decimals'] as num?)?.toInt();
  int get _decimals => _decimalsOrNull ?? 0;
  String get _symbol => '${_token?['symbol'] ?? ''}';
  String get _balanceBase => '${_token?['balance'] ?? '0'}';

  String? _validate() {
    if (_token == null || _decimalsOrNull == null) return 'tk_select'.tr;
    final r = _recipient.text.trim();
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(r) || !isChecksumValid(r)) return 'invalid_recipient'.tr;
    if (r.toLowerCase() == _wallet.address.value.toLowerCase()) return 'invalid_recipient'.tr;
    if (!isValidAmount(_amount.text, _decimals)) return 'invalid_amount'.tr;
    final base = BigInt.tryParse(toBaseUnits(_amount.text.trim(), _decimals));
    if (base == null || base <= BigInt.zero) return 'invalid_amount'.tr;
    if (base > (BigInt.tryParse(_balanceBase) ?? BigInt.zero)) return 'tk_insufficient'.tr;
    return null;
  }

  void _max() => setState(() => _amount.text = fromBaseUnits(_balanceBase, _decimals));

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    final a = extractAddress(d?.text ?? '');
    if (a == null) return jzToast('invalid_recipient'.tr, error: true);
    setState(() => _recipient.text = a);
  }

  Future<void> _scan() async {
    final code = await Get.to<String>(() => const QrScanPage());
    if (code == null) return;
    final a = extractAddress(code);
    if (a == null) return jzToast('invalid_recipient'.tr, error: true);
    setState(() => _recipient.text = a);
  }

  Future<void> _review() async {
    final err = _validate();
    if (err != null) return jzToast(err, error: true);
    final c = JzColors.of(context);
    final ok = await showJzSheet<bool>(
      context,
      title: 'review'.tr,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: JzAmount(prettyAmount(_amount.text.trim()), unit: _symbol, size: 30)),
        gap12,
        Divider(color: c.border),
        JzKv('tk_token'.tr, '${_token?['name'] ?? _symbol}'),
        JzKv('sending_to'.tr, _recipient.text.trim(), mono: true),
        JzKv('tk_fee'.tr, '${AppConfig.minimumFee} ${AppConfig.unit}', mono: true),
        gap4,
        Text('tk_fee_note'.tr, style: TextStyle(fontSize: 12, color: c.faint)),
        gap16,
        JzPrimaryButton(label: 'confirm_send'.tr, icon: Icons.check, onPressed: () => Get.back<bool>(result: true)),
        gap8,
        JzGhostButton(label: 'cancel'.tr, onPressed: () => Get.back<bool>(result: false)),
      ]),
    );
    if (ok != true) return;
    await _send();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final res = await _wallet.transferToken(tokenId: _tokenId!, amount: toBaseUnits(_amount.text.trim(), _decimals), recipient: _recipient.text.trim());
      final hash = res is Map ? '${res['hash'] ?? ''}' : '';
      _recipient.clear();
      _amount.clear();
      // the transfer lands a block or two later — catch-up refreshes so the balances follow without a manual reload
      unawaited(_wallet.reload());
      unawaited(Future<void>.delayed(const Duration(seconds: 7), _wallet.reload));
      unawaited(Future<void>.delayed(const Duration(seconds: 16), _wallet.reload));
      if (!mounted) return;
      await _sent(hash);
      Get.back<void>();
    } catch (e) {
      jzToast(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sent(String hash) async {
    final c = JzColors.of(context);
    await showJzSheet<void>(
      context,
      dismissible: false,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        gap8,
        Center(child: Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: c.okWeak), child: Icon(Icons.check_rounded, color: c.ok, size: 34))),
        gap16,
        Text('sent_title'.tr, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        gap8,
        Text('tk_sent_body'.tr, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.45)),
        if (hash.isNotEmpty) ...[
          gap12,
          Center(child: JzAddressPill(hash, head: 12, tail: 10)),
          gap12,
          JzGhostButton(
            label: 'open_explorer'.tr,
            icon: Icons.open_in_new,
            onPressed: () => launchUrl(Uri.parse('${AppConfig.explorerUrl}/tx/$hash'), mode: LaunchMode.externalApplication),
          ),
        ],
        gap8,
        JzPrimaryButton(label: 'done'.tr, onPressed: () => Get.back<void>()),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('tk_send'.tr)),
      body: SafeArea(
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.all(JzSpace.s4),
            children: [
              JzCard(
                child: Obx(() {
                  final held = _wallet.tokenBalances;
                  if (held.isEmpty) return JzEmpty(icon: Icons.toll_outlined, text: 'no_tokens'.tr);
                  if (_tokenId == null || !held.any((t) => t['tokenId'] == _tokenId)) _tokenId = '${held.first['tokenId']}';
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    JzField(
                      label: 'tk_token'.tr,
                      trailing: Text('${'balance'.tr}: ${formatToken(_balanceBase, _decimals)} $_symbol',
                          style: TextStyle(fontSize: 12, color: c.faint, fontFamily: kMono, fontFeatures: kTabular)),
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _tokenId,
                        isExpanded: true,
                        items: [
                          for (final t in held)
                            DropdownMenuItem(
                              value: '${t['tokenId']}',
                              child: Text('${t['symbol'] ?? '?'} — ${t['name'] ?? ''}', overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => setState(() => _tokenId = v),
                      ),
                    ),
                    gap16,
                    JzField(
                      label: 'recipient'.tr,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        _MiniAction(icon: Icons.content_paste_rounded, label: 'paste'.tr, onTap: _paste),
                        const SizedBox(width: 6),
                        _MiniAction(icon: Icons.qr_code_scanner_rounded, label: 'scan'.tr, onTap: _scan),
                      ]),
                      child: TextField(
                        controller: _recipient,
                        autocorrect: false,
                        style: const TextStyle(fontFamily: kMono, fontSize: 13.5),
                        decoration: InputDecoration(hintText: 'recipient_hint'.tr),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    gap16,
                    JzField(
                      label: 'amount'.tr,
                      child: TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontFamily: kMono, fontSize: 18, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: '0',
                          suffixIcon: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(_symbol, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.muted)),
                              const SizedBox(width: 8),
                              _MiniAction(label: 'max'.tr, onTap: _max),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    gap12,
                    Text('${'tk_fee'.tr}: ${AppConfig.minimumFee} ${AppConfig.unit}', style: TextStyle(fontSize: 12, color: c.faint, fontFamily: kMono, fontFeatures: kTabular)),
                  ]);
                }),
              ),
              gap16,
              JzPrimaryButton(label: _busy ? 'signing'.tr : 'review'.tr, icon: Icons.arrow_forward_rounded, busy: _busy, onPressed: _busy ? null : _review),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.label, required this.onTap, this.icon});
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: c.accentWeak, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c.accent), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.accent)),
        ]),
      ),
    );
  }
}
