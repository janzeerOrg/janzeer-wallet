import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/jz_tokens.dart';
import '../../core/ui/jz.dart';
import '../../core/utils/format.dart';
import '../wallet/wallet_controller.dart';
import 'qr_scan_page.dart';

/// Send: recipient (paste · scan), amount with Max, fee, memo with the byte counter → a review sheet → sign →
/// a "Sent" sheet with the hash. The form never submits without the review step.
class SendPage extends StatefulWidget {
  const SendPage({super.key, this.initialRecipient, this.initialAmount});
  final String? initialRecipient;
  final String? initialAmount;
  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final _wallet = Get.find<WalletController>();
  late final _recipient = TextEditingController(text: widget.initialRecipient ?? '');
  late final _amount = TextEditingController(text: widget.initialAmount ?? '');
  final _fee = TextEditingController(text: AppConfig.minimumFee);
  final _memo = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _recipient.dispose();
    _amount.dispose();
    _fee.dispose();
    _memo.dispose();
    super.dispose();
  }

  int get _memoBytes => utf8.encode(_memo.text.trim()).length;

  String? _validate() {
    final r = _recipient.text.trim();
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(r)) return 'invalid_recipient'.tr;
    if (r.toLowerCase() == _wallet.address.value.toLowerCase()) return 'invalid_recipient'.tr;
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt < 0) return 'invalid_amount'.tr;
    if (amt == 0 && _memo.text.isEmpty) return 'invalid_amount'.tr;
    if (double.tryParse(_fee.text) == null) return 'invalid_amount'.tr;
    // the node's limit is 256 BYTES of UTF-8 — an Arabic letter is 2, an emoji 4 (online test F-005)
    if (_memoBytes > AppConfig.maxMemo) return 'memo_too_long'.tr;
    return null;
  }

  void _max() {
    final bal = double.tryParse(_wallet.balance.value) ?? 0;
    final fee = double.tryParse(_fee.text) ?? 0.01;
    final m = bal - fee;
    setState(() => _amount.text = m > 0 ? m.toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '') : '0');
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    final m = RegExp(r'0x[0-9a-fA-F]{40}').firstMatch(d?.text ?? '');
    if (m == null) return jzToast('invalid_recipient'.tr, error: true);
    setState(() => _recipient.text = m.group(0)!);
  }

  Future<void> _scan() async {
    final code = await Get.to<String>(() => const QrScanPage());
    if (code == null) return;
    final m = RegExp(r'0x[0-9a-fA-F]{40}').firstMatch(code);
    if (m == null) return jzToast('invalid_recipient'.tr, error: true);
    final amount = RegExp(r'[?&]amount=([0-9.]+)').firstMatch(code)?.group(1);
    setState(() {
      _recipient.text = m.group(0)!;
      if (amount != null && _amount.text.isEmpty) _amount.text = amount;
    });
  }

  Future<void> _review() async {
    final err = _validate();
    if (err != null) return jzToast(err, error: true);
    final c = JzColors.of(context);
    final amount = _amount.text.isEmpty ? '0' : _amount.text;
    final total = (double.parse(amount) + double.parse(_fee.text)).toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '');
    final ok = await showJzSheet<bool>(
      context,
      title: 'review'.tr,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: JzAmount(prettyAmount(amount), unit: AppConfig.unit, size: 30)),
        gap12,
        Divider(color: c.border),
        JzKv('sending_to'.tr, _recipient.text.trim(), mono: true),
        JzKv('fee'.tr, '${_fee.text} ${AppConfig.unit}', mono: true),
        JzKv('total'.tr, '$total ${AppConfig.unit}', mono: true),
        if (_memo.text.trim().isNotEmpty) JzKv('memo'.tr, _memo.text.trim()),
        gap4,
        Text('fee_note'.tr, style: TextStyle(fontSize: 12, color: c.faint)),
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
      final hash = await _wallet.sendTransfer(
        recipientAddress: _recipient.text.trim(),
        amount: _amount.text.isEmpty ? '0' : _amount.text,
        fee: _fee.text,
        data: _memo.text,
      );
      _recipient.clear();
      _amount.clear();
      _memo.clear();
      _fee.text = AppConfig.minimumFee;
      if (!mounted) return;
      await _sent(hash);
      Get.back<void>();
    } catch (e) {
      jzToast(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sent(String? hash) async {
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
        Text('sent_body'.tr, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.45)),
        if (hash != null && hash.isNotEmpty) ...[
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
    final bytes = _memoBytes;
    return Scaffold(
      appBar: AppBar(title: Text('send_jnz'.tr)),
      body: SafeArea(
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.all(JzSpace.s4),
            children: [
              JzCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                    trailing: Obx(() => Text('${'balance'.tr}: ${prettyAmount(_wallet.balance.value)} ${AppConfig.unit}', style: TextStyle(fontSize: 12, color: c.faint, fontFamily: kMono, fontFeatures: kTabular))),
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontFamily: kMono, fontSize: 18, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        suffixIcon: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(AppConfig.unit, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.muted)),
                            const SizedBox(width: 8),
                            _MiniAction(label: 'max'.tr, onTap: _max),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  gap16,
                  Row(children: [
                    Expanded(
                      child: JzField(
                        label: 'fee'.tr,
                        child: TextField(
                          controller: _fee,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontFamily: kMono, fontSize: 14),
                          decoration: InputDecoration(suffixText: AppConfig.unit),
                        ),
                      ),
                    ),
                  ]),
                  gap16,
                  JzField(
                    label: 'memo'.tr,
                    trailing: Text('$bytes / ${AppConfig.maxMemo} B', style: TextStyle(fontSize: 11.5, color: bytes > AppConfig.maxMemo ? c.danger : c.faint, fontFamily: kMono, fontFeatures: kTabular)),
                    child: TextField(
                      controller: _memo,
                      maxLines: 2,
                      minLines: 1,
                      decoration: const InputDecoration(hintText: '—'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
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
