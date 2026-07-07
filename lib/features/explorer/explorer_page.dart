import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/format.dart';
import '../wallet/wallet_controller.dart';

/// Network explorer: live stat header, latest blocks, the mempool (pending transfers) and latest confirmed
/// transfers — mirrors the web explorer. Pull to refresh (the node's WebSocket push is off, so we poll on
/// demand rather than stream).
class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});
  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final _wallet = Get.find<WalletController>();
  late Future<_ExplorerData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ExplorerData> _load() async {
    final results = await Future.wait([
      _wallet.networkInfo(),
      _wallet.latestBlocks(size: 10),
      _wallet.pendingTransfers(size: 20),
      _wallet.latestTransfers(size: 12),
    ]);
    return _ExplorerData(
      info: results[0],
      blocks: (results[1]['list'] as List?) ?? const [],
      pending: (results[2]['list'] as List?) ?? const [],
      confirmed: (results[3]['list'] as List?) ?? const [],
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<_ExplorerData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return ListView(children: [const SizedBox(height: 80), Center(child: Text('${snap.error ?? ''}'.replaceFirst('Exception: ', '')))]);
          }
          final d = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _StatHeader(info: d.info),
              const SizedBox(height: 16),
              _Section(title: 'latest_blocks'.tr, count: d.blocks.length),
              if (d.blocks.isEmpty) _empty('no_blocks'.tr) else ...d.blocks.map((b) => _BlockTile(b as Map<String, dynamic>)),
              const SizedBox(height: 16),
              _Section(title: 'mempool'.tr, count: d.pending.length, chip: 'pending'.tr, chipColor: Colors.orange),
              if (d.pending.isEmpty) _empty('mempool_empty'.tr)
              else ...d.pending.map((t) => _TxTile(t as Map<String, dynamic>, me: _wallet.address.value, pending: true)),
              const SizedBox(height: 16),
              _Section(title: 'transactions'.tr, count: d.confirmed.length, chip: 'confirmed'.tr, chipColor: Colors.green),
              if (d.confirmed.isEmpty) _empty('no_transfers'.tr) else ...d.confirmed.map((t) => _TxTile(t as Map<String, dynamic>, me: _wallet.address.value, pending: false)),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(String msg) => Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(msg, style: const TextStyle(color: Colors.grey))));
}

class _ExplorerData {
  final Map<String, dynamic> info;
  final List<dynamic> blocks, pending, confirmed;
  _ExplorerData({required this.info, required this.blocks, required this.pending, required this.confirmed});
}

class _StatHeader extends StatelessWidget {
  final Map<String, dynamic> info;
  const _StatHeader({required this.info});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget stat(String label, String value) => Expanded(
          child: Column(children: [
            Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.bold, color: cs.primary)),
            Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(children: [
          stat('height'.tr, '${info['blocksCount'] ?? 0}'),
          stat('tps'.tr, '${info['transactionsPerSecond'] ?? 0}'),
          stat('validators'.tr, '${info['validatorsCount'] ?? 0}'),
          stat('nodes', '${info['nodesCount'] ?? 0}'),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final int count;
  final String? chip;
  final Color? chipColor;
  const _Section({required this.title, required this.count, this.chip, this.chipColor});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4, left: 4, right: 4),
      child: Row(children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        Text('$count', style: Theme.of(context).textTheme.bodySmall),
        const Spacer(),
        if (chip != null) _Chip(chip!, chipColor ?? Colors.grey),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _BlockTile extends StatelessWidget {
  final Map<String, dynamic> b;
  const _BlockTile(this.b);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: CircleAvatar(backgroundColor: cs.primary.withValues(alpha: 0.12), child: Icon(Icons.widgets_outlined, color: cs.primary, size: 20)),
      title: Text('#${b['height']}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
      subtitle: Text('${b['transactionsCount'] ?? 0} ${'txns'.tr} · ${shortHash('${b['publicKey'] ?? ''}', head: 8, tail: 6)}'),
      trailing: Text(timeAgo(b['timestamp']), style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _TxTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  final String me;
  final bool pending;
  const _TxTile(this.tx, {required this.me, required this.pending});
  @override
  Widget build(BuildContext context) {
    final outgoing = tx['senderAddress'] == me;
    final color = pending ? Colors.orange : (outgoing ? Colors.red : Colors.green);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(pending ? Icons.hourglass_top : (outgoing ? Icons.north_east : Icons.south_west), color: color, size: 20),
      ),
      title: Text('${prettyAmount('${tx['amount'] ?? '0'}')} ${AppConfig.unit}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${shortHash('${tx['senderAddress'] ?? ''}', head: 7, tail: 5)} → ${shortHash('${tx['recipientAddress'] ?? ''}', head: 7, tail: 5)}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      trailing: Text(timeAgo(tx['timestamp']), style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
