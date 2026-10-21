// Canonical list of user-facing features an admin can globally control from
// the admin Feature Flags screen. Single source of truth for feature keys,
// copy and icons used by FeatureFlagService, every gate, and the admin UI.
library;

import 'package:flutter/material.dart';

class FeatureStatus {
  FeatureStatus._();

  static const String enabled = 'enabled';
  static const String comingSoon = 'comingSoon';
  static const String hidden = 'hidden';
}

class FeatureFlagGroup {
  final String title;
  final IconData icon;
  final List<String> keys;

  const FeatureFlagGroup({
    required this.title,
    required this.icon,
    required this.keys,
  });
}

class FeatureFlag {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final bool critical;

  const FeatureFlag({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    this.critical = false,
  });

  static FeatureFlag? find(String key) {
    for (final flag in all) {
      if (flag.key == key) return flag;
    }
    return null;
  }

  /// Every flaggable feature. Default status (when the config doc or key is
  /// missing) is [FeatureStatus.enabled] — a stale/corrupt config never locks
  /// users out. Add new features here, then wire their gates.
  static const List<FeatureFlag> all = [
    FeatureFlag(
      key: 'transactions',
      title: 'Transactions',
      description: 'Add, Send and Receive money',
      icon: Icons.swap_horiz_rounded,
      critical: true,
    ),
    FeatureFlag(
      key: 'transaction_search',
      title: 'Transaction Search',
      description: 'Search across all transactions',
      icon: Icons.search_rounded,
    ),
    FeatureFlag(
      key: 'upi_pay',
      title: 'UPI Payments',
      description: 'Pay via UPI apps',
      icon: Icons.currency_rupee_rounded,
    ),
    FeatureFlag(
      key: 'qr_scan',
      title: 'Scan & Pay',
      description: 'QR scanner shortcut',
      icon: Icons.qr_code_scanner_rounded,
    ),
    FeatureFlag(
      key: 'budget',
      title: 'Budgeting',
      description: 'Overall and per-category budgets',
      icon: Icons.savings_outlined,
    ),
    FeatureFlag(
      key: 'category',
      title: 'Manage Categories',
      description: 'Custom transaction categories',
      icon: Icons.category_outlined,
    ),
    FeatureFlag(
      key: 'lent_money',
      title: 'Lent Money Tracker',
      description: 'Track money lent to friends',
      icon: Icons.handshake_outlined,
    ),
    FeatureFlag(
      key: 'recurring',
      title: 'Recurring Payments',
      description: 'Manage subscriptions and recurring bills',
      icon: Icons.event_repeat,
    ),
    FeatureFlag(
      key: 'goals',
      title: 'Goals',
      description: 'Save towards personal goals',
      icon: Icons.flag_outlined,
    ),
    FeatureFlag(
      key: 'challenges',
      title: 'Savings Challenges',
      description: 'Gamified savings challenges',
      icon: Icons.emoji_events_outlined,
    ),
    FeatureFlag(
      key: 'forecast',
      title: 'Forecast',
      description: 'Projected balance for the month',
      icon: Icons.trending_up_rounded,
    ),
    FeatureFlag(
      key: 'analytics',
      title: 'Analytics & Reports',
      description: 'Spending analytics dashboard',
      icon: Icons.pie_chart_outline_rounded,
    ),
    FeatureFlag(
      key: 'analytics_advanced',
      title: 'Advanced Analytics',
      description: 'Period and date-range analysis',
      icon: Icons.date_range_rounded,
    ),
    FeatureFlag(
      key: 'data_filters',
      title: 'Data Filters',
      description: 'Period and category filters on the analytics screen',
      icon: Icons.filter_alt_rounded,
    ),
    FeatureFlag(
      key: 'financial_summary',
      title: 'Financial Summary',
      description: 'Income, expense and net balance summary cards',
      icon: Icons.summarize_rounded,
    ),
    FeatureFlag(
      key: 'quick_overview',
      title: 'Quick Overview',
      description: 'Progress-style quick overview card on analytics',
      icon: Icons.space_dashboard_rounded,
    ),
    FeatureFlag(
      key: 'current_period',
      title: 'Current Period',
      description: 'Monthly/current-period trend chart on analytics',
      icon: Icons.show_chart_rounded,
    ),
    FeatureFlag(
      key: 'expense_breakdown',
      title: 'Expense Breakdown',
      description: 'Per-category expense pie chart on analytics',
      icon: Icons.pie_chart_rounded,
    ),
    FeatureFlag(
      key: 'spending_heatmap',
      title: 'Spending Heatmap',
      description: 'Daily spending heatmap grid on analytics',
      icon: Icons.calendar_view_month_rounded,
    ),
    FeatureFlag(
      key: 'top_merchants',
      title: 'Top Merchants',
      description: 'Top merchants card on analytics',
      icon: Icons.storefront_outlined,
    ),
    FeatureFlag(
      key: 'salary_detected',
      title: 'Salary Detected',
      description: 'Salary detection card on analytics',
      icon: Icons.attach_money_rounded,
    ),
    FeatureFlag(
      key: 'spending_personality',
      title: 'Spending Personality',
      description: 'Spending personality card on analytics',
      icon: Icons.psychology_outlined,
    ),
    FeatureFlag(
      key: 'export_csv',
      title: 'Export CSV',
      description: 'Download transactions as CSV',
      icon: Icons.table_chart_outlined,
    ),
    FeatureFlag(
      key: 'export_pdf',
      title: 'Export PDF',
      description: 'Download transactions and tax summary as PDF',
      icon: Icons.picture_as_pdf_outlined,
    ),
    FeatureFlag(
      key: 'share_report',
      title: 'Share Report',
      description: 'Share an interactive spending report',
      icon: Icons.share_outlined,
    ),
    FeatureFlag(
      key: 'ai_insights',
      title: 'AI Insights',
      description: 'Personalized tips from your spending',
      icon: Icons.auto_awesome_outlined,
    ),
    FeatureFlag(
      key: 'ai_monthly_forecast',
      title: 'This Month Forecast (AI)',
      description: 'Projected spending card inside AI Insights',
      icon: Icons.query_stats_rounded,
    ),
    FeatureFlag(
      key: 'ai_daily_limit',
      title: 'Smart Daily Limit',
      description: 'Disposable daily spending limit card inside AI Insights',
      icon: Icons.speed_rounded,
    ),
    FeatureFlag(
      key: 'monthly_heatmap',
      title: 'Monthly Spend Heatmap',
      description: 'Calendar heatmap of daily spending inside AI Insights',
      icon: Icons.calendar_month_rounded,
    ),
    FeatureFlag(
      key: 'category_insights',
      title: 'Category Insights',
      description: 'Per-category spending breakdown inside AI Insights',
      icon: Icons.donut_small_rounded,
    ),
    FeatureFlag(
      key: 'wealth',
      title: 'Wealth Builder',
      description: 'Track assets and build a portfolio',
      icon: Icons.monetization_on_outlined,
    ),
    FeatureFlag(
      key: 'custom_mode',
      title: 'Custom Mode',
      description: 'Smart/Custom mode switch on the Wealth Builder banner',
      icon: Icons.tune_rounded,
    ),
    FeatureFlag(
      key: 'total_net_worth',
      title: 'Total Net Worth',
      description: 'Net worth card on the Wealth Builder screen',
      icon: Icons.account_balance_wallet_outlined,
    ),
    FeatureFlag(
      key: 'wealth_assets',
      title: 'Your Assets',
      description: 'Asset cards on the Wealth Builder screen',
      icon: Icons.grid_view_rounded,
    ),
    FeatureFlag(
      key: 'allocation',
      title: 'Allocation',
      description: 'Asset allocation pie chart on Wealth Builder',
      icon: Icons.pie_chart_outline_rounded,
    ),
    FeatureFlag(
      key: 'ideal_income',
      title: 'Ideal Income',
      description: 'Ideal income card on Wealth Builder',
      icon: Icons.payments_outlined,
    ),
    FeatureFlag(
      key: 'smart_suggestions',
      title: 'Smart Suggestions',
      description: 'Smart suggestions card on Wealth Builder',
      icon: Icons.tips_and_updates_outlined,
    ),
    FeatureFlag(
      key: 'loan_tracker',
      title: 'Loan Tracker',
      description: 'Track loans and payments',
      icon: Icons.account_balance_outlined,
    ),
    FeatureFlag(
      key: 'sms_tracking',
      title: 'SMS Tracking',
      description: 'Auto-import transactions from SMS',
      icon: Icons.sms_outlined,
    ),
    FeatureFlag(
      key: 'sms_import',
      title: 'Import from SMS',
      description: 'Import transactions from SMS in Transaction History',
      icon: Icons.sms_rounded,
    ),
    FeatureFlag(
      key: 'sms_auto_import',
      title: 'SMS Auto-Import',
      description: 'Background import of bank SMS into transactions',
      icon: Icons.smart_toy_outlined,
    ),
    FeatureFlag(
      key: 'expense_reminder',
      title: 'Expense Reminder',
      description: 'Nudge when no expenses are added for a while',
      icon: Icons.alarm_on_outlined,
    ),
    FeatureFlag(
      key: 'lite_mode',
      title: 'Lite Mode',
      description: 'Reduces animations for performance on low-end devices',
      icon: Icons.bolt_outlined,
    ),
    FeatureFlag(
      key: 'biometric_app_lock',
      title: 'Biometric App Lock',
      description: 'Fingerprint or face unlock on launch',
      icon: Icons.fingerprint,
    ),
    FeatureFlag(
      key: 'privacy_mode',
      title: 'Privacy Mode',
      description: 'Blur amounts and balances at a tap',
      icon: Icons.visibility_off_outlined,
    ),
    FeatureFlag(
      key: 'restore_data',
      title: 'Restore Data',
      description: 'Restore transactions from the local backup',
      icon: Icons.restore_outlined,
    ),
    FeatureFlag(
      key: 'import_data',
      title: 'Import Data',
      description: 'Import transactions from a CSV file',
      icon: Icons.upload_file,
    ),
    FeatureFlag(
      key: 'export_all_data',
      title: 'Export All Data',
      description: 'Download a full GDPR export of your data',
      icon: Icons.cloud_download_outlined,
    ),
    FeatureFlag(
      key: 'full_backup',
      title: 'Backup & Restore All Data',
      description:
          'Download a complete archive of every collection and restore it later',
      icon: Icons.save_alt_outlined,
    ),
    FeatureFlag(
      key: 'transaction_audit',
      title: 'Transaction Audit',
      description: 'Cross-check transactions against your bank records',
      icon: Icons.fact_check_outlined,
    ),
    FeatureFlag(
      key: 'sms_rules',
      title: 'Auto-tag Rules',
      description: 'Rules for categorizing SMS transactions',
      icon: Icons.rule_outlined,
    ),
    FeatureFlag(
      key: 'invite',
      title: 'Invite Friends',
      description: 'Refer friends to the app',
      icon: Icons.person_add_alt_1_rounded,
    ),
    FeatureFlag(
      key: 'profile',
      title: 'Edit Profile',
      description: 'Update name, age and profile details',
      icon: Icons.badge_outlined,
    ),
    FeatureFlag(
      key: 'notifications',
      title: 'Notifications',
      description: 'Reminders and smart alerts',
      icon: Icons.notifications_outlined,
    ),
    FeatureFlag(
      key: 'home_widget',
      title: 'Home Widget',
      description: 'Quick balance widget for the launcher',
      icon: Icons.widgets_outlined,
    ),
    FeatureFlag(
      key: 'update_checker',
      title: 'In-app Updates',
      description: 'Check and install app updates',
      icon: Icons.system_update_alt_rounded,
    ),
  ];

