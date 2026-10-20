import 'package:money_control/l10n/app_localizations.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/referral_service.dart';
import 'package:money_control/Utils/num_parse.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full invite experience: reward banner, referral code (copy + share) and a
/// live tally of friends referred. Opened from the Invite Friends card in
/// Settings.
class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  String _code = '';
  int _count = 0;
  bool _loading = true;
  bool _sharing = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribeToStats();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await ReferralService.ensureReferralCode();
    // Guard against a post-await dispose: otherwise the listener is created
    // after dispose() and leaks (never cancelled).
    if (!mounted) return;
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            final data = snap.data() ?? {};
            setState(() {
              _code = (data['referralCode'] as String?) ?? '';
              _count = safeToInt(data['referralCount']);
              _loading = false;
            });
          },
          onError: (e) {
            debugPrint('InviteFriends stream error: $e');
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  Future<void> _copyCode() async {
    if (_code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.codeCopied),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _share() async {
    if (_code.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      final text = await ReferralService.buildInviteShareText(_code);
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(text: text));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareWhatsApp() async {
    if (_code.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      final text = await ReferralService.buildInviteShareText(_code);
      if (!mounted) return;
      final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.couldOpenWhatsApp),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.inviteFriends),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18.sp,
        ),
      ),
      body: Container(
        height: double.infinity,
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.contentMaxWidth(context),
                ),
                child: Column(
                  children: [
                    _buildRewardBanner(),
                    SizedBox(height: 20.h),
                    _buildCodeCard(),
                    SizedBox(height: 16.h),
                    _buildProgressCard(),
                    SizedBox(height: 20.h),
                    _buildActionButton(
                      icon: Icons.share_rounded,
                      label: _sharing ? "Opening..." : "Share Invite",
                      filled: true,
                      onTap: _sharing ? null : _share,
                    ),
                    SizedBox(height: 12.h),
                    _buildActionButton(
                      icon: Icons.chat_rounded,
                      label: _sharing ? "Opening..." : "Share via WhatsApp",
                      filled: false,
                      onTap: _sharing ? null : _shareWhatsApp,
                    ),
                    SizedBox(height: 12.h),
                    _buildActionButton(
                      icon: Icons.copy_rounded,
                      label: "Copy Code",
                      filled: false,
                      onTap: _code.isEmpty ? null : _copyCode,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 28.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.inviteFriendsGetProFree,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.whenFriendSignsUpCode,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13.sp,
              height: 1.4,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            isDark ? "No limit — keep stacking!" : "No limit — keep stacking!",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.lightBorder.withValues(alpha: 0.05),
        ),
      ),
      child: _loading
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.referralCODE,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : AppColors.lightTextSecondary,
                        fontSize: 11.sp,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _code.isEmpty ? '—' : _code,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _code.isEmpty ? null : _copyCode,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProgressCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: AppColors.success,
            size: 26.sp,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              _count == 0
                  ? "Share your code to earn your first month of Pro!"
                  : "You've referred $_count friend${_count > 1 ? 's' : ''} — "
                        "$_count month${_count > 1 ? 's' : ''} earned 🎉",
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                fontSize: 13.sp,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              icon: Icon(icon, size: 20.sp),
              label: Text(
                label,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.lightBorder,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              icon: Icon(icon, size: 20.sp),
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
            ),
    );
  }
}
