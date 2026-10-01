import 'package:get/get.dart';

import '../../core/localization/locale_controller.dart';
import '../../core/lock/lock_controller.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/update/update_controller.dart';
import '../../features/wallet/wallet_controller.dart';

/// Long-lived singletons available app-wide.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ThemeController(), permanent: true);
    Get.put(LocaleController(), permanent: true);
    Get.put(WalletController(), permanent: true);
    Get.put(LockController(), permanent: true);
    Get.put(UpdateController(), permanent: true);
  }
}
