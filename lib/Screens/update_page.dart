import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Utils/responsive.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  Map<String, dynamic>? releaseData;
  Map<String, dynamic>? analysisData;
  bool loading = true;
  bool analyzing = false;
  bool error = false;

  @override
  void initState() {
    super.initState();
    fetchLatestRelease();
  }

  Future<void> fetchLatestRelease() async {
    try {
      final url = Uri.parse(
        "https://api.github.com/repos/justaman045/Money_Control/releases/latest",
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! Map) {
          if (!mounted) return;
          setState(() { error = true; loading = false; });
          return;
        }
        final mapData = Map<String, dynamic>.from(data);
        if (!mounted) return;
        setState(() {
          releaseData = mapData;
          loading = false;
        });

        // Trigger smart analysis after fetching release
        final tagName = mapData["tag_name"];
        if (tagName != null) {
          fetchAnalysis(tagName);
        }
      } else {
        if (!mounted) return;
        setState(() {
          error = true;
          loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = true;
        loading = false;
      });
    }
  }

  Future<void> fetchAnalysis(String remoteTag) async {
    setState(() => analyzing = true);
    try {
      final package = await PackageInfo.fromPlatform();
      final localVersion = "v${package.version}"; // Assuming format vX.X.X

      // GitHub Compare: base...head
      final url = Uri.parse(
        "https://api.github.com/repos/justaman045/Money_Control/compare/$localVersion...$remoteTag",
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            setState(() {
              analysisData = Map<String, dynamic>.from(data);
              analyzing = false;
            });
          } else {
            setState(() => analyzing = false);
          }
        }
      } else {
        if (mounted) setState(() => analyzing = false);
      }
    } catch (e) {
      if (mounted) setState(() => analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Update Available",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2E1A47), ...AppColors.darkGradient]
                : [const Color(0xFFE8E0F0), ...AppColors.lightGradient],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
              )
            : error
            ? _errorContent()
            : _content(),
      ),
    );
  }

  Widget _content() {
    final tag = releaseData?["tag_name"] ?? "Unknown";
    final body = releaseData?["body"] ?? "";
    final publishedRaw = releaseData?["published_at"] ?? "";
    final publishedDate = DateTime.tryParse(publishedRaw);

    // Construct the APK URL directly from the tag — CI always uploads app-release.apk.
    // Fall back to scanning assets only when the direct URL can't be built.
    final assets = releaseData?["assets"] as List<dynamic>? ?? [];
    final String downloadUrl = () {
      if (tag != "Unknown") {
        return "https://github.com/justaman045/Money_Control/releases/download/$tag/app-release.apk";
      }
      // Secondary: scan assets, explicitly skipping .aab files
      final apkAsset = assets.firstWhere(
        (a) {
          final name = (a["name"] as String? ?? '').toLowerCase();
          return name.endsWith('.apk') && !name.endsWith('.aab');
        },
        orElse: () => <String, dynamic>{},
      );
      return apkAsset?["browser_download_url"] as String? ??
          "https://github.com/justaman045/Money_Control/releases";
    }();

    final fullReleaseUrl =
        releaseData?["html_url"] ??
        "https://github.com/justaman045/Money_Control/releases";

    final features = _parseChangelog(body);

    // SMART ANALYSIS RESULTS
    final intelligentSummary = _generateIntelligentSummary();

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        children: [
          // ------------------------------------------------------------
          // HEADER CARD
          // ------------------------------------------------------------
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15.w,
                  offset: Offset(0, 8.w),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: const Color(0xFF00E5FF),
                    size: 40.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  "Version $tag",
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  publishedDate != null
                      ? "Released on ${publishedDate.toLocal().toString().split(' ')[0]}"
                      : "New Release",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // ------------------------------------------------------------
          // CHANGELOG
          // ------------------------------------------------------------
          Text(
            "What’s New",
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 12.h),

          Container(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                if (features.isEmpty &&
                    intelligentSummary.isEmpty &&
                    !analyzing)
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      "Bug fixes and improvements.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),

                // MANUAL FEATURES (if any)
                ...features.map((feature) {
                  return _buildFeatureRow(
                    feature,
                    Icons.check_circle_outline_rounded,
                    const Color(0xFF00E676),
                  );
                }),

                // GENERATED ANALYSIS (Separated)
                if (intelligentSummary.isNotEmpty) ...[
                  if (features.isNotEmpty)
                    Divider(color: Colors.white.withValues(alpha: 0.1)),
                  ...intelligentSummary.map((item) {
                    return _buildFeatureRow(
                      item,
                      Icons.auto_awesome_rounded,
                      const Color(0xFF2979FF),
                    );
                  }),
                ],

                if (analyzing)
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 40.h),

          // ------------------------------------------------------------
          // ACTIONS
          // ------------------------------------------------------------
          SizedBox(
            width: double.infinity,
            height: 54.h,
            child: ElevatedButton(
              onPressed: () => launchUrl(
                Uri.parse(downloadUrl),
                mode: LaunchMode.externalApplication,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.download_rounded),
                  SizedBox(width: 8.w),
                  Text(
                    "Download Update",
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Center(
            child: TextButton(
              onPressed: () => launchUrl(
                Uri.parse(fullReleaseUrl),
                mode: LaunchMode.externalApplication,
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text("View Full Changelog on GitHub"),
            ),
          ),
          SizedBox(height: 20.h),
        ],
          ),
        ),
      ),
    );
  }

  Widget _errorContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent.shade100,
            size: 48.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            "Could not fetch release info.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16.sp,
            ),
          ),
          TextButton(
            onPressed: () => fetchLatestRelease(),
            child: const Text(
              "Retry",
              style: TextStyle(color: Color(0xFF00E5FF)),
            ),
          ),
        ],
      ),
    );
  }

  // Parses GitHub release body into clear bullet points
  List<String> _parseChangelog(String body) {
    if (body.isEmpty) return [];

    // Split by lines
    final lines = body.split('\n');
    final List<String> cleaned = [];

    for (var line in lines) {
      line = line.trim();

      // Skip empty or useless lines
      if (line.isEmpty) continue;
      if (line.contains("Full Changelog")) continue;
      if (line.startsWith("##")) continue; // Headers like "What's Changed"

      // Clean up markdown bullets (- or *)
      line = line.replaceAll(RegExp(r'^[\*\-]\s*'), '');

      // Clean up "by @user" suffix common in GitHub Actions auto-gen notes
      // e.g. "Fix bug abc by @justaman045 in #123" -> remove "by @..."
      // Simple regex to catch " by @..." till end or before " in "
      // Actually usually it's "Title by @user in PR"

      // Let's strip the attribution
      final byIndex = line.lastIndexOf(" by @");
      if (byIndex != -1) {
        line = line.substring(0, byIndex);
      }

      if (line.isNotEmpty) {
        cleaned.add(line);
      }
    }
    return cleaned;
  }

  Widget _buildFeatureRow(String text, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: Icon(icon, color: color, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14.5.sp,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Analyzes raw commit data to generate "Smart Summaries"
  List<String> _generateIntelligentSummary() {
    if (analysisData == null) return [];

    final Set<String> summaries = {};

    // 1. Analyze Files
    final files = analysisData!["files"] as List<dynamic>? ?? [];
    for (var f in files) {
      final String name = f["filename"] ?? "";

      if (name.contains("lib/Screens/analysis.dart")) {
        summaries.add("Enhanced AI Insights logic");
      }
      if (name.contains("lib/Screens/subscription")) {
        summaries.add("Updated Subscription Manager");
      }
      if (name.contains("lib/Screens/edit_profile.dart")) {
        summaries.add("Improved User Profile & DOB");
      }
      if (name.contains("lib/Services/recurring_service.dart")) {
        summaries.add("Refined Recurring Payments");
      }
      if (name.contains("pubspec.yaml")) {
        summaries.add("Updated Dependencies");
      }
      if (name.contains("lib/Screens/update_page.dart")) {
        summaries.add("Improved Update Screen");
      }
    }

    // 2. Analyze Commits (if sparse file analysis)
    final commits = analysisData!["commits"] as List<dynamic>? ?? [];
    for (var c in commits) {
      final msg = c["commit"]["message"] as String? ?? "";
      final firstLine = msg.split('\n').first;

      // Heuristic: If it's a "feat" or "fix", add it.
      if (firstLine.toLowerCase().startsWith("feat") ||
          firstLine.toLowerCase().startsWith("fix") ||
          firstLine.toLowerCase().startsWith("add") ||
          firstLine.toLowerCase().startsWith("update")) {
        // Clean it up
        var clean = firstLine.replaceAll(
          RegExp(r'(\(#[0-9]+\))'),
          '',
        ); // Remove (#123)
        if (clean.length > 50) clean = "${clean.substring(0, 47)}...";

        // Only add if not redundant
        if (!summaries.any((s) => s.toLowerCase() == clean.toLowerCase())) {
          summaries.add(clean);
        }
      }
    }

    return summaries.take(5).toList(); // Limit to top 5
  }
}
