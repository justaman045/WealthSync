import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:money_control/Services/app_analytics.dart';
import 'package:money_control/Services/update_checker.dart';

/// The updater's failure modes, exercised end to end through a mocked release
/// and a real temp directory.
///
/// Context: builds up to 2.0.250 reported "Download failed. Please try again."
/// at 100 % on real phones, because the APK was read into memory (`readAsBytes`
/// on ~128 MB) and because every post-download failure shared one message. The
/// tests below pin the replacement contract: streamed hashing, truncation-only
/// size gating, distinct outcomes, and reuse of an already verified file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const version = '9.9.9';

  /// Just over [_minApkBytes] so it clears the "too small to be an APK" gate.
  final Uint8List apkBytes = () {
    final bytes = Uint8List(1024 * 1024 + 64);
    bytes.setRange(0, 4, const [0x50, 0x4b, 0x03, 0x04]); // "PK\x03\x04"
    for (var i = 4; i < bytes.length; i++) {
      bytes[i] = i % 251;
    }
    return bytes;
  }();

  String shaOf(List<int> bytes) => sha256.convert(bytes).toString();

  final checksumLine = '${shaOf(apkBytes)}  app-release.apk\n';

  late Directory tempDir;
  late List<Uri> requests;
  late List<String> installedPaths;

  /// Builds a client that serves a `SHA256SUMS` document and one APK body.
  http.Client releaseClient({
    int apkStatus = 200,
    int checksumStatus = 200,
    String? checksumText,
    String contentType = 'application/vnd.android.package-archive',
    List<int>? apkBody,
    int? announcedLength,
  }) {
    final body = apkBody ?? apkBytes;
    return MockClient.streaming((request, bodyStream) async {
      requests.add(request.url);
      if (request.url.path.endsWith('SHA256SUMS')) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(checksumText ?? checksumLine)),
          checksumStatus,
          headers: const {'content-type': 'text/plain'},
        );
      }
      return http.StreamedResponse(
        Stream.value(body),
        apkStatus,
        contentLength: announcedLength ?? body.length,
        headers: {'content-type': contentType},
      );
    });
  }

  File cachedApk() => File('${tempDir.path}/WealthSync-v$version.apk');

  void wire(http.Client client) {
    UpdateChecker.httpClientFactory = () => client;
    UpdateChecker.temporaryDirectoryOverride = () async => tempDir;
    UpdateChecker.installOverride = (path) async {
      installedPaths.add(path);
      return UpdateInstallResult.installed;
    };
    UpdateChecker.retryDelay = Duration.zero;
  }

  List<Uri> apkRequests() =>
      requests.where((u) => u.path.endsWith('app-release.apk')).toList();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ws_update_test_');
    requests = <Uri>[];
    installedPaths = <String>[];
  });

  tearDown(() async {
    UpdateChecker.httpClientFactory = null;
    UpdateChecker.temporaryDirectoryOverride = null;
    UpdateChecker.installOverride = null;
    UpdateChecker.retryDelay = const Duration(seconds: 2);
    AppAnalytics.debugLogHook = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('downloadAndInstallApk', () {
    test('installs a verified APK and reports progress to 1.0', () async {
      wire(releaseClient());

      final progress = <double>[];
      final result = await UpdateChecker.downloadAndInstallApk(
        version: version,
        onProgress: progress.add,
      );

      expect(result, UpdateInstallResult.installed);
      expect(installedPaths, hasLength(1));
      expect(installedPaths.single, cachedApk().path);
      expect(await cachedApk().exists(), isTrue);
      expect(await File('${cachedApk().path}.part').exists(), isFalse);
      expect(progress, isNotEmpty);
      expect(progress.last, 1.0);
      expect(progress.every((p) => p >= 0.0 && p <= 1.0), isTrue);
    });

    test('reuses an already verified APK instead of re-downloading', () async {
      wire(releaseClient());
      await cachedApk().writeAsBytes(apkBytes);

      final result = await UpdateChecker.downloadAndInstallApk(version: version);

      expect(result, UpdateInstallResult.installed);
      expect(installedPaths, hasLength(1));
      // Only the checksum document was fetched; the 128 MB asset was not.
      expect(apkRequests(), isEmpty);
    });

    test('re-downloads when the cached file does not match the hash', () async {
      wire(releaseClient());
      final stale = Uint8List.fromList(apkBytes)..[100] = 0xFF;
      await cachedApk().writeAsBytes(stale);

      final result = await UpdateChecker.downloadAndInstallApk(version: version);

      expect(result, UpdateInstallResult.installed);
      expect(apkRequests(), hasLength(1));
      expect(shaOf(await cachedApk().readAsBytes()), shaOf(apkBytes));
    });

    test('fails a truncated transfer, retries once, and keeps no file',
        () async {
      wire(
        releaseClient(
          apkBody: Uint8List.sublistView(apkBytes, 0, apkBytes.length - 512),
          announcedLength: apkBytes.length,
        ),
      );

      final result = await UpdateChecker.downloadAndInstallApk(version: version);

      expect(result, UpdateInstallResult.downloadFailed);
      expect(installedPaths, isEmpty);
      // One silent retry, then give up.
      expect(apkRequests(), hasLength(2));
      expect(await cachedApk().exists(), isFalse);
      expect(await File('${cachedApk().path}.part').exists(), isFalse);
    });

    test('rejects an HTML error page', () async {
      wire(
        releaseClient(
          apkBody: Uint8List.fromList(
            utf8.encode('<html><body>404</body></html>'.padRight(4096, ' ')),
          ),
          contentType: 'text/html; charset=utf-8',
        ),
      );

      final result = await UpdateChecker.downloadAndInstallApk(version: version);

      expect(result, UpdateInstallResult.downloadFailed);
      expect(installedPaths, isEmpty);
    });

    test('rejects a non-200 APK response', () async {
      wire(releaseClient(apkStatus: 503));

      final result = await UpdateChecker.downloadAndInstallApk(version: version);

      expect(result, UpdateInstallResult.downloadFailed);
      expect(installedPaths, isEmpty);
    });

    test('rejects bytes that are not a ZIP archive', () async {
      final notAnApk = Uint8List(1024 * 1024 + 64);
      wire(
        releaseClient(
          apkBody: notAnApk,
          // Hash matches, so only the magic-byte gate can reject this.
          checksumText: '${shaOf(notAnApk)}  app-release.apk\n',
        ),
      );

      final result = await UpdateChecker.downloadAndInstallApk(version: version);

      expect(result, UpdateInstallResult.downloadFailed);
      expect(installedPaths, isEmpty);
      expect(await cachedApk().exists(), isFalse);
    });

    test('fails closed when the release publishes no checksum', () async {
      wire(releaseClient(checksumStatus: 404));
      final events = <Map<String, Object>?>[];
      AppAnalytics.debugLogHook = (name, params) {
        if (name == AnalyticsEvent.updateDownloadFailed) events.add(params);
      };

      final result = await UpdateChecker.downloadAndInstallApk(version: version);

      expect(result, UpdateInstallResult.checksumUnavailable);
      // No unverifiable 128 MB download was attempted.
      expect(apkRequests(), isEmpty);
      expect(installedPaths, isEmpty);
      expect(events.single?['reason'], 'checksum_unavailable');
    });

    test('does not install a file whose hash differs from the release', () async {
      wire(releaseClient(checksumText: '${'a' * 64}  app-release.apk\n'));
      final events = <Map<String, Object>?>[];
      AppAnalytics.debugLogHook = (name, params) {
        if (name == AnalyticsEvent.updateDownloadFailed) events.add(params);
      };

      final result = await UpdateChecker.downloadAndInstallApk(version: version);

      expect(result, UpdateInstallResult.checksumMismatch);
      expect(installedPaths, isEmpty);
      expect(await cachedApk().exists(), isFalse);
      expect(events.single?['reason'], 'checksum_mismatch');
    });

    test('reports installer refusal as installFailed', () async {
      wire(releaseClient());
      UpdateChecker.installOverride =
          (_) async => UpdateInstallResult.permissionDenied;
      final events = <Map<String, Object>?>[];
      AppAnalytics.debugLogHook = (name, params) {
        if (name == AnalyticsEvent.updateInstallFailed) events.add(params);
      };

      final result = await UpdateChecker.downloadAndInstallApk(version: version);

      expect(result, UpdateInstallResult.permissionDenied);
      expect(events.single?['reason'], 'permissionDenied');
      // A verified APK stays cached so a retry after granting permission is
      // instant instead of another 128 MB download.
      expect(await cachedApk().exists(), isTrue);
    });

    test('tolerates an under-reported content-length and clamps progress',
        () async {
      // Proxies under-report the body; the SHA-256 is the real gate, so this
      // must install rather than look like a 100 %-then-fail transfer.
      wire(releaseClient(announcedLength: 1024));
      final progress = <double>[];

      final result = await UpdateChecker.downloadAndInstallApk(
        version: version,
        onProgress: progress.add,
      );

      expect(result, UpdateInstallResult.installed);
      expect(progress.every((p) => p >= 0.0 && p <= 1.0), isTrue);
    });

    test('deletes the APKs of superseded versions', () async {
      final old = File('${tempDir.path}/WealthSync-v1.0.0.apk');
      await old.writeAsBytes(apkBytes);
      wire(releaseClient());

      final result = await UpdateChecker.downloadAndInstallApk(version: version);

      expect(result, UpdateInstallResult.installed);
      expect(await old.exists(), isFalse);
    });
  });

  group('regression guards', () {
    test('the APK is never read into memory', () {
      // `readAsBytes()` on a 128 MB APK is the OOM that made the download
      // "reach 100 %" and then fail on real phones. Any future hashing change
      // must keep streaming through `openRead()`.
      final source =
          File('lib/Services/update_checker.dart').readAsStringSync();
      // Doc comments legitimately mention the old call, so scan code only.
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('readAsBytes'), isFalse);
      expect(code.contains('openRead()'), isTrue);
    });
  });
}
