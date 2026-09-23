import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/jz_tokens.dart';
import '../../core/ui/jz.dart';
import '../wallet/wallet_controller.dart';

/// Receive: a large QR on white (scanners need contrast in both themes), the full address, Copy, and an optional
/// requested amount that becomes a `janzeer:pay?to=…&amount=…` URI — the same form the payment layer will use.
class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});
  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  final _amount = TextEditingController();
  bool _request = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _payload(String address) {
    final a = _amount.text.trim();
    if (!_request || a.isEmpty || double.tryParse(a) == null) return address;
    return 'janzeer:pay?to=$address&amount=$a';
  }

  @override
  Widget build(BuildContext context) {
    final w = Get.find<WalletController>();
    final address = w.address.value;
    final c = JzColors.of(context);
    final data = _payload(address);
    return Scaffold(
      appBar: AppBar(title: Text('receive_jnz'.tr)),
      body: SafeArea(
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.all(JzSpace.s4),
            children: [
              JzCard(
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: JzRadius.rMd),
                    child: QrImageView(data: data, size: 220, backgroundColor: Colors.white, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0E1424)), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0E1424))),
                  ),
                  gap16,
                  JzStatLabel('your_address'.tr),
                  gap8,
                  SelectableText(address, textAlign: TextAlign.center, style: TextStyle(fontFamily: kMono, fontSize: 13, color: c.text, height: 1.5)),
                  gap12,
                  JzPrimaryButton(
                    label: 'copy_address_btn'.tr,
                    icon: Icons.copy_rounded,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: address));
                      jzToast('copied'.tr);
                    },
                  ),
                ]),
              ),
              gap12,
              JzCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text('request_amount'.tr, style: Theme.of(context).textTheme.titleSmall)),
                    Switch(value: _request, onChanged: (v) => setState(() => _request = v)),
                  ]),
                  if (_request) ...[
                    gap8,
                    TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontFamily: kMono, fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(hintText: '0.00', suffixText: AppConfig.unit),
                      onChanged: (_) => setState(() {}),
                    ),
                    gap8,
                    Text(data, style: TextStyle(fontSize: 11.5, color: c.faint, fontFamily: kMono)),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
