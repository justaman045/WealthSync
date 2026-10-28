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
import 'package:money_control/Utils/version_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Outcome of an in-app update attempt, so the UI can explain *why* it failed
/// instead of a single generic message.
enum UpdateInstallResult {
  installed,
  cancelled,
  permissionDenied,
  downloadFailed,
  installFailed,
  unsupported,
}

class UpdateChecker {
  static const lastDialogKey = 'last_update_dialog_shown';
  static const _installChannel = MethodChannel('money_control/install');

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

  /// Downloads an APK from the GitHub release and triggers Android install.
  /// [onProgress] is called with a value between 0.0 and 1.0 during download.
  ///
  /// The temp file is treated as disposable: any leftover from a previous
  /// attempt is removed first, and a truncated/empty/invalid download is
  /// deleted rather than handed to the installer. Install a partial APK and
  /// Android reports "There was a problem parsing the package".
  Future<String?> _fetchSha256(String version) async {
    try {
      final client = http.Client();
      try {
        final uri = Uri.parse(
            'https://github.com/justaman045/WealthSync/releases/download/v$version/SHA256SUMS');
        final resp = await client.get(uri, headers: {'User-Agent': 'WealthSync-Updater'});
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
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Failed to fetch SHA256SUMS: $e');
      return null;
    }
  }

  Future<bool> _verifySha256(File file, String expected) async {
    try {
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      final actual = digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return actual.toLowerCase() == expected.toLowerCase();
    } catch (e) {
      debugPrint('SHA256 verification failed: $e');
      return false;
    }
  }

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
      final dir = await getTemporaryDirectory();
      file = File("${dir.path}/WealthSync-v$version.apk");

      await _safeDelete(file);

      final client = http.Client();
      try {
        final response = await client.send(
          http.Request('GET', Uri.parse(_apkUrl(version))),
        );
        if (response.statusCode != 200) {
          return UpdateInstallResult.downloadFailed;
        }

        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('text/html')) {
          debugPrint('APK download failed: received HTML response');
          return UpdateInstallResult.downloadFailed;
        }

        final totalBytes = response.contentLength ?? 0;
        final sink = file.openWrite();
        int received = 0;
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            received += chunk.length;
            if (totalBytes > 0) {
              onProgress?.call(received / totalBytes);
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        if (received == 0) {
          debugPrint("APK download incomplete: $received/$totalBytes bytes");
          await _safeDelete(file);
          return UpdateInstallResult.downloadFailed;
        }
        if (totalBytes > 0 && received != totalBytes) {
          debugPrint("APK download incomplete: $received/$totalBytes bytes");
          await _safeDelete(file);
          return UpdateInstallResult.downloadFailed;
        }
      } finally {
        client.close();
      }

      if (!await _looksLikeApk(file)) {
        debugPrint("Downloaded file is not a valid APK (bad magic bytes)");
        await _safeDelete(file);
        return UpdateInstallResult.downloadFailed;
      }

      final checker = UpdateChecker();
      final expectedSha = await checker._fetchSha256(version);
      if (expectedSha != null) {
        final ok = await checker._verifySha256(file, expectedSha);
        if (!ok) {
          debugPrint('APK SHA256 mismatch');
          await _safeDelete(file);
          return UpdateInstallResult.downloadFailed;
        }
      } else {
        debugPrint('No SHA256SUMS found for release, skipping checksum verification');
      }

      return await UpdateChecker._installApk(file.path);
    } catch (e) {
      debugPrint("APK download failed: $e");
      if (file != null) await _safeDelete(file);
      return UpdateInstallResult.downloadFailed;
    }
  }

  static const _apkMagic = [0x50, 0x4b, 0x03, 0x04]; // "PK\x03\x04"

  /// A real APK is a ZIP archive, so it must start with the ZIP local-file
  /// header. Guards against an HTML error page or other non-APK payload.
  static Future<bool> _looksLikeApk(File file) async {
    try {
      final raf = await file.open();
      try {
        if (await raf.length() < 4) return false;
        raf.setPosition(0);
        final head = await raf.read(4);
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
            _errorMsg = "Download failed. Please try again.";
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
        _errorMsg = "Download failed. Please try again.";
      });
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
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
                const SizedBox(height: 12),
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
