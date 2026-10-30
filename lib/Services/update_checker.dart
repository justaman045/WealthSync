import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/app_analytics.dart';
import 'package:money_control/Utils/version_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Outcome of an in-app update attempt, so the UI can explain *why* it failed
/// instead of a single generic message.
///
/// Every value is user-visible: a phone has no logcat, so the distinction
/// between "the transfer broke" ([downloadFailed]), "there was no space for
/// it" ([storageFull]) and "the file did not match its published hash"
/// ([checksumMismatch]) is the whole diagnostic story.
enum UpdateInstallResult {
  installed,
  cancelled,
  permissionDenied,
  downloadFailed,

  /// The release published no usable `SHA256SUMS`. Fail closed — an
  /// unverifiable 128 MB binary is not something to hand to the installer.
  checksumUnavailable,

  /// The bytes do not hash to the published value. Treated as a hard failure
  /// (never retried blindly, never installed).
  checksumMismatch,

  /// The cache write ran out of space, so no complete file exists.
  storageFull,
  installFailed,
  unsupported,
}

class UpdateChecker {
  static const lastDialogKey = 'last_update_dialog_shown';
  static const _installChannel = MethodChannel('money_control/install');

  /// Test seams. Production always uses the real client/directory/installer.
  @visibleForTesting
  static http.Client Function()? httpClientFactory;

  @visibleForTesting
  static Future<Directory> Function()? temporaryDirectoryOverride;

  /// Lets a test observe the verified file without launching an Android
  /// installer (which no host-side test can do).
  @visibleForTesting
  static Future<UpdateInstallResult> Function(String filePath)? installOverride;

  /// Shortened to zero in tests so retries do not sleep.
  @visibleForTesting
  static Duration retryDelay = const Duration(seconds: 2);

  static http.Client _newClient() => httpClientFactory?.call() ?? http.Client();

  static Future<Directory> _temporaryDirectory() async =>
      await (temporaryDirectoryOverride?.call() ?? getTemporaryDirectory());

  static const _releasesLatestUrl =
      'https://github.com/justaman045/WealthSync/releases/latest';
  static const _versionJsonUrl =
      'https://raw.githubusercontent.com/justaman045/WealthSync/master/app_version.json';

  static String _apkUrl(String version) =>
      'https://github.com/justaman045/WealthSync/releases/download/v$version/app-release.apk';

  static Future<void> checkForUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (prefs.getString(lastDialogKey) == todayStr) return;

      final info = await _fetchRemoteInfo();
      final latestVersion = info.version;
      if (latestVersion == null || latestVersion.isEmpty) return;

      final package = await PackageInfo.fromPlatform();
      final currentVersion = package.version;

      // Only throttle once we actually have a version to compare against, so a
      // transient network failure doesn't suppress the check for the whole day.
      await prefs.setString(lastDialogKey, todayStr);

      if (isNewerVersion(latestVersion, currentVersion)) {
        _maybeShowUpdateDialog(latestVersion, info.message, info.force);
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  /// Manual check triggered by the user — bypasses the daily throttle.
  ///
  /// Returns `true` when a newer version was found, `false` when the app is up
  /// to date, and `null` when the check could not be completed (offline, bad
  /// response, …). The `null` case lets the caller say "couldn't check"
  /// instead of falsely claiming the app is up to date.
  static Future<bool?> checkForUpdateManual() async {
    try {
      final info = await _fetchRemoteInfo();
      final latestVersion = info.version;
      if (latestVersion == null || latestVersion.isEmpty) return null;

      final package = await PackageInfo.fromPlatform();
      final currentVersion = package.version;

      if (isNewerVersion(latestVersion, currentVersion)) {
        _maybeShowUpdateDialog(latestVersion, info.message, info.force);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Manual update check failed: $e");
      return null;
    }
  }

  /// Resolves the newest release version plus its advisory copy.
  ///
  /// The authoritative version comes from the GitHub `releases/latest`
  /// redirect (immune to an orphaned `app_version.json` commit from a
  /// force-push); `app_version.json` is only a fallback and supplies the
  /// human-readable message/force flag.
  static Future<({String? version, String message, bool force})>
      _fetchRemoteInfo() async {
    var message = '';
    var force = false;
    String? jsonVersion;

    try {
      final response = await http
          .get(Uri.parse(_versionJsonUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          jsonVersion = (data["latest_version"] as String?)?.trim();
          message = data["update_message"] as String? ?? '';
          force = data["force"] as bool? ?? false;
        }
      }
    } catch (e) {
      debugPrint("app_version.json fetch failed: $e");
    }

    String? tagVersion;
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(_releasesLatestUrl))
        ..followRedirects = false;
      final response =
          await client.send(request).timeout(const Duration(seconds: 10));
      await response.stream.drain<void>();
      final location =
          response.headers['location'] ?? response.headers['Location'];
      final match = location == null
          ? null
          : RegExp(r'/tag/v?([0-9]+\.[0-9]+\.[0-9]+)').firstMatch(location);
      tagVersion = match?.group(1);
    } catch (e) {
      debugPrint("release tag fetch failed: $e");
    } finally {
      client.close();
    }

    return (
      version: tagVersion ?? jsonVersion,
      message: message,
      force: force,
    );
  }

