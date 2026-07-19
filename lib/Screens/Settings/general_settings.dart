import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Screens/budget.dart';
import 'package:money_control/Screens/category_management.dart';
import 'package:money_control/Screens/notification_history.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/main.dart'; // For ThemeController
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/settings_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_control/Utils/responsive.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  bool _autoImport = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoImport = prefs.getBool('sms_auto_import_enabled') == true;
    });
  }

  Future<void> _toggleAutoImport(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_auto_import_enabled', val);
    if (!mounted) return;
    setState(() => _autoImport = val);
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
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : AppColors.lightTextPrimary),
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
                constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
                child: Column(
                  children: [
                SectionHeader("Preferences"),
                _buildCurrencyTile(context),
                SettingsTile(
                  icon: Icons.category_outlined,
                  title: "Manage Categories",
                  onTap: () => Get.to(() => const CategoryManagementScreen()),
                ),
                SettingsTile(
                  icon: Icons.monetization_on_outlined,
                  title: "Set Budget",
                  onTap: () => Get.to(() => const CategoryBudgetScreen()),
                ),
                SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: "Notifications",
                  onTap: () {
                    Get.to(() => const NotificationHistoryScreen());
                  },
                ),

                SectionDivider(),

                SectionHeader("Automation"),
                SettingsTile(
                  icon: Icons.smart_toy_outlined,
                  title: "Auto-Import SMS",
                  trailing: Switch(
                    value: _autoImport,
                    activeThumbColor: const Color(0xFF00E5FF),
                    onChanged: _toggleAutoImport,
                  ),
                ),

                SectionDivider(),

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
                      activeThumbColor: const Color(0xFF00E5FF),
                      onChanged: (val) {
                        themeController.setTheme(val);
                      },
                    ),
                  );
                }),
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
    return Obx(() => SettingsTile(
      icon: Icons.currency_exchange,
      title: "Currency (${CurrencyController.to.currencyCode.value})",
      onTap: () {
        _showCurrencyDialog(context);
      },
    ));
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
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
                    style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
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
