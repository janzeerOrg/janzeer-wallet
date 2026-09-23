import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../storage/secure_store.dart';
import 'jz_theme.dart';

/// One brand theme (the explorer's tokens), dark or light. `GetMaterialApp` is wrapped in an `Obx` (see main.dart)
/// that reads [isDark] and rebuilds with explicit `theme`/`darkTheme`/`themeMode`, so a change applies immediately.
/// (The seed-colour presets of the first version are gone — owner, 2026-09-23: same look as web/Telegram.)
class ThemeController extends GetxController {
  final RxBool isDark = SecureStore.themeDark.obs;

  ThemeData get lightTheme => buildJzTheme(Brightness.light);
  ThemeData get darkTheme => buildJzTheme(Brightness.dark);
  ThemeMode get mode => isDark.value ? ThemeMode.dark : ThemeMode.light;

  void setDark(bool v) {
    isDark.value = v;
    SecureStore.themeDark = v;
  }
}
