import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:http/http.dart' as http;
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Screens/update_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateChecker {
  static Future<void> checkForUpdate() async {
    try {
      final url = Uri.parse(
        "https://raw.githubusercontent.com/justaman045/Money_Control/master/app_version.json",
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        debugPrint("Error with the Setup");
        return;
      } else if (response.statusCode != 200) {
        return;
      }

      final data = jsonDecode(response.body);

      final latestVersion = data["latest_version"] as String? ?? '';
      final updateMessage = data["update_message"] as String? ?? '';
      if (latestVersion.isEmpty) return;
      final isForce = data["force"] as bool? ?? false;

      final package = await PackageInfo.fromPlatform();
      final currentVersion = package.version;

      if (_isNewerVersion(latestVersion, currentVersion)) {
        _maybeShowUpdateDialog(latestVersion, updateMessage, isForce);
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  // Sync helper so no BuildContext is used inside the async function.
  // Get.overlayContext is always the active navigator's overlay — never stale.
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

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String message,
    bool force,
  ) {
    // final scheme = Theme.of(context).colorScheme;

    showGeneralDialog(
      context: context,
      barrierDismissible: !force,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 24),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Get.isDarkMode
                      ? [const Color(0xFF2E1A47), const Color(0xFF1A1A2E)]
                      : AppColors.lightGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Get.isDarkMode
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppColors.lightBorder.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B4CFF).withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon header
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Color(0xFF00E5FF),
                      size: 32,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "New Update Available!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Get.isDarkMode
                          ? Colors.white
                          : AppColors.lightTextPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Version $version",
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF00E5FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Get.isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Get.isDarkMode
                            ? Colors.white70
                            : AppColors.lightTextSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      if (!force)
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Get.isDarkMode
                                  ? Colors.white54
                                  : AppColors.lightTextSecondary,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text("Later"),
                          ),
                        ),
                      if (!force) SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            gotoPage(UpdatePage());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
                            shadowColor: const Color(
                              0xFF00E5FF,
                            ).withValues(alpha: 0.4),
                          ),
                          child: const Text(
                            "Update Now",
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
