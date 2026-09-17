import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Screens/budget.dart';
import 'package:money_control/Screens/category_management.dart';
import 'package:money_control/Screens/home_widget_preview.dart';
import 'package:money_control/Screens/notification_settings.dart';
import 'package:money_control/Services/background_worker.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Services/sms_service.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/main.dart'; // For ThemeController
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Components/settings_widgets.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/Services/feature_flag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_control/Utils/responsive.dart';

/// "mm:ss", or "h:mm:ss" past an hour. Clamps negatives to 00:00.
String formatCountdown(Duration remaining) {
  final total = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$mm:$ss';
}

Future<String?> _resolveSmsUserEmail(SharedPreferences prefs) async {
  var email = prefs.getString('user_email');
  if (email == null || email.isEmpty) {
    try {
      email = FirebaseAuth.instance.currentUser?.email;
    } catch (_) {}
  }
  return email;
}

/// Live "next auto-import" estimate shown under the Auto-Import SMS tile.
/// Self-contained: tick rebuilds only this line, not the whole screen.
class _NextSmsAutoImportCountdown extends StatefulWidget {
  const _NextSmsAutoImportCountdown();

  @override
  State<_NextSmsAutoImportCountdown> createState() =>
      _NextSmsAutoImportCountdownState();
}

class _NextSmsAutoImportCountdownState
    extends State<_NextSmsAutoImportCountdown> {
  Timer? _timer;
  final _text = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(SmsService.autoImportEnabledKey) == true;
    final email = await _resolveSmsUserEmail(prefs);
    String text;
    if (!enabled) {
      text = 'Auto-Import is off — SMS will not be imported automatically';
    } else {
      final watermarkMs =
          prefs.getInt(SmsService.autoImportWatermarkKey(email ?? '')) ?? 0;
      final estimate = nextSmsAutoImportEstimate(lastScanMs: watermarkMs);
      if (estimate == null) {
        text = 'Waiting for the first scan…';
      } else {
        final remaining = estimate.difference(DateTime.now());
        if (remaining.inSeconds <= 0) {
          text = 'Next auto-import ≈ 00:00 — due any moment';
        } else {
          text = 'Next auto-import ≈ ${formatCountdown(remaining)}';
        }
      }
    }
    if (_text.value != text) _text.value = text;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(left: 88.w, right: 16.w, top: 4.h),
      child: ValueListenableBuilder<String>(
        valueListenable: _text,
        builder: (_, text, __) => Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
            fontSize: 12.sp,
          ),
        ),
      ),
    );
  }
}

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  bool _autoImport = false;
  bool _expenseReminder = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoImport =
          prefs.getBool(SmsService.autoImportEnabledKey) == true;
      _expenseReminder = prefs.getBool(transactionReminderEnabledKey) ?? true;
    });
  }

  Future<void> _toggleAutoImport(bool val) async {
    await SmsService.setAutoImportEnabled(val);
    if (!mounted) return;
    setState(() => _autoImport = val);
  }

  Future<void> _toggleExpenseReminder(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(transactionReminderEnabledKey, val);
    if (!mounted) return;
    setState(() => _expenseReminder = val);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("General"),
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
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
                    SectionHeader("Preferences"),
                    _buildCurrencyTile(context),
                    FeatureVisible(
                      flagKey: 'category',
                      child: SettingsTile(
                        icon: Icons.category_outlined,
                        title: AppStrings.manageCategories,
                        onTap: () {
                          if (!ensureFeatureVisible(context, 'category'))
                            return;
                          Get.to(() => const CategoryManagementScreen());
                        },
                      ),
                    ),
                    FeatureVisible(
                      flagKey: 'budget',
                      child: SettingsTile(
                        icon: Icons.monetization_on_outlined,
                        title: AppStrings.setBudget,
                        onTap: () {
                          if (!ensureFeatureVisible(context, 'budget')) return;
                          Get.to(() => const CategoryBudgetScreen());
                        },
                      ),
                    ),
                    FeatureVisible(
                      flagKey: 'notifications',
                      child: SettingsTile(
                        icon: Icons.notifications_none_rounded,
                        title: "Notifications",
                        onTap: () {
                          if (!ensureFeatureVisible(context, 'notifications'))
                            return;
                          Get.to(() => const NotificationSettingsScreen());
                        },
                      ),
                    ),

                    SectionDivider(),

                    FeatureSection(
                      flagKeys: ['sms_auto_import', 'expense_reminder'],
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SectionHeader("Automation"),
                          FeatureVisible(
                            flagKey: 'sms_auto_import',
                            child: Obx(
                              () => Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SettingsTile(
                                    icon: Icons.smart_toy_outlined,
                                    title: "Auto-Import SMS",
                                    trailing: Switch(
                                      value: _autoImport,
                                      activeThumbColor: AppColors.primary,
                                      onChanged:
                                          FeatureFlagService.to.visibleToMe(
                                            'sms_auto_import',
                                          )
                                          ? _toggleAutoImport
                                          : null,
                                    ),
                                  ),
                                  const _NextSmsAutoImportCountdown(),
                                ],
                              ),
                            ),
                          ),
                          FeatureVisible(
                            flagKey: 'expense_reminder',
                            child: Obx(
                              () => SettingsTile(
                                icon: Icons.alarm_on_outlined,
                                title: "Expense Reminder",
                                subtitle:
                                    "Nudge me when no expenses are added for a while",
                                trailing: Switch(
                                  value: _expenseReminder,
                                  activeThumbColor: AppColors.primary,
                                  onChanged:
                                      FeatureFlagService.to.visibleToMe(
                                        'expense_reminder',
                                      )
                                      ? _toggleExpenseReminder
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SectionDivider(),
                        ],
                      ),
                    ),

                    SectionHeader("Appearance"),
                    Obx(() {
                      final bool isDarkMode =
                          themeController.themeMode == ThemeMode.dark;
                      return SettingsTile(
                        icon: isDarkMode
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        title: "Dark Mode",
                        trailing: Switch(
                          value: isDarkMode,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) {
                            themeController.setTheme(val);
                          },
                        ),
                      );
                    }),
                    FeatureVisible(
                      flagKey: 'lite_mode',
                      child: Obx(() {
                        final perf = PerformanceController.to;
                        final manual = perf.userOverridden.value;
                        return SettingsTile(
                          icon: Icons.bolt_outlined,
                          title: "Lite Mode",
                          subtitle: manual
                              ? "Manual override active — tap here to restore auto detection"
                              : "Improves performance on low-end devices by "
                                    "reducing animations and visual effects",
                          onTap: manual ? perf.resetToAuto : null,
                          trailing: Switch(
                            value: perf.liteMode.value,
                            activeThumbColor: AppColors.primary,
                            onChanged:
                                FeatureFlagService.to.visibleToMe('lite_mode')
                                ? (val) {
                                    if (val) {
                                      perf.setLiteMode(true);
                                    } else {
                                      perf.setLiteMode(false);
                                    }
                                  }
                                : null,
                          ),
                        );
                      }),
                    ),

                    const SectionDivider(),

                    SectionHeader("Home Widget"),
                    FeatureVisible(
                      flagKey: 'home_widget',
                      child: SettingsTile(
                        icon: Icons.widgets_outlined,
                        title: "Home Widget",
                        subtitle: "Preview & setup the balance widget",
                        onTap: () {
                          if (!ensureFeatureVisible(context, 'home_widget'))
                            return;
                          Get.to(() => const HomeWidgetPreviewScreen());
                        },
                      ),
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

  Widget _buildCurrencyTile(BuildContext context) {
    return Obx(
      () => SettingsTile(
        icon: Icons.currency_exchange,
        title: "Currency (${CurrencyController.to.currencyCode.value})",
        onTap: () {
          _showCurrencyDialog(context);
        },
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Map<String, String>> currencies = [
      {'code': 'INR', 'symbol': '₹'},
      {'code': 'USD', 'symbol': '\$'},
      {'code': 'EUR', 'symbol': '€'},
      {'code': 'GBP', 'symbol': '£'},
      {'code': 'JPY', 'symbol': '¥'},
    ];

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Currency",
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16.h),
              ...currencies.map(
                (c) => ListTile(
                  title: Text(
                    "${c['code']} (${c['symbol']})",
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  onTap: () {
                    CurrencyController.to.setCurrency(c['code']!, c['symbol']!);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
