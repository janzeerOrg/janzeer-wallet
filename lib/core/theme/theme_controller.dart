import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../storage/secure_store.dart';
import 'theme_presets.dart';

/// Drives the active theme from observable preset + light/dark state. `GetMaterialApp` is wrapped in an `Obx`
/// (see main.dart) that reads [presetIndex] / [isDark] and rebuilds with explicit `theme`/`darkTheme`/`themeMode`,
/// so a change applies immediately. (Get.changeTheme alone did NOT work here: GetMaterialApp had no explicit
/// themeMode, defaulting to system, so on a dark device the untouched darkTheme slot was rendered.)
/// Persists the chosen preset + light/dark mode in [SecureStore].
class ThemeController extends GetxController {
  final RxInt presetIndex = SecureStore.themePreset.obs;
  final RxBool isDark = SecureStore.themeDark.obs;

  ThemePreset get preset => kThemePresets[presetIndex.value.clamp(0, kThemePresets.length - 1)];
  ThemeData get lightTheme => preset.theme(false);
  ThemeData get darkTheme => preset.theme(true);
  ThemeMode get mode => isDark.value ? ThemeMode.dark : ThemeMode.light;

  void setPreset(int i) {
    presetIndex.value = i;
    SecureStore.themePreset = i;
  }

  void setDark(bool v) {
    isDark.value = v;
    SecureStore.themeDark = v;
  }
}
