import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/core/update/update_controller.dart';

/// The update check trusts NOTHING in the manifest it downloads: these cases pin what is accepted.
void main() {
  test('versions compare numerically, part by part', () {
    expect(compareVersions('1.2.10', '1.2.9'), 1);
    expect(compareVersions('1.2.3', '1.2.3'), 0);
    expect(compareVersions('1.2', '1.2.0'), 0);
    expect(compareVersions('1.3', '1.2.9'), 1);
    expect(compareVersions('1.2.2', '1.2.3'), -1);
    expect(compareVersions('2.0.0', '1.99.99'), 1);
  });

  const sha = 'a3f1c0de00000000000000000000000000000000000000000000000000000001';

  test('a well-formed manifest is read', () {
    final m = UpdateInfo.tryParse('{"schema":1,"version":"1.2.4","build":9,"notes":{"en":"New.","ar":"جديد."},'
        '"files":{"android":{"name":"janzeer-wallet-1.2.4-android.apk","url":"https://downloads.janzeer.org/wallet/1.2.4/janzeer-wallet-1.2.4-android.apk","sha256":"$sha","size":82000000},'
        '"linux-x64":{"name":"x.tar.gz","url":"https://github.com/janzeerOrg/janzeer-wallet/releases/download/v1.2.4/x.tar.gz","sha256":"$sha","size":1}}}')!;
    expect(m.version, '1.2.4');
    expect(m.build, 9);
    expect(m.files.keys, containsAll(['android', 'linux-x64']));
    expect(m.files['android']!.size, 82000000);
    expect(m.notesFor('ar'), 'جديد.');
    expect(m.notesFor('fr'), 'New.');
  });

  test('a download outside the project hosts is dropped', () {
    for (final url in [
      'https://evil.example/janzeer-wallet.apk',
      'http://downloads.janzeer.org/wallet/x.apk', // not https
      'https://downloads.janzeer.org.evil.example/x.apk',
      'https://github.com/someone-else/janzeer-wallet/releases/download/v9/x.apk',
      'https://github.com/janzeerOrg/other-repo/releases/download/v9/x.apk',
    ]) {
      final m = UpdateInfo.tryParse('{"schema":1,"version":"9.0.0","files":{"android":{"name":"x.apk","url":"$url","sha256":"$sha","size":1}}}')!;
      expect(m.files, isEmpty, reason: url);
    }
    expect(UpdateInfo.allowedUrl('https://downloads.janzeer.org/wallet/1.2.4/a.apk'), isTrue);
  });

  test('a file without a valid SHA-256 is dropped', () {
    final m = UpdateInfo.tryParse('{"schema":1,"version":"9.0.0","files":{"android":{"name":"x.apk","url":"https://downloads.janzeer.org/x.apk","sha256":"abc","size":1}}}')!;
    expect(m.files, isEmpty);
  });

  test('anything that is not a schema-1 manifest is no update', () {
    for (final body in ['', 'not json', '[]', '{"schema":2,"version":"9.0.0"}', '{"schema":1}', '{"schema":1,"version":"9.0.0-beta"}', '{"schema":1,"version":"<script>"}', '<html>404</html>']) {
      expect(UpdateInfo.tryParse(body), isNull, reason: body);
    }
  });
}
