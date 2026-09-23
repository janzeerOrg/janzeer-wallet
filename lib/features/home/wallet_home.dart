import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/jz_tokens.dart';
import '../../core/ui/jz.dart';
import '../../core/utils/format.dart';
import '../send/qr_scan_page.dart';
import '../send/send_page.dart';
import '../wallet/wallet_controller.dart';

/// Wallet tab — the explorer's wallet home, on a phone: the hero (balance, address, nonce, live), three actions
/// (Send · Receive · Scan) and the tabs Activity · Tokens · Validator (`.wtabs`).
class WalletHome extends StatefulWidget {
  const WalletHome({super.key});
  @override
  State<WalletHome> createState() => _WalletHomeState();
}

class _WalletHomeState extends State<WalletHome> {
  int _tab = 0;

  Future<void> _scan() async {
    final code = await Get.to<String>(() => const QrScanPage());
    if (code == null) return;
    final m = RegExp(r'0x[0-9a-fA-F]{40}').firstMatch(code);
    if (m == null) return jzToast('invalid_recipient'.tr, error: true);
    Get.to<void>(() => SendPage(initialRecipient: m.group(0)!, initialAmount: _amountFrom(code)));
  }

  /// `janzeer:pay?…&amount=…` / `…?amount=…` — the request-amount form the receive screen and the payment layer use.
  String? _amountFrom(String code) => RegExp(r'[?&]amount=([0-9.]+)').firstMatch(code)?.group(1);

  @override
  Widget build(BuildContext context) {
    final w = Get.find<WalletController>();
    return RefreshIndicator(
      onRefresh: w.reload,
      child: ListView(
        padding: const EdgeInsets.all(JzSpace.s4),
        children: [
          _Hero(w: w),
          gap12,
          Row(children: [
            Expanded(child: JzActionTile(icon: Icons.north_east_rounded, label: 'send'.tr, primary: true, onTap: () => Get.toNamed(Routes.send))),
            const SizedBox(width: JzSpace.s3),
            Expanded(child: JzActionTile(icon: Icons.south_west_rounded, label: 'receive'.tr, onTap: () => Get.toNamed(Routes.receive))),
            const SizedBox(width: JzSpace.s3),
            Expanded(child: JzActionTile(icon: Icons.qr_code_scanner_rounded, label: 'scan'.tr, onTap: _scan)),
          ]),
          Obx(() => w.hasFaucet.value ? Padding(padding: const EdgeInsets.only(top: JzSpace.s3), child: _FaucetButton(w: w)) : const SizedBox.shrink()),
          gap16,
          JzCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              JzTabs(
                tabs: [(Icons.receipt_long_outlined, 'activity'.tr), (Icons.toll_outlined, 'tokens'.tr), (Icons.bolt_outlined, 'validator'.tr)],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              switch (_tab) {
                0 => const _ActivityPanel(),
                1 => _TokensPanel(w: w),
                _ => const _ValidatorPanel(),
              },
            ]),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.w});
  final WalletController w;

  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return JzCard(
      hero: true,
      padding: const EdgeInsets.all(JzSpace.s5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          JzStatLabel('balance'.tr),
          const Spacer(),
          Obx(() => w.loading.value
              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.muted))
              : InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: w.reload,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 7, color: c.ok),
                      const SizedBox(width: 6),
                      Text('refresh'.tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
                    ]),
                  ),
                )),
        ]),
        gap8,
        Obx(() => JzAmount(prettyAmount(w.balance.value), unit: AppConfig.unit, size: 34)),
        gap4,
        Text('balance_hint'.tr, style: TextStyle(fontSize: 12, color: c.faint)),
        gap16,
        Row(children: [
          Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: Obx(() => JzAddressPill(w.address.value)))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            JzStatLabel('next_nonce'.tr),
            Obx(() => Text('${w.nonce.value}', style: TextStyle(fontFamily: kMono, fontFeatures: kTabular, fontSize: 16, fontWeight: FontWeight.w700, color: c.text))),
          ]),
        ]),
      ]),
    );
  }
}

class _FaucetButton extends StatelessWidget {
  const _FaucetButton({required this.w});
  final WalletController w;
  @override
  Widget build(BuildContext context) => JzGhostButton(
        label: 'faucet'.tr,
        icon: Icons.water_drop_outlined,
        onPressed: () async {
          try {
            final hash = await w.requestFaucet();
            jzToast('faucet_sent'.trParams({'hash': '${hash.substring(0, 12)}…'}));
            await w.reload();
          } catch (e) {
            jzToast(e.toString().replaceFirst('Exception: ', ''), error: true);
          }
        },
      );
}

