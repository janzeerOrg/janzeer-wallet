import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../storage/secure_store.dart';

/// One downloadable file of a release.
class UpdateFile {
  const UpdateFile({required this.name, required this.url, required this.sha256, required this.size});
  final String name;
  final String url;
  final String sha256;
  final int size;
}

/// The release manifest `latest.json` (written by the deployment kit next to the downloads; schema 1):
/// `{schema, version, build, released, notes:{en,ar}, files:{<platform>:{name,url,sha256,size}}}`.
///
/// Everything in it is checked before use: a manifest that is malformed, or that points anywhere but the project's
/// own download hosts, is treated as "no update" — the check must never be a way to send a user to a foreign file.
class UpdateInfo {
  const UpdateInfo({required this.version, required this.build, required this.notes, required this.files});
  final String version;
  final int build;
  final Map<String, String> notes;
  final Map<String, UpdateFile> files;

  static final _version = RegExp(r'^\d+(\.\d+){1,3}$');
  static final _sha = RegExp(r'^[0-9a-f]{64}$');

  /// Hosts a download may come from: the project's downloads host and the wallet's GitHub releases.
  static bool allowedUrl(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.scheme != 'https') return false;
    if (u.host == 'downloads.janzeer.org') return true;
    return u.host == 'github.com' && u.path.toLowerCase().startsWith('/janzeerorg/janzeer-wallet/releases/download/');
  }

  /// Returns null for anything that is not a well-formed schema-1 manifest.
  static UpdateInfo? tryParse(String body) {
    try {
      final j = jsonDecode(body);
      if (j is! Map || j['schema'] != 1) return null;
      final version = j['version'];
      if (version is! String || !_version.hasMatch(version)) return null;
      final files = <String, UpdateFile>{};
      final rawFiles = j['files'];
      if (rawFiles is Map) {
        rawFiles.forEach((k, v) {
          if (k is! String || v is! Map) return;
          final url = v['url'], sha = v['sha256'], name = v['name'], size = v['size'];
          if (url is String && sha is String && name is String && allowedUrl(url) && _sha.hasMatch(sha)) {
            files[k] = UpdateFile(name: name, url: url, sha256: sha, size: size is int ? size : 0);
          }
        });
      }
      final notes = <String, String>{};
      final rawNotes = j['notes'];
      if (rawNotes is Map) {
        rawNotes.forEach((k, v) {
          if (k is String && v is String) notes[k] = v.length > 2000 ? v.substring(0, 2000) : v;
        });
      }
      return UpdateInfo(version: version, build: j['build'] is int ? j['build'] as int : 0, notes: notes, files: files);
    } catch (_) {
      return null;
    }
  }

  String notesFor(String lang) => notes[lang] ?? notes['en'] ?? '';
}

/// `1.2.10` > `1.2.9`: numeric, part by part; a missing part counts as 0.
int compareVersions(String a, String b) {
  final x = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final y = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// The manifest key of the build this app is: `android`, `linux-x64`, `windows-x64`, `macos` ('' = no downloads).
String platformKey() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isLinux) return 'linux-x64';
  if (Platform.isWindows) return 'windows-x64';
  if (Platform.isMacOS) return 'macos';
  return '';
}

/// Looks for a newer wallet release: quietly once a day when the app opens, and on demand from Settings.
///
/// There is no push service behind this (a non-custodial wallet should not need one): the app reads one small public
/// file. An update is never installed by the app itself — it shows what is new and opens the download; on Android the
/// system installer then refuses any file that is not signed with the project's release key.
class UpdateController extends GetxController {
  /// A release newer than this build, or null.
  final available = Rxn<UpdateInfo>();
  final checking = false.obs;
  final _dismissed = SecureStore.dismissedUpdate.obs;

  static const _every = Duration(hours: 24);

  @override
  void onReady() {
    super.onReady();
    unawaited(check());
  }

  /// The banner on the home screen: an update exists and the user has not said "later" to this very version.
  bool get showBanner => available.value != null && _dismissed.value != available.value!.version;

  UpdateFile? get file => available.value?.files[platformKey()];

  /// `true` = a newer version exists, `false` = this is the latest, `null` = could not check (offline, bad answer).
  /// Unless [force], at most one network check per day.
  Future<bool?> check({bool force = false}) async {
    if (checking.value) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - SecureStore.lastUpdateCheck < _every.inMilliseconds) return available.value != null;
    checking.value = true;
    try {
      final info = await fetchManifest();
      if (info == null) return null;
      SecureStore.lastUpdateCheck = now;
      final newer = compareVersions(info.version, AppConfig.appVersion) > 0;
      available.value = newer ? info : null;
      return newer;
    } finally {
      checking.value = false;
    }
  }

  /// "Later": hide the banner for this version (Settings still offers it).
  void dismiss() {
    final v = available.value?.version;
    if (v == null) return;
    SecureStore.dismissedUpdate = v;
    _dismissed.value = v;
  }

  /// Open the download of this platform's file (the browser / the system handles it), else the wallet page.
  Future<void> openDownload() async {
    final url = file?.url ?? AppConfig.walletPageUrl;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// The first manifest URL that answers with a valid manifest. Overridable for tests.
  Future<UpdateInfo?> fetchManifest() async {
    for (final url in AppConfig.updateManifestUrls) {
      final info = await _get(url);
      if (info != null) return info;
    }
    return null;
  }

  Future<UpdateInfo?> _get(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final resp = await req.close().timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final bytes = <int>[];
      await for (final chunk in resp.timeout(const Duration(seconds: 10))) {
        bytes.addAll(chunk);
        if (bytes.length > 64 * 1024) return null; // a manifest is a few hundred bytes
      }
      return UpdateInfo.tryParse(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
