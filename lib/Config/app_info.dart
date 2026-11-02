/// Static product facts shown on the About screen.
///
/// The About screen used to describe the app with a hardcoded paragraph and a
/// hand-written acknowledgement list, so neither could be asserted: a stale
/// claim ("24 asset types") or a dropped dependency credit was invisible. These
/// lists are the source of truth the screen renders and `about_content_test`
/// checks.
library;

class AppFeature {
  const AppFeature({required this.title, required this.description});

  final String title;
  final String description;
}

class AppInfo {
  AppInfo._();

  static const String name = 'WealthSync';
  static const String tagline = 'Your Pocket CFO';

  static const String summary =
      'Track expenses, budgets, goals and your whole portfolio in one place, '
      'with on-device SMS import on Pro and an encrypted local backup.';

  static const String privacyPolicyUrl =
      'https://justaman045.github.io/WealthSync/privacy_policy.html';

  // Section/tile labels live here too, so the About screen has one source of
  // copy and the legal deep links cannot drift from the section names.
  static const String developerLabel = 'Developer';
  static const String featuresLabel = 'Features';
  static const String acknowledgementsLabel = 'Acknowledgements';
  static const String legalAndDataLabel = 'Legal & Data';
  static const String termsOfService = 'Terms of Service';
  static const String privacyPolicy = 'Privacy Policy';
  static const String dataAndConsents = 'Data & Consents';
  static const String poweredBy = 'Powered by open-source technologies:';

  /// What the app actually does today. Keep this to shipped behaviour: every
  /// line is a promise on a store listing.
  static const List<AppFeature> features = <AppFeature>[
    AppFeature(
      title: 'Dashboard',
      description:
          'Monthly balance, spending trend and quick insights on one screen.',
    ),
    AppFeature(
      title: 'Transactions',
      description:
          'Income and expenses with custom categories, notes and attachments.',
    ),
    AppFeature(
      title: 'Budgets',
      description: 'Monthly budgets with alerts when a category runs hot.',
    ),
    AppFeature(
      title: 'Savings goals',
      description: 'Set a target, track progress and keep a savings streak.',
    ),
    AppFeature(
      title: 'Wealth portfolio',
      description:
          'Stocks, mutual funds, property, gold, PF and more in one net worth.',
    ),
    AppFeature(
      title: 'Recurring payments',
      description: 'Subscriptions and EMIs, with an optional auto-pay entry.',
    ),
    AppFeature(
      title: 'Lent money',
      description:
          'Track money lent to (or borrowed from) friends, including top-ups and repayments.',
    ),
    AppFeature(
      title: 'Offline first',
      description:
          'Works without a connection; on-device backups are encrypted with a key in secure storage.',
    ),
    AppFeature(
      title: 'SMS import (Pro)',
      description:
          'Bank messages are parsed on the device — the SMS body never leaves the phone.',
    ),
  ];

  /// Third-party work the app depends on. Credit is not optional for some of
  /// these licences, so this list is asserted by a test.
  static const List<String> acknowledgements = <String>[
    'Flutter Framework',
    'Firebase Authentication & Firestore',
    'GetX – State Management & Routing',
    'flutter_screenutil – Responsive UI',
    'fl_chart – Charts',
    'package_info_plus',
    'share_plus, printing, and more',
  ];
}
