import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../wallet/wallet_controller.dart';

/// Read-only recent transfers for this wallet (sender or recipient), newest first.
class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});
  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final _wallet = Get.find<WalletController>();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _wallet.recentTransfers();
  }

  Future<void> _reload() async {
    setState(() => _future = _wallet.recentTransfers());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final me = _wallet.address.value;
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = (snap.data?['list'] as List?) ?? const [];
          if (list.isEmpty) {
            return ListView(children: [const SizedBox(height: 80), Center(child: Text('no_transfers'.tr))]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final tx = list[i] as Map<String, dynamic>;
              final outgoing = tx['senderAddress'] == me;
              final ts = tx['timestamp'];
              final when = ts == null ? '' : DateFormat('MMM d, HH:mm').format(DateTime.fromMillisecondsSinceEpoch((ts as num).toInt()));
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (outgoing ? Colors.red : Colors.green).withValues(alpha: 0.15),
                  child: Icon(outgoing ? Icons.north_east : Icons.south_west, color: outgoing ? Colors.red : Colors.green),
                ),
                title: Text('${tx['amount'] ?? ''}'),
                subtitle: Text('${outgoing ? tx['recipientAddress'] : tx['senderAddress']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(when, style: Theme.of(context).textTheme.bodySmall),
              );
            },
          );
        },
      ),
    );
  }
}
