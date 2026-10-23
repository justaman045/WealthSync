import 'package:money_control/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/settings_widgets.dart';
import 'package:money_control/Screens/notification_history.dart';
import 'package:money_control/Services/notification_service.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central control for every WealthSync notification: a master toggle plus one
/// per-channel toggle. Mirrors what the enforce-at-post-time choke points in
/// [NotificationService] and the background worker read, so a toggle flipped
/// here takes effect on the next notification.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const List<({String channelId, String label, IconData icon})>
  _channels = [
    (
      channelId: 'reminder_channel',
      label: 'Reminders',
      icon: Icons.alarm_on_outlined,
    ),
    (
      channelId: 'insight_channel',
      label: 'Daily Insights',
      icon: Icons.insights_rounded,
    ),
    (
      channelId: 'weekly_digest_channel',
      label: 'Weekly Digest',
      icon: Icons.calendar_view_week_outlined,
    ),
    (
      channelId: 'update_channel',
      label: 'Update Alerts',
      icon: Icons.system_update_rounded,
    ),
    (
      channelId: 'recurring_pending_channel',
      label: 'Recurring Payments',
      icon: Icons.event_repeat_rounded,
    ),
    (
      channelId: 'sms_import_channel',
      label: 'SMS Auto-Import',
      icon: Icons.smart_toy_outlined,
    ),
    (
      channelId: 'budget_alerts',
      label: 'Budget Alerts',
      icon: Icons.warning_amber_rounded,
    ),
    (
      channelId: 'general_notifications',
      label: 'Subscription & General',
      icon: Icons.workspace_premium_outlined,
    ),
  ];

  bool _master = true;
  final Set<String> _disabledChannels = <String>{};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final disabled = <String>{};
    for (final channel in _channels) {
      if (!(prefs.getBool(notificationChannelEnabledKey(channel.channelId)) ??
          true)) {
        disabled.add(channel.channelId);
      }
    }
    if (!mounted) return;
    setState(() {
      _master = prefs.getBool(notificationsMasterEnabledKey) ?? true;
      _disabledChannels
        ..clear()
        ..addAll(disabled);
    });
  }

  Future<void> _toggleMaster(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationsMasterEnabledKey, val);
    if (!mounted) return;
    setState(() => _master = val);
  }

  Future<void> _toggleChannel(String channelId, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationChannelEnabledKey(channelId), val);
    if (!mounted) return;
    setState(() {
      if (val) {
        _disabledChannels.remove(channelId);
      } else {
        _disabledChannels.add(channelId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.notifications),
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
        titleTextStyle: AppType.titleMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
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
                    const SectionHeader("Preferences"),
                    SettingsTile(
                      icon: _master
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      title: "All Notifications",
                      subtitle: _master
                          ? "Notifications are enabled"
                          : "Temporarily mute everything",
                      iconColor: _master
                          ? AppColors.primary
                          : AppColors.warning,
                      trailing: Switch(
                        value: _master,
                        activeThumbColor: AppColors.primary,
                        onChanged: _toggleMaster,
                      ),
                    ),
                    if (!_master)
                      Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.warning,
                              size: 20.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.masterToggleOffNothingPosted,
                                style: AppType.bodySmall(isDark
                                      ? Colors.white70
                                      : AppColors.lightTextPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SectionDivider(),

                    const SectionHeader("Channels"),
                    for (final channel in _channels)
                      SettingsTile(
                        icon: channel.icon,
                        title: channel.label,
                        trailing: Switch(
                          value: !_disabledChannels.contains(channel.channelId),
                          activeThumbColor: AppColors.primary,
                          onChanged: _master
                              ? (val) => _toggleChannel(channel.channelId, val)
                              : null,
                        ),
                      ),

                    const SectionDivider(),

                    const SectionHeader("History"),
                    SettingsTile(
                      icon: Icons.history_rounded,
                      title: "Notification History",
                      subtitle: "See past notifications",
                      onTap: () =>
                          Get.to(() => const NotificationHistoryScreen()),
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
}
