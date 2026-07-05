import 'package:get/get.dart';

import '../../features/home/home_shell.dart';
import '../../features/lock/lock_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/receive/receive_page.dart';
import '../../features/send/send_page.dart';
import '../../features/tokens/tokens_page.dart';
import '../../features/validator/validator_page.dart';
import '../../features/unlock/unlock_page.dart';
import 'app_routes.dart';

class AppPages {
  static final routes = <GetPage>[
    GetPage(name: Routes.onboarding, page: () => const OnboardingPage()),
    GetPage(name: Routes.unlock, page: () => const UnlockPage()),
    GetPage(name: Routes.lock, page: () => const LockPage()),
    GetPage(name: Routes.home, page: () => const HomeShell()),
    GetPage(name: Routes.send, page: () => const SendPage()),
    GetPage(name: Routes.receive, page: () => const ReceivePage()),
    GetPage(name: Routes.validator, page: () => const ValidatorPage()),
    GetPage(name: Routes.tokens, page: () => const TokensPage()),
  ];
}
