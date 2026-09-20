import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/responsive/responsive.dart';
import '../wallet/wallet_controller.dart';
import 'qr_scan_page.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key});
  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final _wallet = Get.find<WalletController>();
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
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

  String? _validate() {
    final r = _recipient.text.trim();
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(r)) return 'invalid_recipient'.tr;
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt < 0) return 'invalid_amount'.tr;
    if (amt == 0 && _memo.text.isEmpty) return 'invalid_amount'.tr;
    // the node's limit is 256 BYTES of UTF-8 — an Arabic letter is 2, an emoji 4 (online test F-005)
    if (utf8.encode(_memo.text.trim()).length > AppConfig.maxMemo) return 'memo_too_long'.tr;
    return null;
  }

  Future<void> _send() async {
    final err = _validate();
    if (err != null) return _toast(err);
    setState(() => _busy = true);
    try {
      await _wallet.sendTransfer(
        recipientAddress: _recipient.text,
        amount: _amount.text.isEmpty ? '0' : _amount.text,
        fee: _fee.text,
        data: _memo.text,
      );
      // Clear the form on success so nothing lingers if we stay on the page. (send-field fix)
      _recipient.clear();
      _amount.clear();
      _memo.clear();
      _fee.text = AppConfig.minimumFee;
      _toast('send_submitted'.tr);
      Get.back<void>();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await Get.to<String>(() => const QrScanPage());
    if (code == null) return;
    // Accept a bare address or a URI payload (e.g. ethereum:0x…?value=…) — extract the first 0x-address.
    final m = RegExp(r'0x[0-9a-fA-F]{40}').firstMatch(code);
    if (m == null) return _toast('invalid_recipient'.tr);
    setState(() => _recipient.text = m.group(0)!);
  }

  void _toast(String m) => Get.snackbar('', m, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('send'.tr)),
      body: SafeArea(
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _recipient,
                decoration: InputDecoration(
                  labelText: 'recipient'.tr,
                  hintText: '0x…',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'scan_qr'.tr,
                    onPressed: _scan,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'amount'.tr)),
              const SizedBox(height: 12),
              TextField(controller: _fee, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'fee'.tr)),
              const SizedBox(height: 12),
              TextField(controller: _memo, maxLength: AppConfig.maxMemo, // characters; the byte limit is enforced in _validate() decoration: InputDecoration(labelText: 'memo'.tr)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _send,
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                label: Text('send'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
