// Screenshot harness: renders every screen at phone size, EN/AR × dark/light, into test/goldens/*.png so the
// design can be reviewed without a device. Real fonts are loaded (Roboto from the Flutter SDK, DejaVu for Arabic
// and monospace), and the storage/network layers are faked.
//
//   flutter test --run-skipped --tags screenshots --update-goldens test/screenshots_test.dart   # (re)generate the PNGs
//
// Tagged `screenshots` and skipped by a plain `flutter test` — the PNGs are a review aid, not a regression gate.
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:wallet/core/config/app_config.dart';
import 'package:wallet/core/localization/locale_controller.dart';
import 'package:wallet/core/localization/translations.dart';
import 'package:wallet/core/lock/lock_controller.dart';
import 'package:wallet/core/storage/secure_store.dart';
import 'package:wallet/core/theme/jz_theme.dart';
import 'package:wallet/core/theme/theme_controller.dart';
import 'package:wallet/features/home/home_shell.dart';
import 'package:wallet/features/lock/lock_page.dart';
import 'package:wallet/features/onboarding/onboarding_page.dart';
import 'package:wallet/features/receive/receive_page.dart';
import 'package:wallet/features/send/send_page.dart';
import 'package:wallet/features/unlock/unlock_page.dart';
import 'package:wallet/features/wallet/wallet_controller.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

const _me = '0xd4337de2debd0ffef906ed5256c9b8ed28af26cb';
const _other = '0xed4ed582c025f6d4ce83f100cbf005fc2b5b7220';

/// The controller with the network removed: fixed balance, address and a few transfers.
class _FakeWallet extends WalletController {
  @override
  // ignore: must_call_super — the real onInit builds the API client and hits the network
  void onInit() {
    address.value = _me;
    balance.value = '9704.81';
    nonce.value = 42;
    hasVault.value = true;
    unlocked.value = true;
    networkId.value = 'janzeer';
    tokenBalances.assignAll([
      {'symbol': 'GOLD', 'name': 'Gold Token', 'tokenId': '0x9f1c2b3a4d5e6f708192a3b4c5d6e7f8091a2b3c', 'balance': '125000000000', 'decimals': 8},
      {'symbol': 'PONG', 'name': 'Pong Points', 'tokenId': '0x1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d', 'balance': '4200', 'decimals': 2},
    ]);
  }

  @override
  Future<void> reload() async {}

  @override
  void rebuildApi() {}

  @override
  Future<Map<String, dynamic>> myTransfers({int page = 0, int size = 10, bool unconfirmed = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (unconfirmed) {
      return {
        'list': [
          {'senderAddress': _me, 'recipientAddress': _other, 'amount': '4.85', 'fee': '0.01', 'nonce': 42, 'timestamp': now - 20000, 'hash': '8fceed56d01725c0170a1176d838918eb8bb2eaf13b60697057fd249ca110448'},
        ],
        'totalPages': 1,
      };
    }
    return {
      'list': [
        {'senderAddress': _other, 'recipientAddress': _me, 'amount': '300', 'fee': '0.01', 'timestamp': now - 3600000, 'blockHeight': 17020, 'hash': '1c86f1720403c7de5253d2cae88086803375653537afca35f7b51c32e183a1f6'},
        {'senderAddress': _me, 'recipientAddress': _other, 'amount': '0.26', 'fee': '0.01', 'data': 'coffee ☕', 'timestamp': now - 7200000, 'blockHeight': 16990, 'hash': '5a83347a846de66c2d4ba7094092b9397bfcc2cb1758e2c41f22e96ee1fb2c0b'},
        {'senderAddress': _other, 'recipientAddress': _me, 'amount': '2000', 'fee': '0.01', 'timestamp': now - 86400000 * 2, 'blockHeight': 12000, 'hash': 'b13ba1c7aa00000000000000000000000000000000000000000000000000cafe'},
      ],
      'totalPages': 2,
    };
  }
}

Future<void> _loadFonts() async {
  // Platform.resolvedExecutable is …/flutter/bin/cache/dart-sdk/bin/dart → cut at /bin/cache.
  final exe = Platform.resolvedExecutable;
  final root = exe.substring(0, exe.indexOf('/bin/cache'));
  final mf = Directory('$root/bin/cache/artifacts/material_fonts');
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File(f);
      if (!file.existsSync()) continue;
      loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    }
    await loader.load();
  }
  await load('Roboto', ['${mf.path}/Roboto-Regular.ttf', '${mf.path}/Roboto-Medium.ttf', '${mf.path}/Roboto-Bold.ttf']);
  await load('DejaVu', ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf']);
  await load('monospace', ['/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf']);
  await load('MaterialIcons', ['${mf.path}/MaterialIcons-Regular.otf']);
}

