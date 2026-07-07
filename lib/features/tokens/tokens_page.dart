import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/crypto/janzeer_crypto.dart' show TokenOp;
import '../../core/responsive/responsive.dart';
import '../../core/utils/format.dart';
import '../wallet/wallet_controller.dart';

/// Native tokens (JZT-1): multi-asset balances + an op-aware form (create/mint/burn/setcap/transfer).
/// Non-custodial — signing runs on a background isolate in WalletController; the node only verifies.
class TokensPage extends StatefulWidget {
  const TokensPage({super.key});
  @override
  State<TokensPage> createState() => _TokensPageState();
}

class _TokensPageState extends State<TokensPage> {
  final _wallet = Get.find<WalletController>();

  int _op = TokenOp.transfer;
  String? _tokenId; // selected token (from the registry dropdown)
  final _symbol = TextEditingController();
  final _name = TextEditingController();
  final _decimals = TextEditingController(text: '0');
  final _cap = TextEditingController();
  final _initial = TextEditingController();
  final _amount = TextEditingController();
  final _recipient = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _wallet.reload();
  }

  @override
  void dispose() {
    _symbol.dispose();
    _name.dispose();
    _decimals.dispose();
    _cap.dispose();
    _initial.dispose();
    _amount.dispose();
    _recipient.dispose();
    super.dispose();
  }

  void _toast(String m) => Get.snackbar('', m, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));

  Map<String, dynamic>? get _selectedToken {
    for (final t in _wallet.tokens) {
      if (t['tokenId'] == _tokenId) return t;
    }
    return null;
  }

  /// Decimals that drive the human→base-unit conversion: entered for CREATE, else from the selected token.
  int get _activeDecimals =>
      _op == TokenOp.create ? (int.tryParse(_decimals.text) ?? 0) : ((_selectedToken?['decimals'] as int?) ?? 0);

  /// The native-coin fee for the current op: CREATE pays the flat token-create fee, everything else the minimum.
  String get _fee => _op == TokenOp.create ? AppConfig.tokenCreateFee : AppConfig.minimumFee;

  /// A token tx confirms a block or two later — re-pull balances/registry so the assets list and the token
  /// picker update on their own (no more leaving the tab and coming back). Fires two catch-up refreshes.
  void _scheduleRefresh() {
    unawaited(_wallet.reload());
    unawaited(Future<void>.delayed(const Duration(seconds: 7), _wallet.reload));
    unawaited(Future<void>.delayed(const Duration(seconds: 16), _wallet.reload));
  }

  bool _shows(String f) {
    switch (_op) {
      case TokenOp.create:
        return const ['symbol', 'name', 'decimals', 'cap', 'initial'].contains(f);
      case TokenOp.mint:
      case TokenOp.burn:
        return const ['token', 'amount'].contains(f);
      case TokenOp.setcap:
        return const ['token', 'cap'].contains(f);
      case TokenOp.transfer:
        return const ['token', 'amount', 'recipient'].contains(f);
    }
    return false;
  }

  String? _validate() {
    if (_op == TokenOp.create) {
      final s = _symbol.text.trim();
      if (s.isEmpty || s.length > 12) return 'tk_need_symbol'.tr;
      if (_name.text.trim().isEmpty) return 'tk_need_name'.tr;
      final d = int.tryParse(_decimals.text);
      if (d == null || d < 0 || d > 18) return 'tk_need_decimals'.tr;
      final c = double.tryParse(_cap.text);
      if (c == null || c <= 0) return 'tk_need_cap'.tr;
      return null;
    }
    if (_tokenId == null || _tokenId!.isEmpty) return 'tk_need_token'.tr;
    if (_op == TokenOp.mint || _op == TokenOp.burn || _op == TokenOp.transfer) {
      final a = double.tryParse(_amount.text);
      if (a == null || a <= 0) return 'tk_need_amount'.tr;
    }
    if (_op == TokenOp.setcap) {
      final c = double.tryParse(_cap.text);
      if (c == null || c < 0) return 'tk_need_cap'.tr;
    }
    if (_op == TokenOp.transfer && !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(_recipient.text.trim())) {
      return 'tk_need_recipient'.tr;
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) return _toast(err);
    setState(() => _busy = true);
    try {
      final d = _activeDecimals;
      switch (_op) {
        case TokenOp.create:
          final dd = int.parse(_decimals.text);
          await _wallet.createToken(
            symbol: _symbol.text.trim(),
            name: _name.text.trim(),
            decimals: dd,
            cap: toBaseUnits(_cap.text, dd),
            initialSupply: toBaseUnits(_initial.text.isEmpty ? '0' : _initial.text, dd),
          );
          _toast('tk_created'.tr);
          break;
        case TokenOp.mint:
          await _wallet.mintToken(tokenId: _tokenId!, amount: toBaseUnits(_amount.text, d));
          _toast('tk_submitted'.tr);
          break;
        case TokenOp.burn:
          await _wallet.burnToken(tokenId: _tokenId!, amount: toBaseUnits(_amount.text, d));
          _toast('tk_submitted'.tr);
          break;
        case TokenOp.setcap:
          await _wallet.setTokenCap(tokenId: _tokenId!, cap: toBaseUnits(_cap.text, d));
          _toast('tk_submitted'.tr);
          break;
        case TokenOp.transfer:
          await _wallet.transferToken(tokenId: _tokenId!, amount: toBaseUnits(_amount.text, d), recipient: _recipient.text.trim());
          _toast('tk_submitted'.tr);
          break;
      }
      _symbol.clear();
      _name.clear();
      _cap.clear();
      _initial.clear();
      _amount.clear();
      _recipient.clear();
      _scheduleRefresh();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ops = const [TokenOp.transfer, TokenOp.create, TokenOp.mint, TokenOp.burn, TokenOp.setcap];
    const opKey = {
      TokenOp.transfer: 'tk_transfer',
      TokenOp.create: 'tk_create',
      TokenOp.mint: 'tk_mint',
      TokenOp.burn: 'tk_burn',
      TokenOp.setcap: 'tk_setcap',
    };
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('tokens'.tr),
        actions: [
          Obx(() => IconButton(
                icon: _wallet.loading.value
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                tooltip: 'refresh'.tr,
                onPressed: _wallet.loading.value ? null : _wallet.reload,
              )),
        ],
      ),
      body: SafeArea(
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('tk_assets'.tr, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Obx(() => Card(
                    child: Column(children: [
                      ListTile(
                        title: const Text('JNZ'),
                        trailing: Text(prettyAmount(_wallet.balance.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      ..._wallet.tokenBalances.map((tb) => ListTile(
                            title: Text((tb['symbol'] as String).isEmpty ? '?' : tb['symbol'] as String),
                            subtitle: Text(shortHash(tb['tokenId'] as String), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                            trailing: Text(formatToken(tb['balance'] as String, tb['decimals'] as int), style: const TextStyle(fontWeight: FontWeight.w600)),
                          )),
                      if (_wallet.tokenBalances.isEmpty)
                        ListTile(title: Text('tk_none'.tr, style: TextStyle(color: Theme.of(context).disabledColor))),
                    ]),
                  )),
              const SizedBox(height: 16),
              Text('tk_op'.tr, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ops
                    .map((o) => ChoiceChip(
                          label: Text(opKey[o]!.tr),
                          selected: _op == o,
                          onSelected: (_) => setState(() => _op = o),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              if (_op != TokenOp.transfer)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _op == TokenOp.create ? 'tk_create_hint'.tr : 'tk_issuer_hint'.tr,
                    style: TextStyle(fontSize: 12.5, color: scheme.primary),
                  ),
                ),
              if (_shows('token'))
                Obx(() => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: _tokenId,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: 'tk_token'.tr),
                        hint: Text('tk_select'.tr),
                        items: _wallet.tokens
                            .map((t) => DropdownMenuItem(
                                  value: t['tokenId'] as String,
                                  child: Text('${t['symbol']} — ${t['name']}', overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _tokenId = v),
                      ),
                    )),
              if (_shows('symbol')) _field(_symbol, 'tk_symbol', maxLength: 12),
              if (_shows('name')) _field(_name, 'tk_name', maxLength: 40),
              if (_shows('decimals')) _field(_decimals, 'tk_decimals', number: true),
              if (_shows('initial')) _field(_initial, 'tk_initial', number: true),
              if (_shows('amount')) _field(_amount, 'tk_amount', number: true),
              if (_shows('cap')) _field(_cap, _op == TokenOp.setcap ? 'tk_newcap' : 'tk_cap', number: true),
              if (_shows('recipient')) _field(_recipient, 'tk_recipient', hint: '0x…'),
              // Make the native-coin fee explicit — CREATE costs 5 JNZ, other ops 0.01 JNZ.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${'tk_fee'.tr}: $_fee ${AppConfig.unit}', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text('tk_submit'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String labelKey, {bool number = false, int? maxLength, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLength: maxLength,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(labelText: labelKey.tr, hintText: hint),
        ),
      );
}
