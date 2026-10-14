import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:money_control/Components/colors.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static const lastDialogKey = 'last_update_dialog_shown';
  static const _installChannel = MethodChannel('money_control/install');

  static Future<void> checkForUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (prefs.getString(lastDialogKey) == todayStr) return;

      final url = Uri.parse(
        "https://raw.githubusercontent.com/justaman045/WealthSync/master/app_version.json",
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        debugPrint("Error with the Setup");
        return;
      } else if (response.statusCode != 200) {
        return;
      }

      final data = jsonDecode(response.body);
      if (data is! Map) return;

      final latestVersion = data["latest_version"] as String? ?? '';
      final updateMessage = data["update_message"] as String? ?? '';
      if (latestVersion.isEmpty) return;
      final isForce = data["force"] as bool? ?? false;

      final package = await PackageInfo.fromPlatform();
      final currentVersion = package.version;

      await prefs.setString(lastDialogKey, todayStr);

      if (_isNewerVersion(latestVersion, currentVersion)) {
        _maybeShowUpdateDialog(latestVersion, updateMessage, isForce);
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  /// Manual check triggered by the user — bypasses the daily throttle and
  /// returns whether a newer version was found so the caller can show feedback.
  static Future<bool> checkForUpdateManual() async {
    try {
      final url = Uri.parse(
        "https://raw.githubusercontent.com/justaman045/WealthSync/master/app_version.json",
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body);
      if (data is! Map) return false;

      final latestVersion = data["latest_version"] as String? ?? '';
      final updateMessage = data["update_message"] as String? ?? '';
      if (latestVersion.isEmpty) return false;
      final isForce = data["force"] as bool? ?? false;

      final package = await PackageInfo.fromPlatform();
      final currentVersion = package.version;

      if (_isNewerVersion(latestVersion, currentVersion)) {
        _maybeShowUpdateDialog(latestVersion, updateMessage, isForce);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Manual update check failed: $e");
      return false;
    }
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

  static bool _isNewerVersion(String remote, String local) {
    String clean(String v) => v.split('-').first;
    List<int> r = clean(remote).split('.').map((s) => int.tryParse(s) ?? 0).toList();
    List<int> l = clean(local).split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (r.length < 3) { r.add(0); }
    while (l.length < 3) { l.add(0); }

    for (int i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  /// Downloads an APK from the GitHub release and triggers Android install.
  /// [onProgress] is called with a value between 0.0 and 1.0 during download.
  static Future<bool> downloadAndInstallApk({
    required String version,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      final url = Uri.parse(
        "https://github.com/justaman045/WealthSync/releases/download/v$version/app-release.apk",
      );
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return false;
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/WealthSync-v$version.apk");

      if (await file.exists()) {
        return await _installApk(file.path);
      }

      final downloadUrl = Uri.parse(
        "https://github.com/justaman045/WealthSync/releases/download/v$version/app-release.apk",
      );

      final client = http.Client();
      try {
        final request = await client.send(
          http.Request('GET', downloadUrl),
        );
        final totalBytes = request.contentLength ?? 0;
        final sink = file.openWrite();
        int received = 0;

        await for (final chunk in request.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (totalBytes > 0) {
            onProgress?.call(received / totalBytes);
          }
        }

        await sink.flush();
        await sink.close();
        if (request.statusCode != 200) {
          await file.delete();
          return false;
        }
      } finally {
        client.close();
      }

      return await _installApk(file.path);
    } catch (e) {
      debugPrint("APK download failed: $e");
      return false;
    }
  }

  static Future<bool> _installApk(String filePath) async {
    try {
      var hasPermission = await _installChannel.invokeMethod<bool>(
        'checkInstallPermission',
      );
      if (hasPermission != true) {
        hasPermission = await _installChannel.invokeMethod<bool>(
          'requestInstallPermission',
        );
      }
      if (hasPermission == true) {
        final result = await _installChannel.invokeMethod<String>(
          'installApk',
          filePath,
        );
        return result == 'installed';
      }
      return false;
    } catch (e) {
      debugPrint("APK install failed: $e");
      return false;
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
      final installed = await UpdateChecker.downloadAndInstallApk(
        version: widget.version,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (!mounted) return;
      setState(() => _state = _DownloadState.done);

      if (installed && context.mounted) {
        Navigator.of(context).pop();
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
                  style: const TextStyle(fontSize: 13, color: Colors.redAccent),
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
                          foregroundColor: Colors.black,
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
