import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'core/localization/locale_controller.dart';
import 'core/localization/translations.dart';
import 'core/storage/secure_store.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SecureStore.init();
  runApp(const JanzeerWalletApp());
}

class JanzeerWalletApp extends StatelessWidget {
  const JanzeerWalletApp({super.key});

  /// First screen: no wallet → onboarding; wallet + app-lock → lock; wallet only → password unlock.
  String get _initialRoute {
    if (SecureStore.vault == null) return Routes.onboarding;
    return SecureStore.lockMode != 'none' ? Routes.lock : Routes.unlock;
  }

  @override
  Widget build(BuildContext context) {
    // Controllers must exist before we read theme/locale for the app config.
    InitialBinding().dependencies();
    final theme = Get.find<ThemeController>();
    final locale = Get.find<LocaleController>();

    // Obx rebuilds the app when the preset or light/dark mode changes, so theme switches apply immediately
    // (explicit theme/darkTheme/themeMode — not the system default that made Get.changeTheme ineffective).
    return Obx(() => GetMaterialApp(
          title: 'Janzeer Wallet',
          debugShowCheckedModeBanner: false,
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.mode,
          translations: AppTranslations(),
          locale: locale.locale,
          fallbackLocale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: _initialRoute,
          getPages: AppPages.routes,
        ));
  }
}
