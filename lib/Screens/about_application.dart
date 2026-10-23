import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Components/colors.dart';

class AboutApplicationScreen extends StatefulWidget {
  const AboutApplicationScreen({super.key});

  @override
  State<AboutApplicationScreen> createState() => _AboutApplicationScreenState();
}

class _AboutApplicationScreenState extends State<AboutApplicationScreen> {
  String _appVersion = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = info.version);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            AppColors.darkBackground, // Midnight Void
            AppColors.darkSurface.withValues(alpha: 0.95),
          ]
        : [AppColors.lightBackground, AppColors.lightBorder]; // Premium Light

    final textColor = isDark ? Colors.white : AppColors.darkBackground;
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : AppColors.darkBackground.withValues(alpha: 0.6);

    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.6);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            "About Application",
            style: AppType.titleMedium(textColor),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20.sp),
            onPressed: () => Navigator.pop(context),
          ),
          toolbarHeight: 64.h,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
              // APP HEADER CARD
              _appInfoCard(
                surface: cardColor,
                border: borderColor,
                scheme: scheme,
                version: _appVersion,
                secondary: secondaryTextColor,
                textColor: textColor,
                isDark: isDark,
              ),
              SizedBox(height: 22.h),

              _sectionLabel("Developer", secondaryTextColor),
              SizedBox(height: 8.h),
              _developerTile(
                cardColor,
                borderColor,
                scheme,
                secondaryTextColor,
                textColor,
                isDark,
              ),

              SizedBox(height: 22.h),

              _sectionLabel("Acknowledgements", secondaryTextColor),
              SizedBox(height: 8.h),
              _acknowledgementCard(
                cardColor,
                borderColor,
                scheme,
                secondaryTextColor,
                textColor,
                isDark,
              ),

              SizedBox(height: 30.h),
            ],
          ),
        ),
        ),
      ),
      ),
    );
  }

  Widget _sectionLabel(String title, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: AppType.labelMedium(color),
      ),
    );
  }

  // ---------------- APP INFO CARD ----------------
  Widget _appInfoCard({
    required Color surface,
    required Color border,
    required ColorScheme scheme,
    required String version,
    required Color secondary,
    required Color textColor,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15.w,
            offset: Offset(0, 5.w),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 18.h),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40.r,
            backgroundColor: scheme.primary.withValues(alpha: 0.15),
            backgroundImage: const AssetImage("assets/app_logo.png"),
          ),
          SizedBox(height: 14.h),
          Text(
            "WealthSync",
            style: AppType.titleLarge(textColor),
          ),
          SizedBox(height: 6.h),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: version == "Loading..." ? 0.5 : 1,
            child: Text(
              "Version $version",
              style: AppType.bodySmall(secondary),
            ),
          ),
          SizedBox(height: 14.h),
          Divider(color: border),
          SizedBox(height: 12.h),
          Text(
            "Empower your financial journey with WealthSync. Seamlessly track expenses, visualize income streams, and gain profound insights into your spending habits with our AI-powered analytics. Crafted for elegance, designed for control.",
            textAlign: TextAlign.center,
            style: AppType.bodySmall(textColor.withValues(alpha: 0.85)),
          ),
          SizedBox(height: 18.h),
        ],
      ),
    );
  }

  // ---------------- DEVELOPER TILE ----------------
  Widget _developerTile(
    Color surface,
    Color border,
    ColorScheme scheme,
    Color secondary,
    Color textColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15.w,
            offset: Offset(0, 5.w),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          leading: CircleAvatar(
            radius: 24.r,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.lightSurfaceCard,
            child: const Icon(Icons.code_rounded, color: AppColors.success),
          ),
          title: Text(
            "Developed by Aman Ojha",
            style: AppType.labelLarge(textColor),
          ),
          subtitle: Text(
            "Software Engineer & Designer",
            style: AppType.bodySmall(secondary),
          ),
        ),
      ),
    );
  }

  // ---------------- ACKNOWLEDGEMENT CARD ----------------
  Widget _acknowledgementCard(
    Color surface,
    Color border,
    ColorScheme scheme,
    Color secondary,
    Color textColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15.w,
            offset: Offset(0, 5.w),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Powered by open-source technologies:",
            style: AppType.labelMedium(secondary),
          ),
          SizedBox(height: 10.h),

          _bullet("Flutter Framework", textColor),
          _bullet("Firebase Authentication & Firestore", textColor),
          _bullet("GetX – State Management & Routing", textColor),
          _bullet("flutter_screenutil – Responsive UI", textColor),
          _bullet("package_info_plus", textColor),
          _bullet("share_plus, printing, and more", textColor),

          SizedBox(height: 16.h),
          Row(
            children: [
              Icon(
                Icons.copyright,
                size: 16.sp,
                color: secondary.withValues(alpha: 0.9),
              ),
              SizedBox(width: 6.w),
              Text(
                "${DateTime.now().year} WealthSync",
                style: AppType.bodySmall(secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text, Color textColor) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "•  ",
            style: AppType.bodyMedium(Colors.grey.shade500),
          ),
          Expanded(
            child: Text(
              text,
              style: AppType.bodySmall(textColor.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }
}
