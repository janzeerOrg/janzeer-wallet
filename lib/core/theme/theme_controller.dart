import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../storage/secure_store.dart';
import 'theme_presets.dart';

/// Drives the active theme via [Get.changeTheme] (preserves navigation, unlike rebuilding the app).
/// Persists the chosen preset + light/dark mode in [SecureStore].
class ThemeController extends GetxController {
  final RxInt presetIndex = SecureStore.themePreset.obs;
  final RxBool isDark = SecureStore.themeDark.obs;

  ThemePreset get preset => kThemePresets[presetIndex.value.clamp(0, kThemePresets.length - 1)];
  ThemeData get theme => preset.theme(isDark.value);

  void setPreset(int i) {
    presetIndex.value = i;
    SecureStore.themePreset = i;
    Get.changeTheme(theme);
  }

  void setDark(bool v) {
    isDark.value = v;
    SecureStore.themeDark = v;
    Get.changeTheme(theme);
  }
}
