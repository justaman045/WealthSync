// lib/Screens/feedback_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:money_control/Services/error_handler.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  String _appVersion = "Loading...";

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = info.version);
  }

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  late final _appVersionCtrl = TextEditingController(text: _appVersion);
  final _deviceModelCtrl = TextEditingController();
  final _osVersionCtrl = TextEditingController();

  bool _submitting = false;

  // === GOOGLE FORM CONFIG ===
  // This is the "formResponse" URL you saw in DevTools
  static const String _formUrl =
      "https://docs.google.com/forms/d/e/1FAIpQLSdf0mRQBB1mcwIIGpOPaHRhONYjGNLPRNy11fYyfHylK2mitg/formResponse";

  // These entry IDs come from the payload (Network tab → Payload → Form Data)
  static const String _entryName = "entry.1368653212";
  static const String _entryEmail = "entry.1731016817";
  static const String _entryFeedback = "entry.773676350";
  static const String _entryAppVersion = "entry.123699386";
  static const String _entryDeviceModel = "entry.1615870811";
  static const String _entryOsVersion = "entry.1846805458";

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _feedbackCtrl.dispose();
    _appVersionCtrl.dispose();
    _deviceModelCtrl.dispose();
    _osVersionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final body = {
        _entryName: _nameCtrl.text.trim(),
        _entryEmail: FirebaseAuth.instance.currentUser?.email ?? '',
        _entryFeedback: _feedbackCtrl.text.trim(),
        _entryAppVersion: _appVersionCtrl.text.trim(),
        _entryDeviceModel:
            "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}",
        _entryOsVersion:
            "${DateTime.now().day} - ${DateTime.now().month} - ${DateTime.now().year}",
        // Optional extra fields like "fvv", "pageHistory" are not required
      };

      final resp = await http.post(
        Uri.parse(_formUrl),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
        },
        body: body,
      );

      // Google Forms usually returns 200 or 302 on success
      if (resp.statusCode >= 200 && resp.statusCode < 400) {
        ErrorHandler.showSuccess("Thanks! Your feedback has been submitted");
        _feedbackCtrl.clear();
      } else {
        debugPrint(resp.body);
        ErrorHandler.showError("Failed to submit feedback (code ${resp.statusCode}).");
      }
    } catch (e) {
      ErrorHandler.showError("Error submitting feedback: $e");
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            const Color(0xFF1A1A2E), // Midnight Void
            const Color(0xFF16213E).withValues(alpha: 0.95),
          ]
        : [const Color(0xFFF5F7FA), const Color(0xFFC3CFE2)]; // Premium Light

    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF1A1A2E).withValues(alpha: 0.7);

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
            "Feedback",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20.sp),
            onPressed: () => Navigator.pop(context),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Help me improve Money Control",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Share bugs, feature requests, or general feedback. "
                    "This goes straight to my inbox via Google Forms.",
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      color: secondaryTextColor,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 30.h),

                  // Name
                  _buildGlassTextField(
                    controller: _nameCtrl,
                    hint: "Name",
                    isDark: isDark,
                    icon: Icons.person_outline,
                    textColor: textColor,
                    hintColor: secondaryTextColor,
                  ),
                  SizedBox(height: 20.h),

                  // Feedback
                  _buildGlassTextField(
                    controller: _feedbackCtrl,
                    hint: "Your feedback",
                    isDark: isDark,
                    icon: Icons.chat_bubble_outline,
                    maxLines: 5,
                    textColor: textColor,
                    hintColor: secondaryTextColor,
                  ),
                  SizedBox(height: 30.h),

                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25.r),
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF6C63FF),
                                  const Color(0xFF4834D4),
                                ]
                              : [
                                  const Color(
                                    0xFF6C63FF,
                                  ).withValues(alpha: 0.8),
                                  const Color(
                                    0xFF4834D4,
                                  ).withValues(alpha: 0.8),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6C63FF,
                            ).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.r),
                          ),
                        ),
                        child: _submitting
                            ? SizedBox(
                                width: 22.w,
                                height: 22.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                "Submit Feedback",
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required IconData icon,
    required Color textColor,
    required Color hintColor,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: textColor, fontSize: 15.sp),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: hintColor.withValues(alpha: 0.5)),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            child: Icon(icon, color: hintColor, size: 22.sp),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
          alignLabelWithHint: true,
        ),
        validator: (v) =>
            v == null || v.trim().isEmpty ? "$hint is required" : null,
      ),
    );
  }
}