  /// Groups flags by the screen/place their gate lives, in the order shown on
  /// the admin Feature Flags screen. Organized to keep related toggles together;
  /// every key in [all] must appear in exactly one group (test-enforced).
  static const List<FeatureFlagGroup> groups = [
    FeatureFlagGroup(
      title: 'Home & Transactions',
      icon: Icons.home_rounded,
      keys: [
        'transactions',
        'transaction_search',
        'upi_pay',
        'qr_scan',
        'forecast',
      ],
    ),
    FeatureFlagGroup(
      title: 'Lending & Subscriptions',
      icon: Icons.handshake_rounded,
      keys: ['lent_money', 'recurring'],
    ),
    FeatureFlagGroup(
      title: 'Budget, Goals & Loans',
      icon: Icons.savings_outlined,
      keys: ['budget', 'category', 'goals', 'challenges', 'loan_tracker'],
    ),
    FeatureFlagGroup(
      title: 'Analytics Dashboard',
      icon: Icons.pie_chart_outline_rounded,
      keys: [
        'analytics',
        'analytics_advanced',
        'data_filters',
        'financial_summary',
        'quick_overview',
        'current_period',
        'expense_breakdown',
        'spending_heatmap',
        'top_merchants',
        'salary_detected',
        'spending_personality',
        'export_csv',
        'export_pdf',
        'share_report',
      ],
    ),
    FeatureFlagGroup(
      title: 'AI Tools',
      icon: Icons.auto_awesome_rounded,
      keys: [
        'ai_insights',
        'ai_monthly_forecast',
        'ai_daily_limit',
        'monthly_heatmap',
        'category_insights',
      ],
    ),
    FeatureFlagGroup(
      title: 'Wealth & Assets',
      icon: Icons.monetization_on_outlined,
      keys: [
        'wealth',
        'custom_mode',
        'total_net_worth',
        'wealth_assets',
        'allocation',
        'ideal_income',
        'smart_suggestions',
      ],
    ),
    FeatureFlagGroup(
      title: 'Automation & Reminders',
      icon: Icons.smart_toy_outlined,
      keys: [
        'sms_tracking',
        'sms_import',
        'sms_auto_import',
        'sms_rules',
        'expense_reminder',
      ],
    ),
    FeatureFlagGroup(
      title: 'Privacy & Security',
      icon: Icons.security_rounded,
      keys: [
        'biometric_app_lock',
        'privacy_mode',
        'lite_mode',
        'transaction_audit',
      ],
    ),
    FeatureFlagGroup(
      title: 'Data Management',
      icon: Icons.folder_open_rounded,
      keys: ['full_backup', 'restore_data', 'import_data', 'export_all_data'],
    ),
    FeatureFlagGroup(
      title: 'Settings & Extras',
      icon: Icons.settings_rounded,
      keys: [
        'invite',
        'profile',
        'notifications',
        'home_widget',
        'update_checker',
      ],
    ),
  ];
}
