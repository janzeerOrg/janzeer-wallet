import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_crop_page.dart';

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

  /// Decode a QR from a photo/screenshot (owner's request 2026-09-23: the camera is not the only way). Found at once →
  /// done. Not found → the crop step: the user frames the code and scans only that area.
  Future<void> _fromImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || _done) return;
    String? raw;
    try {
      raw = await _decodeFile(file.path);
    } catch (e) {
      Get.snackbar('', '$e', snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
      return;
    }
    if (raw == null) {
      final bytes = await file.readAsBytes();
      raw = await Get.to<String>(() => QrCropPage(image: bytes, decode: _decodeBytes));
      if (raw == null) return; // the user left the crop step
    }
    _done = true;
    Get.back<String>(result: raw);
  }

  Future<String?> _decodeFile(String path) async {
    final capture = await _controller.analyzeImage(path);
    final raw = capture?.barcodes.isNotEmpty == true ? capture!.barcodes.first.rawValue : null;
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// The cropped area goes through a temp file (the scanner reads files); removed right after.
  Future<String?> _decodeBytes(Uint8List bytes) async {
    final f = File('${Directory.systemTemp.path}/jz-qr-${DateTime.now().microsecondsSinceEpoch}.png');
    try {
      await f.writeAsBytes(bytes, flush: true);
      return await _decodeFile(f.path);
    } catch (_) {
      return null;
    } finally {
      if (await f.exists()) await f.delete();
    }
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
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // The camera failing must never be a dead end: show the reason and keep "from image" reachable.
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.no_photography_outlined, size: 40, color: Colors.white70),
                  const SizedBox(height: 12),
                  Text('${error.errorCode.name}${error.errorDetails?.message != null ? '\n${error.errorDetails!.message}' : ''}',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: _fromImage, icon: const Icon(Icons.photo_library_outlined, size: 18), label: Text('from_image'.tr)),
                ]),
              ),
            ),
          ),
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