Widget _app(Widget home, {required bool dark, required String lang}) {
  return GetMaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildJzTheme(Brightness.light, fontFamilyFallback: const ['DejaVu']),
    darkTheme: buildJzTheme(Brightness.dark, fontFamilyFallback: const ['DejaVu']),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    translations: AppTranslations(),
    locale: Locale(lang),
    fallbackLocale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tmp = Directory.systemTemp.createTempSync('jz-shots');

  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    await SecureStore.init();
    SecureStore.address = _me;
    await _loadFonts();
  });

  Future<void> shoot(WidgetTester tester, String name, Widget page, {bool dark = true, String lang = 'en', Future<void> Function()? after}) async {
    Get.reset();
    Get.put<WalletController>(_FakeWallet(), permanent: true);
    Get.put(LockController(), permanent: true);
    Get.put(ThemeController(), permanent: true);
    Get.put(LocaleController(), permanent: true);
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(page, dark: dark, lang: lang));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    if (after != null) {
      await after();
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    }
    await expectLater(find.byType(GetMaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  for (final (suffix, dark, lang) in [('dark', true, 'en'), ('light', false, 'en'), ('ar', true, 'ar')]) {
    testWidgets('onboarding $suffix', (t) => shoot(t, 'onboarding_$suffix', const OnboardingPage(), dark: dark, lang: lang));
    testWidgets('unlock $suffix', (t) => shoot(t, 'unlock_$suffix', const UnlockPage(), dark: dark, lang: lang));
    testWidgets('lock $suffix', (t) async {
      SecureStore.lockMode = 'pin';
      await shoot(t, 'lock_$suffix', const LockPage(), dark: dark, lang: lang);
      SecureStore.lockMode = 'none';
    });
    testWidgets('home $suffix', (t) => shoot(t, 'home_$suffix', const HomeShell(), dark: dark, lang: lang));
    if (AppConfig.tokensEnabled) {
      testWidgets('home tokens $suffix', (t) => shoot(t, 'home_tokens_$suffix', const HomeShell(), dark: dark, lang: lang, after: () async {
            await t.tap(find.text(lang == 'ar' ? 'العملات' : 'Tokens').first);
          }));
    }
    testWidgets('home validator registered $suffix', (t) => shoot(t, 'home_validator_registered_$suffix', const HomeShell(), dark: dark, lang: lang, after: () async {
          Get.find<WalletController>().myValidators.value = [
            {'nodeKey': '03f7c8080674cb04944170b11730cca5371ebfc702592be9cc5d1ad78771b8c390', 'active': true},
            {'nodeKey': '0216a8c020eb121966258faeb0cdc06c45cad36451cd34c1f2e5b58c383be17fe7', 'active': false},
          ];
          await t.tap(find.text(lang == 'ar' ? 'المُصادِق' : 'Validator').first);
        }));
    testWidgets('home validator $suffix', (t) => shoot(t, 'home_validator_$suffix', const HomeShell(), dark: dark, lang: lang, after: () async {
          await t.tap(find.text(lang == 'ar' ? 'المُصادِق' : 'Validator').first);
        }));
    testWidgets('settings $suffix', (t) => shoot(t, 'settings_$suffix', const HomeShell(), dark: dark, lang: lang, after: () async {
          await t.tap(find.byIcon(Icons.settings_outlined));
        }));
    testWidgets('send $suffix', (t) => shoot(t, 'send_$suffix', const SendPage(initialRecipient: _other, initialAmount: '12.5'), dark: dark, lang: lang));
    testWidgets('receive $suffix', (t) => shoot(t, 'receive_$suffix', const ReceivePage(), dark: dark, lang: lang));
  }
}
