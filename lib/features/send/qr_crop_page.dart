import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/jz_tokens.dart';
import '../../core/ui/jz.dart';

/// Shown when no QR code was found in a picked image: the user frames the code with the square (drag the square or
/// its corners, pinch/drag the picture) and scans just that area. Stays open until a code is read or the user leaves,
/// so several tries are one tap each (owner's request 2026-09-24).
///
/// [decode] analyses the cropped bytes and returns the decoded text, or null when nothing was found.
class QrCropPage extends StatefulWidget {
  const QrCropPage({super.key, required this.image, required this.decode});
  final Uint8List image;
  final Future<String?> Function(Uint8List cropped) decode;

  @override
  State<QrCropPage> createState() => _QrCropPageState();
}

class _QrCropPageState extends State<QrCropPage> {
  final _crop = CropController();
  bool _busy = false;

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        final text = await widget.decode(croppedImage);
        if (!mounted) return;
        if (text != null && text.isNotEmpty) {
          Get.back<String>(result: text);
          return;
        }
        jzToast('no_qr_in_area'.tr, error: true);
      case CropFailure():
        jzToast('no_qr_in_area'.tr, error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text('select_qr_area'.tr, style: const TextStyle(color: Colors.white))),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text('select_qr_hint'.tr, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          ),
          Expanded(
            child: Crop(
              image: widget.image,
              controller: _crop,
              onCropped: _onCropped,
              aspectRatio: 1,
              interactive: true,
              baseColor: Colors.black,
              maskColor: Colors.black.withValues(alpha: 0.6),
              radius: 12,
              initialRectBuilder: InitialRectBuilder.withSizeAndRatio(size: 0.6, aspectRatio: 1),
              cornerDotBuilder: (size, edgeAlignment) => Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: JzPrimaryButton(
              label: 'scan_area'.tr,
              icon: Icons.qr_code_scanner_rounded,
              busy: _busy,
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _busy = true);
                      _crop.crop();
                    },
            ),
          ),
        ]),
      ),
    );
  }
}
