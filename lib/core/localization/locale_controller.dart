import 'dart:ui';

import 'package:get/get.dart';

import '../storage/secure_store.dart';

/// English/Arabic toggle, persisted. `Get.updateLocale` switches strings and flips RTL for Arabic.
class LocaleController extends GetxController {
  final RxString code = SecureStore.locale.obs;

  Locale get locale => Locale(code.value);

  bool get isArabic => code.value == 'ar';

  void setLocale(String c) {
    code.value = c;
    SecureStore.locale = c;
    Get.updateLocale(Locale(c));
  }

  void toggle() => setLocale(isArabic ? 'en' : 'ar');
}
