import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../config/app_config.dart';
import '../theme/jz_tokens.dart';
import '../ui/jz.dart';
import 'update_controller.dart';

/// Home-screen banner: shown while a newer release exists and has not been postponed.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final u = Get.find<UpdateController>();
    final c = JzColors.of(context);
    return Obx(() {
      if (!u.showBanner) return const SizedBox.shrink();
      final info = u.available.value!;
      return Padding(
        padding: const EdgeInsets.only(bottom: JzSpace.s3),
        child: Material(
          color: c.accentWeak,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => showUpdateDialog(context),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
              child: Row(children: [
                Icon(Icons.system_update_alt_rounded, color: c.accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('update_available'.trParams({'v': info.version}), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                    Text('update_tap'.tr, style: TextStyle(fontSize: 12.5, color: c.muted)),
                  ]),
                ),
                IconButton(tooltip: 'later'.tr, icon: Icon(Icons.close, size: 18, color: c.muted), onPressed: u.dismiss),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

/// What is new, which file, its SHA-256, and the two choices: download or later.
Future<void> showUpdateDialog(BuildContext context) {
  final u = Get.find<UpdateController>();
  final info = u.available.value;
  if (info == null) return Future.value();
  final c = JzColors.of(context);
  final file = u.file;
  final notes = info.notesFor(Get.locale?.languageCode ?? 'en');
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('update_available'.trParams({'v': info.version})),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('update_current'.trParams({'v': AppConfig.appVersion}), style: TextStyle(fontSize: 12.5, color: c.muted)),
          if (notes.isNotEmpty) ...[gap12, Text(notes, style: TextStyle(fontSize: 14, height: 1.45, color: c.text))],
          gap12,
          Text('update_how'.tr, style: TextStyle(fontSize: 12.5, height: 1.45, color: c.muted)),
          if (file != null) ...[
            gap12,
            Text('SHA-256 · ${file.name}', style: TextStyle(fontSize: 11.5, color: c.faint)),
            gap4,
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: file.sha256));
                jzToast('copied'.tr);
              },
              child: Text(file.sha256, style: TextStyle(fontFamily: kMono, fontSize: 11.5, height: 1.4, color: c.muted)),
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () {
              u.dismiss();
              Navigator.of(ctx).pop();
            },
            child: Text('later'.tr)),
        FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              u.openDownload();
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text('download_update'.tr)),
      ],
    ),
  );
}
