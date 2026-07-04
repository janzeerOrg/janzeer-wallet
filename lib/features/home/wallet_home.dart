import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/format.dart';
import '../wallet/wallet_controller.dart';

/// Wallet tab: a hero balance card, nonce stat, and quick actions (Send / Receive / Validator).
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
              Expanded(child: _ActionButton(icon: Icons.bolt, label: 'validator'.tr, tonal: true, onTap: () => Get.toNamed(Routes.validator))),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() => w.loading.value
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
              : const SizedBox.shrink()),
          const SizedBox(height: 8),
          // This wallet's latest transactions (send/receive, confirmed/pending) with load-more.
          const _ActivitySection(),
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

/// This wallet's activity: pending (mempool) transfers first, then confirmed, 10 at a time with "load more".
class _ActivitySection extends StatefulWidget {
  const _ActivitySection();
  @override
  State<_ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends State<_ActivitySection> {
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
    setState(() { _loading = true; _error = ''; });
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()));
    }
    final me = _w.address.value;
    final items = [..._pending, ..._confirmed];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(children: [
            Text('recent_activity'.tr, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _initialLoad, tooltip: 'refresh'.tr),
          ]),
        ),
        if (_error.isNotEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text(_error, style: const TextStyle(color: Colors.grey)))
        else if (items.isEmpty)
          const _EmptyActivity()
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _TxRow(items[i], me: me, pending: i < _pending.length),
                ],
              ],
            ),
          ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: _loadingMore ? null : _loadMore,
                icon: _loadingMore
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.expand_more),
                label: Text('load_more'.tr),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(children: [
        Icon(Icons.receipt_long_outlined, size: 34, color: Theme.of(context).disabledColor),
        const SizedBox(height: 8),
        Text('no_transfers'.tr, style: const TextStyle(color: Colors.grey)),
      ]),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow(this.tx, {required this.me, required this.pending});
  final Map<String, dynamic> tx;
  final String me;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final outgoing = tx['senderAddress'] == me;
    final amountColor = pending ? Colors.orange : (outgoing ? Colors.red : Colors.green);
    final counterparty = outgoing ? tx['recipientAddress'] : tx['senderAddress'];
    final statusColor = pending ? Colors.orange : Colors.green;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: amountColor.withValues(alpha: 0.15),
        child: Icon(pending ? Icons.hourglass_top : (outgoing ? Icons.north_east : Icons.south_west), color: amountColor, size: 20),
      ),
      title: Text('${outgoing ? '-' : '+'}${prettyAmount('${tx['amount'] ?? '0'}')} ${AppConfig.unit}',
          style: TextStyle(fontWeight: FontWeight.w600, color: amountColor)),
      subtitle: Text(shortHash('${counterparty ?? ''}', head: 10, tail: 8), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
            child: Text(pending ? 'pending'.tr : 'confirmed'.tr, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 2),
          Text(timeAgo(tx['timestamp']), style: Theme.of(context).textTheme.bodySmall),
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
