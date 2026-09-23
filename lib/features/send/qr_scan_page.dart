import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen QR scanner. Pops with the first decoded string via `Get.back(result:)`, or null if cancelled.
/// The caller extracts/validates the address (see SendPage._scan).
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});
  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Decode a QR from a photo/screenshot (owner's request 2026-09-23: the camera is not the only way).
  Future<void> _fromImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || _done) return;
    final capture = await _controller.analyzeImage(file.path);
    final raw = capture?.barcodes.isNotEmpty == true ? capture!.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) {
      Get.snackbar('', 'no_qr_found'.tr, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      return;
    }
    _done = true;
    Get.back<String>(result: raw);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _done = true;
    Get.back<String>(result: raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('scan_qr'.tr),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _controller.toggleTorch()),
          IconButton(icon: const Icon(Icons.photo_library_outlined), tooltip: 'from_image'.tr, onPressed: _fromImage),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