/// This wallet's activity: pending (mempool) transfers first, then confirmed, 10 at a time with "load more".
class _ActivityPanel extends StatefulWidget {
  const _ActivityPanel();
  @override
  State<_ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends State<_ActivityPanel> {
  final _w = Get.find<WalletController>();
  final List<Map<String, dynamic>> _pending = [];
  final List<Map<String, dynamic>> _confirmed = [];
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final results = await Future.wait([
        _w.myTransfers(unconfirmed: true, size: 20),
        _w.myTransfers(page: 0, size: 10),
      ]);
      _pending
        ..clear()
        ..addAll(((results[0]['list'] as List?) ?? const []).cast<Map<String, dynamic>>());
      _confirmed
        ..clear()
        ..addAll(((results[1]['list'] as List?) ?? const []).cast<Map<String, dynamic>>());
      _page = 0;
      _hasMore = ((results[1]['totalPages'] as num?)?.toInt() ?? 0) > 1;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final r = await _w.myTransfers(page: _page + 1, size: 10);
      _confirmed.addAll(((r['list'] as List?) ?? const []).cast<Map<String, dynamic>>());
      _page += 1;
      _hasMore = _page + 1 < ((r['totalPages'] as num?)?.toInt() ?? 0);
    } catch (_) {
      // keep what we have
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Pending + outgoing + the node reports the nonce (0.1.0+) → "Speed up": the same transfer, a higher fee.
  Future<void> _speedUp(Map<String, dynamic> tx) async {
    final oldFee = double.tryParse('${tx['fee']}') ?? 0.01;
    final suggested = (oldFee * 2 > oldFee + 0.01 ? oldFee * 2 : oldFee + 0.01);
    final feeCtl = TextEditingController(text: suggested.toStringAsFixed(2));
    final c = JzColors.of(context);
    final fee = await showJzSheet<String>(
      context,
      title: 'speed_up'.tr,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('speed_up_note'.tr, style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.45)),
        gap16,
        JzField(
          label: '${'new_fee'.tr} (${AppConfig.unit})',
          child: TextField(
            controller: feeCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontFamily: kMono),
            decoration: InputDecoration(helperText: '${'current_fee'.tr}: ${tx['fee']}'),
          ),
        ),
        gap16,
        JzPrimaryButton(label: 'speed_up_confirm'.tr, icon: Icons.speed, onPressed: () => Get.back<String>(result: feeCtl.text.trim())),
      ]),
    );
    if (fee == null || fee.isEmpty) return;
    try {
      await _w.speedUpTransfer(tx, fee);
      jzToast('speed_up_sent'.tr);
      await _initialLoad();
    } catch (e) {
      jzToast('$e', error: true);
    }
  }

  void _detail(Map<String, dynamic> tx, bool pending) {
    final me = _w.address.value;
    final outgoing = tx['senderAddress'] == me;
    final c = JzColors.of(context);
    showJzSheet<void>(
      context,
      title: outgoing ? 'send'.tr : 'receive'.tr,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          JzAmount('${outgoing ? '−' : '+'}${prettyAmount('${tx['amount'] ?? '0'}')}', unit: AppConfig.unit, size: 26, color: outgoing ? c.text : c.ok),
          const Spacer(),
          JzTag(pending ? 'pending'.tr : 'confirmed'.tr, kind: pending ? JzTagKind.pending : JzTagKind.ok),
        ]),
        gap12,
        Divider(color: c.border),
        JzKv(outgoing ? 'recipient'.tr : 'sending_to'.tr, '${outgoing ? tx['recipientAddress'] : tx['senderAddress']}', mono: true),
        JzKv('fee'.tr, '${tx['fee'] ?? ''} ${AppConfig.unit}', mono: true),
        if ((tx['data'] ?? '').toString().isNotEmpty) JzKv('memo'.tr, '${tx['data']}'),
        if (tx['nonce'] != null) JzKv('next_nonce'.tr, '${tx['nonce']}', mono: true),
        JzKv('height'.tr, tx['blockHeight'] == null ? '—' : '${tx['blockHeight']}', mono: true),
        JzKv('transactions'.tr, '${tx['hash'] ?? ''}', mono: true),
        gap16,
        if (pending && outgoing && tx['nonce'] != null)
          JzPrimaryButton(
              label: 'speed_up'.tr,
              icon: Icons.speed,
              onPressed: () {
                Get.back<void>();
                _speedUp(tx);
              })
        else
          JzGhostButton(label: 'done'.tr, onPressed: () => Get.back<void>()),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(12), child: JzSkeletonList());
    }
    final me = _w.address.value;
    final items = [..._pending, ..._confirmed];
    if (_error.isNotEmpty) {
      return JzEmpty(
        icon: Icons.cloud_off_outlined,
        text: _error,
        action: JzGhostButton(label: 'refresh'.tr, icon: Icons.refresh, expand: false, onPressed: _initialLoad),
      );
    }
    if (items.isEmpty) return JzEmpty(icon: Icons.receipt_long_outlined, text: 'no_transfers'.tr);
    return Column(children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) Divider(height: 1, color: c.border),
        _TxRow(items[i], me: me, pending: i < _pending.length, onTap: () => _detail(items[i], i < _pending.length)),
      ],
      if (_hasMore)
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextButton.icon(
            onPressed: _loadingMore ? null : _loadMore,
            icon: _loadingMore ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more, size: 18),
            label: Text('load_more'.tr),
          ),
        ),
    ]);
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow(this.tx, {required this.me, required this.pending, required this.onTap});
  final Map<String, dynamic> tx;
  final String me;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    final outgoing = tx['senderAddress'] == me;
    final counterparty = outgoing ? tx['recipientAddress'] : tx['senderAddress'];
    final tone = pending ? c.pending : (outgoing ? c.text : c.ok);
    final disc = pending ? c.pendingWeak : (outgoing ? c.surface3 : c.okWeak);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: disc),
            child: Icon(pending ? Icons.hourglass_top_rounded : (outgoing ? Icons.north_east_rounded : Icons.south_west_rounded), size: 18, color: pending ? c.pending : (outgoing ? c.muted : c.ok)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(outgoing ? 'send'.tr : 'receive'.tr, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 2),
              JzMono(shortHash('${counterparty ?? ''}', head: 8, tail: 6), size: 12),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${outgoing ? '−' : '+'}${prettyAmount('${tx['amount'] ?? '0'}')}',
                style: TextStyle(fontFamily: kMono, fontFeatures: kTabular, fontSize: 14, fontWeight: FontWeight.w700, color: tone)),
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (pending) ...[JzTag('pending'.tr, kind: JzTagKind.pending), const SizedBox(width: 6)],
              Text(timeAgo(tx['timestamp']), style: TextStyle(fontSize: 11.5, color: c.faint)),
            ]),
          ]),
        ]),
      ),
    );
  }
}

