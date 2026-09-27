// Single source of truth for user-visible copy that integration tests assert
// on. RULES:
//  1. Screens must render `AppStrings.x` instead of an inline literal whenever
//     the same text is asserted in integration_test/ (directly or via helpers).
//  2. Integration tests must assert `find.text(AppStrings.x)` — never re-type
//     the literal. This makes copy changes compile-time safe on both sides.
//  3. Data-dependent literals (amounts, counts, plan prices) stay inline — they
//     are data, not copy.
//  4. When restyling a screen, move its asserted copy here in the same change.
class AppStrings {
  AppStrings._();

  // ---- Home / shell ----
  static const String totalBalance = 'Total Balance';
  static const String showAllCards = 'Show All Cards';

  // Title of the home section whose "View All" opens CategoriesHistoryScreen
  // (a per-category transaction list). It used to read "Quick Send", which is
  // the separate UPI row and never described this destination.
  static const String categoryHistoryTitle = 'Category History';
  static const String viewAll = 'View All';

  // ---- Onboarding / auth ----
  static const String getStarted = 'Get Started';
  static const String letsStart = "Let's Start";
  static const String signIn = 'Sign In';
  static const String continueLabel = 'Continue';

  // ---- Transactions ----
  static const String sendCta = 'SEND';
  static const String receiveCta = 'RECEIVE';
  static const String send = 'Send';
  static const String receive = 'Receive';
  static const String add = 'Add';
  static const String save = 'Save';

  // ---- Budget ----
  static const String budgeting = 'Budgeting';
  static const String categoryBudgets = 'Category Budgets';
  static const String setBudget = 'Set Budget';
  static const String manageCategories = 'Manage Categories';
  static const String signOut = 'Sign Out';

  // ---- Goals / features ----
  static const String goals = 'Goals';
  static const String lentMoneyTracker = 'Lent Money Tracker';
  static const String lentToFriend = 'Lent to Friend';
  static const String subscriptions = 'Subscriptions';

  // ---- Subscription / Pro ----
  static const String upgradeToPro = 'Upgrade to Pro';
  static const String monthly = 'Monthly';
  static const String yearly = 'Yearly';
  static const String youAreAProMember = 'You are a Pro Member!';
  static const String renewsOn = 'Renews on:';

  // ---- Analytics (data-dependent titles) ----
  static const String monthlyTrend = 'Monthly Trend';
  static const String currentPeriod = 'Current Period';
  static const String expenseBreakdown = 'Expense Breakdown';

  // ---- Admin feature flags ----
  static const String featureFlags = 'Feature Flags';
  static const String featureFlagsSubtitle =
      'Globally enable, mark as coming soon, or hide features for every user.';
  static const String statusEnabled = 'Enabled';
  static const String statusComingSoon = 'Coming Soon';
  static const String statusHidden = 'Hidden';
  static const String statusEnabledHint =
      'Available to everyone, including free users.';
  static const String statusComingSoonHint =
      'Customers see \'Coming Soon\'; admins can still use it.';
  static const String statusHiddenHint =
      'Removed for everyone, including admins. Toggle back anytime.';
  static const String criticalFeatureTitle =
      'This is a core feature';
  static const String criticalFeatureWarning =
      'Disabling a core feature affects the main experience. Only admins can '
      'bring it back here.';
  static const String disableCriticalConfirm = 'Disable anyway';

  // ---- Coming Soon placeholder ----
  static const String comingSoonTitle = 'Coming Soon';
  static const String comingSoonBody =
      'We\'re working on this feature and it will be available soon.';
  static const String comingSoonFollow =
      'Check back later for updates — you\'ll be the first to know when it\'s live.';
}