  static void _maybeShowUpdateDialog(
    String version,
    String message,
    bool force,
  ) {
    final overlayCtx = Get.overlayContext;
    if (overlayCtx != null) {
      _showUpdateDialog(overlayCtx, version, message, force);
    }
  }

  /// Anything smaller than this cannot be a real APK, so a 200 response
  /// carrying a login page or an error document is rejected before we spend
  /// time hashing it.
  static const int _minApkBytes = 1024 * 1024;

  /// One silent retry for a truncated transfer: mobile radios drop long
  /// connections, and re-downloading is cheaper than making the user tap again.
  static const int _downloadAttempts = 2;

  /// Downloads an APK from the GitHub release, verifies it against the
  /// published `SHA256SUMS`, and triggers the Android installer.
  /// [onProgress] is called with a value between 0.0 and 1.0 during download.
  ///
  /// Ordering matters:
  ///
  /// 1. The checksum is fetched **first**. It is 64 bytes against 128 MB, and
  ///    without it the download cannot be trusted — a missing checksum fails
  ///    closed ([UpdateInstallResult.checksumUnavailable]).
  /// 2. A previously verified APK for the same version is reused, so cancelling
  ///    the installer or retrying does not re-download the whole file.
  /// 3. Bytes stream to `<name>.part` and are hashed as a stream, never loaded
  ///    into memory: `readAsBytes()` on a 128 MB APK is an OOM on a real phone,
  ///    which is exactly how "download reaches 100 % then fails" happened.
  ///
  /// Any partial or unverifiable file is deleted rather than handed to the
  /// installer — Android reports "There was a problem parsing the package".
  static Future<UpdateInstallResult> downloadAndInstallApk({
    required String version,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      try {
        await launchUrl(
          Uri.parse(_apkUrl(version)),
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint("APK URL launch failed: $e");
      }
      return UpdateInstallResult.unsupported;
    }

    File? file;
    try {
      final dir = await _temporaryDirectory();
      file = File("${dir.path}/WealthSync-v$version.apk");

      final expectedSha = await _fetchSha256WithRetry(version);
      if (expectedSha == null) {
        debugPrint('APK SHA256 unavailable for v$version, failing closed');
        _reportDownloadFailure('checksum_unavailable', version);
        return UpdateInstallResult.checksumUnavailable;
      }

      if (await _isUsableApk(file, expectedSha)) {
        debugPrint('Reusing verified APK for v$version');
        onProgress?.call(1.0);
        return await _installVerifiedApk(file, version);
      }

      await _cleanupStaleApks(dir, keep: file);
      await _safeDelete(file);

      UpdateInstallResult? failure;
      for (var attempt = 1; attempt <= _downloadAttempts; attempt++) {
        failure = await _downloadApk(
          url: Uri.parse(_apkUrl(version)),
          target: file,
          onProgress: onProgress,
        );
        if (failure == null) break;
        // Retrying against a full disk just burns time.
        if (failure == UpdateInstallResult.storageFull) break;
        if (attempt < _downloadAttempts) {
          debugPrint('APK download attempt $attempt failed, retrying');
          await Future<void>.delayed(retryDelay);
        }
      }

      if (failure != null) {
        _reportDownloadFailure(
          failure == UpdateInstallResult.storageFull
              ? 'storage_full'
              : 'download_failed',
          version,
        );
        return failure;
      }

      if (!await _looksLikeApk(file)) {
        debugPrint("Downloaded file is not a valid APK (bad magic bytes)");
        await _safeDelete(file);
        _reportDownloadFailure('invalid_apk', version);
        return UpdateInstallResult.downloadFailed;
      }

      final actualSha = await _sha256OfFile(file);
      if (actualSha != expectedSha) {
        debugPrint('APK SHA256 mismatch');
        await _safeDelete(file);
        _reportDownloadFailure('checksum_mismatch', version);
        return UpdateInstallResult.checksumMismatch;
      }

      return await _installVerifiedApk(file, version);
    } catch (e, st) {
      debugPrint("APK download failed: $e");
      if (file != null) await _safeDelete(file);
      AppAnalytics.recordError(e, st, reason: 'update_download_apk');
      final result = _resultForFileSystemError(e);
      _reportDownloadFailure(
        result == UpdateInstallResult.storageFull
            ? 'storage_full'
            : 'download_failed',
        version,
      );
      return result;
    }
  }

  static Future<UpdateInstallResult?> _downloadApk({
    required Uri url,
    required File target,
    void Function(double progress)? onProgress,
  }) async {
    // The `.part` file keeps an interrupted transfer out of the path that
    // [_isUsableApk] treats as already verified.
    final part = File('${target.path}.part');
    await _safeDelete(part);

    final client = _newClient();
    IOSink? sink;
    try {
      final request = http.Request('GET', url)
        ..headers['User-Agent'] = 'WealthSync-Updater';
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('APK download failed: HTTP ${response.statusCode}');
        await response.stream.drain<void>();
        return UpdateInstallResult.downloadFailed;
      }

      final contentType =
          (response.headers['content-type'] ?? '').toLowerCase();
      if (contentType.contains('text/html')) {
        debugPrint('APK download failed: received HTML response');
        await response.stream.drain<void>();
        return UpdateInstallResult.downloadFailed;
      }

      final totalBytes = response.contentLength ?? 0;
      var received = 0;
      sink = part.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          // A lying content-length must not push the bar past 100 %.
          onProgress?.call(
            (received / totalBytes).clamp(0.0, 1.0).toDouble(),
          );
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (received == 0) {
        debugPrint('APK download incomplete: no bytes received');
        await _safeDelete(part);
        return UpdateInstallResult.downloadFailed;
      }
      // Only truncation is fatal. A content-length that under-reports the body
      // is tolerated — the SHA-256 check below is the real gate.
      if (totalBytes > 0 && received < totalBytes) {
        debugPrint('APK download incomplete: $received/$totalBytes bytes');
        await _safeDelete(part);
        return UpdateInstallResult.downloadFailed;
      }
      if (received < _minApkBytes) {
        debugPrint('APK download too small: $received bytes');
        await _safeDelete(part);
        return UpdateInstallResult.downloadFailed;
      }

      await _safeDelete(target);
      await part.rename(target.path);
      return null;
    } catch (e, st) {
      debugPrint("APK download failed: $e");
      await _safeDelete(part);
      AppAnalytics.recordError(e, st, reason: 'update_download_stream');
      return _resultForFileSystemError(e);
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {
          // Best effort: the caller already classified the failure.
        }
      }
      client.close();
    }
  }

  /// `readAsBytes()` on a 128 MB APK is an OOM on a phone; hashing the file
  /// stream keeps peak memory at one chunk.
  static Future<String> _sha256OfFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static Future<bool> _isUsableApk(File file, String expectedSha) async {
    try {
      if (!await file.exists()) return false;
      if (await file.length() < _minApkBytes) return false;
      if (!await _looksLikeApk(file)) return false;
      return await _sha256OfFile(file) == expectedSha;
    } catch (e) {
      debugPrint('APK cache check failed: $e');
      return false;
    }
  }

  /// Keeps the cache to one APK. Verified downloads are deliberately retained
  /// for retries, so the previous version's file must not linger at 128 MB.
  static Future<void> _cleanupStaleApks(
    Directory dir, {
    required File keep,
  }) async {
    final separator = Platform.pathSeparator;
    final keepName = keep.path.split(separator).last;
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.path.split(separator).last;
        if (name == keepName) continue;
        if (!name.startsWith('WealthSync-v')) continue;
        if (!name.endsWith('.apk') && !name.endsWith('.apk.part')) continue;
        await _safeDelete(entity);
      }
    } catch (e) {
      debugPrint('APK cache cleanup failed: $e');
    }
  }

  static Future<String?> _fetchSha256WithRetry(String version) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      final sha = await _fetchSha256(version);
      if (sha != null) return sha;
      if (attempt < 2) await Future<void>.delayed(retryDelay);
    }
    return null;
  }

  static Future<String?> _fetchSha256(String version) async {
    final client = _newClient();
    try {
      final uri = Uri.parse(
          'https://github.com/justaman045/WealthSync/releases/download/v$version/SHA256SUMS');
      final resp = await client
          .get(uri, headers: {'User-Agent': 'WealthSync-Updater'})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final body = resp.body;
      if (body.trim().startsWith('<')) return null;
      final lines = body.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
      for (final line in lines) {
        if (line.contains('app-release.apk')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.isNotEmpty && parts[0].length == 64) {
            return parts[0].toLowerCase();
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Failed to fetch SHA256SUMS: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// ENOSPC (`errno 28`) is the one filesystem failure worth naming separately:
  /// "free up space" is actionable, "download failed" is not.
  static UpdateInstallResult _resultForFileSystemError(Object error) {
    if (error is FileSystemException && error.osError?.errorCode == 28) {
      return UpdateInstallResult.storageFull;
    }
    final message = error.toString().toLowerCase();
    if (message.contains('no space left') ||
        message.contains('enospc') ||
        message.contains('disk full')) {
      return UpdateInstallResult.storageFull;
    }
    return UpdateInstallResult.downloadFailed;
  }

  static Future<UpdateInstallResult> _installVerifiedApk(
    File file,
    String version,
  ) async {
    final result = await _installApk(file.path);
    if (result != UpdateInstallResult.installed) {
      debugPrint('APK install did not complete: ${result.name}');
      AppAnalytics.log(AnalyticsEvent.updateInstallFailed, {
        'reason': result.name,
        'version': version,
      });
    }
    return result;
  }

  /// Analytics is the only channel for update failures on a real phone.
  static void _reportDownloadFailure(String reason, String version) {
    AppAnalytics.log(AnalyticsEvent.updateDownloadFailed, {
      'reason': reason,
      'version': version,
    });
  }

  static const _apkMagic = [0x50, 0x4b, 0x03, 0x04]; // "PK\x03\x04"

  /// A real APK is a ZIP archive, so it must start with the ZIP local-file
  /// header. Guards against an HTML error page or other non-APK payload.
  static Future<bool> _looksLikeApk(File file) async {
    try {
      final raf = await file.open();
      try {
        if (await raf.length() < 4) return false;
        await raf.setPosition(0);
        final head = await raf.read(4);
        if (head.length < _apkMagic.length) return false;
        for (var i = 0; i < _apkMagic.length; i++) {
          if (head[i] != _apkMagic[i]) return false;
        }
        return true;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort — a stale file is harmless once we re-download.
    }
  }

  static Future<UpdateInstallResult> _installApk(String filePath) async {
    final override = installOverride;
    if (override != null) {
      try {
        return await override(filePath);
      } catch (e) {
        debugPrint("APK install failed: $e");
        return UpdateInstallResult.installFailed;
      }
    }
    try {
      var hasPermission = await _installChannel.invokeMethod<bool>(
        'checkInstallPermission',
      );
      if (hasPermission != true) {
        hasPermission = await _installChannel.invokeMethod<bool>(
          'requestInstallPermission',
        );
      }
      if (hasPermission != true) {
        return UpdateInstallResult.permissionDenied;
      }

      final result = await _installChannel.invokeMethod<String>(
        'installApk',
        filePath,
      );
      return result == 'installed'
          ? UpdateInstallResult.installed
          : UpdateInstallResult.cancelled;
    } on PlatformException catch (e) {
      debugPrint("APK install failed: $e");
      return e.code == 'PERMISSION_REQUIRED'
          ? UpdateInstallResult.permissionDenied
          : UpdateInstallResult.installFailed;
    } catch (e) {
      debugPrint("APK install failed: $e");
      return UpdateInstallResult.installFailed;
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String message,
    bool force,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: !force,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return _UpdateDialog(
          version: version,
          message: message,
          force: force,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: child,
        );
      },
    );
  }
}

enum _DownloadState { idle, downloading, done, error }

class _UpdateDialog extends StatefulWidget {
  final String version;
  final String message;
  final bool force;

  const _UpdateDialog({
    required this.version,
    required this.message,
    required this.force,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _DownloadState _state = _DownloadState.idle;
  double _progress = 0.0;
  String? _errorMsg;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    if (widget.force) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startDownload());
    }
  }

  Future<void> _startDownload() async {
    if (_state == _DownloadState.downloading) return;
    setState(() {
      _state = _DownloadState.downloading;
      _progress = 0.0;
      _errorMsg = null;
    });

    try {
      final outcome = await UpdateChecker.downloadAndInstallApk(
        version: widget.version,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (!mounted) return;

      switch (outcome) {
        case UpdateInstallResult.installed:
          setState(() => _state = _DownloadState.done);
          if (context.mounted) Navigator.of(context).pop();
        case UpdateInstallResult.cancelled:
        case UpdateInstallResult.unsupported:
          setState(() => _state = _DownloadState.done);
        case UpdateInstallResult.permissionDenied:
          setState(() {
            _state = _DownloadState.error;
            _errorMsg = "Allow installs from this source, then try again.";
          });
        case UpdateInstallResult.downloadFailed:
          setState(() {
            _state = _DownloadState.error;
            _errorMsg = "Download failed. Check your connection and try again.";
          });
        case UpdateInstallResult.storageFull:
          setState(() {
            _state = _DownloadState.error;
            _errorMsg =
                "Not enough free space to save the update. Free up some storage and try again.";
          });
        case UpdateInstallResult.checksumUnavailable:
          setState(() {
            _state = _DownloadState.error;
            _errorMsg =
                "Couldn't verify the download. Get the update directly from GitHub instead.";
          });
        case UpdateInstallResult.checksumMismatch:
          setState(() {
            _state = _DownloadState.error;
            _errorMsg =
                "The downloaded file didn't pass its security check. Get the update directly from GitHub instead.";
          });
        case UpdateInstallResult.installFailed:
          setState(() {
            _state = _DownloadState.error;
            _errorMsg = "Install failed. Please try again.";
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _DownloadState.error;
        _errorMsg = "Download failed. Check your connection and try again.";
      });
    }
  }

  /// Escape hatch for every failure: the release page always offers the APK,
  /// so a broken in-app path never leaves the user without a way to update.
  Future<void> _openReleasePage() async {
    try {
      final opened = await launchUrl(
        Uri.parse(UpdateChecker._releasesLatestUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) debugPrint("Release page launch returned false");
    } catch (e) {
      debugPrint("Release page launch failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final secondaryColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : AppColors.lightTextSecondary;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : AppColors.lightSurfaceCard;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1B2E), const Color(0xFF121218)]
                  : AppColors.lightGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.lightBorder.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "New Update Available!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Version ${widget.version}",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryColor,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_state == _DownloadState.downloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.lightBorder,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _progress > 0
                      ? "Downloading... ${(_progress * 100).toInt()}%"
                      : "Preparing download...",
                  style: TextStyle(fontSize: 13, color: secondaryColor),
                ),
              ] else if (_state == _DownloadState.error) ...[
                Text(
                  _errorMsg ?? "Something went wrong.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _openReleasePage,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text("Download from GitHub"),
                ),
                const SizedBox(height: 4),
              ],
              if (_state != _DownloadState.downloading)
                Row(
                  children: [
                    if (!widget.force)
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: secondaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text("Later"),
                        ),
                      ),
                    if (!widget.force) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _startDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        child: const Text(
                          "Download & Install",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
