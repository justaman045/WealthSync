import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Services/local_backup_service.dart';

class LegalTrustPage extends StatefulWidget {
  const LegalTrustPage({super.key});

  @override
  State<LegalTrustPage> createState() => _LegalTrustPageState();
}

class _LegalTrustPageState extends State<LegalTrustPage> {
  bool consentDataProcessing = false;
  bool consentMarketing = false;
  bool deletingData = false;
  bool downloadingData = false;

  String? message;

  @override
  void initState() {
    super.initState();
    _loadUserConsents();
  }

  Future<void> _loadUserConsents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.email)
          .get();

      if (mounted) {
        setState(() {
          consentDataProcessing = doc.data()?["consent_data"] ?? false;
          consentMarketing = doc.data()?["consent_marketing"] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load user consents: $e");
    }
  }

  Future<void> _toggleConsent(String key, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (key == 'data') consentDataProcessing = value;
      if (key == 'marketing') consentMarketing = value;
    });

    await FirebaseFirestore.instance.collection("users").doc(user.email).update(
      {
        "consent_data": consentDataProcessing,
        "consent_marketing": consentMarketing,
      },
    );
  }

  /// -------------------------------------------------------
  /// 🔥 DELETE ALL USER DATA EXCEPT EMAIL
  /// -------------------------------------------------------
  Future<void> _requestDataDeletion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      deletingData = true;
      message = null;
    });

    try {
      final userDoc = FirebaseFirestore.instance
          .collection("users")
          .doc(user.email);

      /// Delete transactions collection
      final txSnap = await userDoc.collection("transactions").get();
      for (var doc in txSnap.docs) {
        await doc.reference.delete();
      }

      /// Delete categories
      final catSnap = await userDoc.collection("categories").get();
      for (var doc in catSnap.docs) {
        await doc.reference.delete();
      }

      /// Delete offline backups
      final backupSnap = await userDoc.collection("backups").get();
      for (var doc in backupSnap.docs) {
        await doc.reference.delete();
      }

      /// Delete insights, preferences, logs etc.
      final anySubCollections = ["insights", "preferences", "logs"];
      for (String name in anySubCollections) {
        final coll = await userDoc.collection(name).get();
        for (var doc in coll.docs) {
          await doc.reference.delete();
        }
      }

      /// DO NOT DELETE MAIN USER DOC
      /// Just clear fields except email.
      await userDoc.update({
        "createdAt": FieldValue.serverTimestamp(),
        "consent_data": false,
        "consent_marketing": false,
      });

      if (mounted) {
        setState(() {
          deletingData = false;
          message =
              "Your data deletion request is successful. All financial & personal data has been erased except your account email.";
        });
      }

      Get.snackbar(
        "Data Cleared",
        "All your data (except email) has been deleted.",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          deletingData = false;
          message = "Error deleting data: $e";
        });
      }
      Get.snackbar(
        "Error",
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// -------------------------------------------------------
  /// 📄 DOWNLOAD USER DATA AS JSON
  /// -------------------------------------------------------
  Future<void> _downloadMyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    setState(() => downloadingData = true);

    try {
      // final userDoc = FirebaseFirestore.instance
      //     .collection("users")
      //     .doc(user.email);

      // final txSnap = await userDoc.collection("transactions").get();
      // final catSnap = await userDoc.collection("categories").get();

      /// This map isn't strictly needed if using LocalBackupService, but kept for logic structure
      // final export = {
      //   "email": user.email,
      //   "transactions": txSnap.docs
      //       .map((e) => {"id": e.id, ...e.data()})
      //       .toList(),
      //   "categories": catSnap.docs
      //       .map((e) => {"id": e.id, ...e.data()})
      //       .toList(),
      // };

      await LocalBackupService.exportBackupFile(user.email!);

      if (mounted) setState(() => downloadingData = false);

      Get.snackbar(
        "Data Ready",
        "Your data export file has been created.",
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
    } catch (e) {
      if (mounted) setState(() => downloadingData = false);
      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// -------------------------------------------------------
  /// UI
  /// -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            const Color(0xFF1A1A2E), // Midnight Void
            const Color(0xFF16213E).withValues(alpha: 0.95),
          ]
        : [
            const Color(0xFFF5F7FA), // Premium Light
            const Color(0xFFC3CFE2),
          ];

    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1A1A2E).withValues(alpha: 0.6);

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
          title: Text(
            "Legal & Privacy",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20.sp),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        bottomNavigationBar: const BottomNavBar(currentIndex: 3),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGlassSection(
                title: "Terms of Service",
                content: _termsOfServiceText,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                secondaryColor: secondaryTextColor,
                isDark: isDark,
              ),
              SizedBox(height: 20.h),
              _buildGlassSection(
                title: "Privacy Policy",
                content: _privacyPolicyText,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                secondaryColor: secondaryTextColor,
                isDark: isDark,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://justaman045.github.io/Money_Control/privacy_policy.html',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: Icon(
                    Icons.open_in_new,
                    size: 14.sp,
                    color: Colors.blue,
                  ),
                  label: Text(
                    "View full policy online",
                    style: TextStyle(fontSize: 13.sp, color: Colors.blue),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              _sectionTitle("Your Consents", textColor),
              SizedBox(height: 10.h),
              _buildConsentSection(
                cardColor,
                borderColor,
                textColor,
                secondaryTextColor,
              ),
              SizedBox(height: 24.h),
              _sectionTitle("Data Management", textColor),
              SizedBox(height: 10.h),
              _buildDataActions(cardColor, borderColor, textColor, isDark),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  Widget _buildGlassSection({
    required String title,
    required String content,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color secondaryColor,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF6C63FF) : Colors.deepPurple,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            content,
            style: TextStyle(
              fontSize: 13.5.sp,
              height: 1.5,
              color: secondaryColor,
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }

  Widget _buildConsentSection(
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color secondaryColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _consentTile(
            "Consent to Data Processing",
            "Allow the app to process data to improve services.",
            consentDataProcessing,
            (v) => _toggleConsent('data', v),
            textColor,
            secondaryColor,
          ),
          Divider(color: borderColor, height: 1),
          _consentTile(
            "Marketing Communication",
            "Receive optional promotional updates.",
            consentMarketing,
            (v) => _toggleConsent('marketing', v),
            textColor,
            secondaryColor,
          ),
        ],
      ),
    );
  }

  Widget _consentTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    Color textColor,
    Color secondaryColor,
  ) {
    return SwitchListTile(
      activeThumbColor: const Color(0xFF6C63FF),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 14.5.sp,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: secondaryColor, fontSize: 12.sp),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildDataActions(
    Color cardColor,
    Color borderColor,
    Color textColor,
    bool isDark,
  ) {
    return Column(
      children: [
        // Download Button
        Container(
          width: double.infinity,
          height: 52.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26.r),
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF6C63FF), const Color(0xFF4834D4)]
                  : [
                      const Color(0xFF6C63FF).withValues(alpha: 0.8),
                      const Color(0xFF4834D4).withValues(alpha: 0.8),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: downloadingData ? null : _downloadMyData,
            icon: downloadingData
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download_rounded, color: Colors.white),
            label: Text(
              downloadingData ? "Preparing..." : "Download My Data (JSON)",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // Delete Button
        SizedBox(
          width: double.infinity,
          height: 52.h,
          child: OutlinedButton(
            onPressed: deletingData ? null : _requestDataDeletion,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26.r),
              ),
              foregroundColor: Colors.redAccent,
            ),
            child: deletingData
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: const CircularProgressIndicator(
                      color: Colors.redAccent,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    "Delete My Data Permanently",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                    ),
                  ),
          ),
        ),

        if (message != null) ...[
          SizedBox(height: 15.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              message!,
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  /// -------------------------------------------------------
  /// TEXTS
  /// -------------------------------------------------------
  final String _termsOfServiceText = '''
By using this application, you agree to the following Terms of Service:

• You are responsible for the accuracy of the data you enter.
• The app provides financial insights but is not a substitute for professional financial advice.
• We reserve the right to update features, pricing, or terms at any time.
• Any misuse, abuse, or unauthorized activities may result in restricted access.
• You must not use the app for illegal, harmful, or fraudulent activities.

Continued use of this app means you accept the latest version of our Terms.
''';

  final String _privacyPolicyText = '''
We are committed to protecting your personal data.

What We Collect:
• Basic profile information (email)
• Financial transactions that you manually add
• Categories and notes you create
• App usage data to improve features
• SMS messages (Pro feature — bank notifications only, processed on-device)

SMS Data Collection:
We access device SMS messages solely to detect bank transaction notifications for automatic expense import. SMS content is processed entirely on-device. We extract only the transaction amount, merchant name, and date — no SMS body text is stored on our servers or shared with any third party. This feature requires your explicit permission and can be revoked at any time from your device settings.

How Your Data is Used:
• To provide budgeting & analytics features
• To personalize insights
• To improve app performance

Your Rights:
• You can request your data at any time
• You may update, correct, or delete your data
• You may request permanent deletion (except your email used for login)
• You can withdraw your consent at any time

We NEVER:
• Sell your data
• Share with third parties without consent
• Store SMS message body text on our servers

Your data is securely stored with industry-standard encryption.
''';
}