/// Tokens tab: the JZT-1 balances this address holds + "Manage" → the token operations page.
class _TokensPanel extends StatelessWidget {
  const _TokensPanel({required this.w});
  final WalletController w;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Obx(() {
      final list = w.tokenBalances;
      return Column(children: [
        if (list.isEmpty)
          JzEmpty(icon: Icons.toll_outlined, text: 'no_tokens'.tr)
        else
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.accentWeak),
                  child: Text('${list[i]['symbol'] ?? '?'}'.substring(0, 1), style: TextStyle(fontWeight: FontWeight.w800, color: c.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${list[i]['name'] ?? list[i]['symbol'] ?? ''}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text)),
                    JzMono(shortHash('${list[i]['tokenId'] ?? ''}', head: 8, tail: 6), size: 11.5),
                  ]),
                ),
                JzAmount(formatToken('${list[i]['balance'] ?? '0'}', (list[i]['decimals'] as num?)?.toInt() ?? 0), unit: '${list[i]['symbol'] ?? ''}', size: 15),
              ]),
            ),
          ],
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          child: Row(children: [
            Expanded(child: Text('tokens_sub'.tr, style: TextStyle(fontSize: 12.5, color: c.faint))),
            const SizedBox(width: 10),
            JzGhostButton(label: 'manage'.tr, icon: Icons.tune, expand: false, onPressed: () => Get.toNamed(Routes.tokens)),
          ]),
        ),
      ]);
    });
  }
}

/// Validator tab: what it is, and the way to the register/exit page.
class _ValidatorPanel extends StatelessWidget {
  const _ValidatorPanel();
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: c.accentWeak), child: Icon(Icons.bolt, color: c.accent, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text('validator_status'.tr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text))),
        ]),
        gap8,
        Text('validator_sub'.tr, style: TextStyle(fontSize: 13, color: c.muted, height: 1.45)),
        gap4,
        Text('${'deposit'.tr}: 2000 ${AppConfig.unit} · ${'non_refundable'.tr}', style: TextStyle(fontSize: 12, color: c.faint)),
        gap12,
        JzGhostButton(label: 'manage'.tr, icon: Icons.tune, onPressed: () => Get.toNamed(Routes.validator)),
      ]),
    );
  }
}
