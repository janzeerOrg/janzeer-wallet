import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/core/config/app_config.dart';

/// The version the app shows (About, update check, release manifest) must be the version it is built as.
/// 1.2.5 shipped with the constant still at 1.2.4 and told its own users that 1.2.5 was available (2026-10-23).
void main() {
  test('AppConfig.appVersion equals the pubspec version', () {
    final spec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true).firstMatch(spec);
    expect(m, isNotNull, reason: 'pubspec.yaml has no version line');
    expect(AppConfig.appVersion, m!.group(1), reason: 'bump lib/core/config/app_config.dart together with pubspec.yaml');
  });
}
