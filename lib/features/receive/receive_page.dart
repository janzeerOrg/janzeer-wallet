import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../wallet/wallet_controller.dart';

class ReceivePage extends StatelessWidget {
  const ReceivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final w = Get.find<WalletController>();
    final address = w.address.value;
    return Scaffold(
      appBar: AppBar(title: Text('receive'.tr)),
      body: SafeArea(
        child: ContentColumn(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('your_address'.tr, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: QrImageView(data: address, size: 220, backgroundColor: Colors.white),
                ),
                const SizedBox(height: 20),
                SelectableText(address, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: address));
                    Get.snackbar('', 'copy_address'.tr, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
                  },
                  icon: const Icon(Icons.copy),
                  label: Text('copy_address'.tr),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
