// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcomeBack => 'Welcome back,';

  @override
  String get home => 'Home';

  @override
  String get transactions => 'Transactions';

  @override
  String get settings => 'Settings';

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get noTransactions => 'No Transactions';

  @override
  String get noTransactionsSubtitle =>
      'You haven\'t made any transactions yet.';

  @override
  String get sendMoney => 'Send Money';

  @override
  String get receiveMoney => 'Receive Money';

  @override
  String get amount => 'Amount';

  @override
  String get recipient => 'Recipient';

  @override
  String get sender => 'Sender';

  @override
  String get selectCategory => 'Select Category';

  @override
  String get note => 'Note';

  @override
  String get date => 'Date';

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get deleteCategoryTitle => 'Delete Category';

  @override
  String deleteCategoryContent(Object category) {
    return 'Do you want to delete \'$category\'?\n\n• This will NOT delete existing transactions.\n• Category will simply be removed from your list.';
  }

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get newCategory => 'New Category';

  @override
  String get categoryNameHint => 'Category Name';

  @override
  String get enterNameHint => 'Enter name';

  @override
  String get addNoteHint => 'Add a note...';

  @override
  String get selectCategoryError => 'Select a category';

  @override
  String get send => 'Send';

  @override
  String get receive => 'Receive';

  @override
  String welcomeUser(Object name) {
    return 'Welcome, $name';
  }

  @override
  String get onboardingSubtitle =>
      'Let\'s set up your financial goals in 2 steps.';

  @override
  String get onboardingReferralHint => 'e.g. AMAN05';

  @override
  String get onboardingReferralOptional => 'Referral Code (Optional)';

  @override
  String get onboardingReferralPitch =>
      'Have a friend’s code? Get 1 month free!';

  @override
  String get chooseCurrencyStep => '1. Choose Currency';

  @override
  String get setBudgetStep => '2. Set Monthly Budget';

  @override
  String get budgetProUpsell =>
      'Create budgets, track spending, and get alerts with Pro.';

  @override
  String get budgetSetLimit => 'Set Limit';

  @override
  String get budgetUpdate => 'Update';

  @override
  String get budgetHint => 'e.g. 20000';

  @override
  String get startTracking => 'Start Tracking';

  @override
  String get enterBudgetError => 'Please enter a budget';

  @override
  String get invalidNumberError => 'Invalid number';

  @override
  String get transactionHistoryTitle => 'Transaction History';

  @override
  String get importSmsTooltip => 'Import from SMS';

  @override
  String get tabAll => 'All';

  @override
  String get tabIncome => 'Income';

  @override
  String get tabOutcome => 'Outcome';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get unknownRecipient => 'Unknown';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get monthlyForecastTitle => 'Monthly Forecast';

  @override
  String get incomeSectionTitle => 'INCOME';

  @override
  String get expenseSectionTitle => 'EXPENSES';

  @override
  String get incomeSoFar => 'Income So Far';

  @override
  String get projectedRemaining => 'Projected Remaining';

  @override
  String get expensesSoFar => 'Expenses So Far';

  @override
  String get accessDenied => 'Access Denied';

  @override
  String get accessDevice => 'Access from any device';

  @override
  String get activeLoans => 'Active Loans';

  @override
  String get add2 => '+ Add';

  @override
  String get addCard => 'Add Card';

  @override
  String get addFirstGoal => 'Add your first goal';

  @override
  String get addLink => 'Add Link';

  @override
  String get addLoan => 'Add Loan';

  @override
  String get addLoanTrackEMIsSee =>
      'Add a loan to track EMIs and\\nsee your repayment schedule';

  @override
  String get addPerson => 'Add person';

  @override
  String get addPolicy => 'Add Policy';

  @override
  String get addProgress => 'Add Progress';

  @override
  String get addProperty => 'Add Property';

  @override
  String get addRule => 'Add Rule';

  @override
  String get addSubscription => 'Add Subscription';

  @override
  String get addVehicle => 'Add Vehicle';

  @override
  String get adminDashboard => 'Admin Dashboard';

  @override
  String get adminUtils => 'Admin Utils';

  @override
  String get advanceDueDateNextCycle =>
      'This will advance the due date to the next cycle without recording a payment.';

  @override
  String get alignUPIQRCodeWithin => 'Align the UPI QR code within the frame';

  @override
  String get allocation => 'Allocation';

  @override
  String get alreadyImported => 'Already Imported';

  @override
  String get analyticsAdvanced => 'Advanced Analytics';

  @override
  String get analyticsAllCategories => 'All Categories';

  @override
  String get analyticsCategory => 'Category';

  @override
  String get analyticsDataExport => 'Data Export';

  @override
  String get analyticsExpense => 'Expense';

  @override
  String get analyticsExpenses => 'Expenses';

  @override
  String get analyticsExportCsvDesc =>
      'Export your transaction history as CSV.';

  @override
  String get analyticsExportPdfDesc =>
      'Generate detailed PDF reports for analysis.';

  @override
  String get analyticsHeatmapBillDue => 'Bill/EMI due';

  @override
  String get analyticsHeatmapHighSpend => 'High spend';

  @override
  String get analyticsHeatmapLowSpend => 'Low spend';

  @override
  String get analyticsHeatmapSalary => 'Salary';

  @override
  String get analyticsIn => 'In';

  @override
  String get analyticsNetBalance => 'Net Balance';

  @override
  String get analyticsNotEnoughDataForTrend => 'Not enough data for trend.';

  @override
  String get analyticsOthers => 'Others';

  @override
  String get analyticsPeriod => 'Period';

  @override
  String get analyticsPersonalityBalanced => 'Balanced Spender';

  @override
  String get analyticsPersonalityBalancedDesc =>
      'Your spending is well-distributed across categories.';

  @override
  String get analyticsPersonalityBigSpender => 'Big Spender';

  @override
  String analyticsPersonalityBigSpenderDesc(Object amount) {
    return 'Your average transaction is over $amount — you go big.';
  }

  @override
  String get analyticsPersonalityCommuter => 'Commuter';

  @override
  String analyticsPersonalityCommuterDesc(Object pct) {
    return 'Transport accounts for $pct% of your expenses.';
  }

  @override
  String get analyticsPersonalityFoodie => 'Foodie';

  @override
  String analyticsPersonalityFoodieDesc(Object pct) {
    return 'Food & dining makes up $pct% of your spending.';
  }

  @override
  String get analyticsPersonalityFrequentSpender => 'Frequent Spender';

  @override
  String analyticsPersonalityFrequentSpenderDesc(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions in the last 30 days',
      one: '1 transaction in the last 30 days',
    );
    return '$_temp0 — always on the move.';
  }

  @override
  String get analyticsPersonalityFunSeeker => 'Fun Seeker';

  @override
  String get analyticsPersonalityFunSeekerDesc =>
      'Entertainment & leisure is your top spending category.';

  @override
  String get analyticsPersonalityJustStarting => 'Just Getting Started';

  @override
  String get analyticsPersonalityJustStartingDesc =>
      'Add more transactions to unlock your spending personality.';

  @override
  String get analyticsPersonalityShopaholic => 'Shopaholic';

  @override
  String analyticsPersonalityShopaholicDesc(Object pct) {
    return 'Shopping takes $pct% of your budget.';
  }

  @override
  String get analyticsPersonalitySmartSaver => 'Smart Saver';

  @override
  String get analyticsPersonalitySmartSaverDesc =>
      'You save over 40% of your income — great financial discipline!';

  @override
  String get analyticsShareReportDesc =>
      'Share your monthly report as an image.';

  @override
  String analyticsShareReportFileName(Object period) {
    return 'My $period Financial Report — Money Control';
  }

  @override
  String analyticsSpendingExceedsIncome(Object pct) {
    return 'Spending exceeds income by $pct%';
  }

  @override
  String get analyticsTaxSummary => 'Tax Summary';

  @override
  String get analyticsTaxSummaryDesc =>
      'Export categorized annual tax summary PDF.';

  @override
  String get analyticsThisMonth => 'This Month';

  @override
  String get analyticsThisWeek => 'This Week';

  @override
  String analyticsTransactionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get analyticsUnknownMerchant => 'Unknown';

  @override
  String get analyticsUnlockHistory =>
      'Unlock full history and custom date ranges.';

  @override
  String get analyticsReports => 'Analytics & Reports';

  @override
  String get annually => 'annually';

  @override
  String get approve => 'Approve';

  @override
  String get assetsLiabilities => 'Assets − All Liabilities';

  @override
  String get auto => 'AUTO';

  @override
  String get autoPAYMISSED => 'AUTO-PAY MISSED';

  @override
  String get autoPay => 'Auto-pay';

  @override
  String get autoTagRules => 'Auto-Tag Rules';

  @override
  String get back => 'Back';

  @override
  String get bankDataImported => 'No bank data imported';

  @override
  String get balanceAddLent => '+ Add Lent';

  @override
  String get balanceDeductDues =>
      'Deduct this month\'s dues from the total balance';

  @override
  String get balanceDuesDeducted => 'Dues Deducted';

  @override
  String balanceDuesDue(String amount) {
    return '- $amount due';
  }

  @override
  String get balanceDuesHidden => '- •••• due';

  @override
  String get balanceHidden => '••••';

  @override
  String balanceHiddenAnnouncement(String title) {
    return '$title. Hidden';
  }

  @override
  String get balanceIncludeLent => 'Include lent money in the total balance';

  @override
  String get balanceLentIncluded => 'Lent Included';

  @override
  String get balanceNoDues => '- No Dues';

  @override
  String balanceStreak(int days) {
    return '$days day streak';
  }

  @override
  String balanceTapToHide(String title) {
    return '$title. Tap to hide';
  }

  @override
  String balanceVersusLastMonth(String percent) {
    return '$percent% vs last month';
  }

  @override
  String get bankTransactionsFound => 'No bank transactions found.';

  @override
  String get bestVALUE => 'BEST VALUE';

  @override
  String get borrowedFriend => 'Borrowed from Friend';

  @override
  String get browseLibraryTabTapCustom =>
      'Browse the Library tab or tap + Custom';

  @override
  String get cameraPermissionRequired => 'Camera permission required';

  @override
  String get cancelAnytimeQuestionsAsked =>
      'Cancel anytime. No questions asked.';

  @override
  String get cancelPlan => 'Cancel Plan';

  @override
  String get cancelSubscription => 'Cancel Subscription';

  @override
  String get cancelSubscription2 => 'Cancel Subscription?';

  @override
  String get cards => 'Your Cards';

  @override
  String get categoriesFound => 'No categories found';

  @override
  String get categoryUse => 'Category in Use';

  @override
  String get changePassword => 'Change Password';

  @override
  String get chooseUPIApp => 'Choose UPI App';

  @override
  String get clear => 'Clear';

  @override
  String get clearHistory => 'Clear History?';

  @override
  String get code => 'Your code: ';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get color => 'Color';

  @override
  String get confirm => 'Confirm';

  @override
  String get couldLoadForecast => 'Could not load forecast';

  @override
  String get couldOpenBrowser => 'Could not open browser';

  @override
  String get couldOpenWhatsApp => 'Could not open WhatsApp';

  @override
  String get couldnTLoadPaymentHistory => 'Couldn\'t load payment history.';

  @override
  String get couldnTLoadSubscriptionCheck =>
      'Couldn\'t load subscription. Check your connection.';

  @override
  String get couldnTLoadSubscriptionsCheck =>
      'Couldn\'t load subscriptions. Check your connection.';

  @override
  String get create => 'Create';

  @override
  String get createRecurringPaymentEMI => 'Create recurring payment for EMI';

  @override
  String get createSplitEntries => 'Create Split Entries';

  @override
  String get creditCards => 'Credit Cards';

  @override
  String get creditCardsAdded => 'No credit cards added';

  @override
  String get currentPlan => 'Current Plan';

  @override
  String get custom => 'Custom';

  @override
  String get customizeWhichCategoriesCount =>
      'Customize which categories count';

  @override
  String get dailyLimitTreatment => 'Daily limit treatment';

  @override
  String get dataBackedUpSecurely => 'Data backed up securely';

  @override
  String get dataFilters => 'Data Filters';

  @override
  String get dataSupport => 'Data & Support';

  @override
  String get debugForceExpiry => 'Debug: Force Expiry';

  @override
  String get defaultRulesCanTDeleted => 'Default rules can\'t be deleted';

  @override
  String get delete2 => 'Delete?';

  @override
  String get deleteAnyway => 'Delete Anyway';

  @override
  String get deleteGoal => 'Delete Goal?';

  @override
  String get deleteItemPermanently => 'This will delete this item permanently.';

  @override
  String get deleteNotificationHistory =>
      'This will delete all your notification history.';

  @override
  String get deleteSubscription => 'Delete Subscription?';

  @override
  String get deleteTransaction => 'Delete Transaction';

  @override
  String get done => 'Done!';

  @override
  String get due => 'Due';

  @override
  String get duplicateTransaction => 'Duplicate Transaction';

  @override
  String get durationDays => 'Duration (days)';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get editTransaction => 'Edit Transaction';

  @override
  String get endFreeTrial => 'End Free Trial?';

  @override
  String get endTrial => 'End Trial';

  @override
  String get enjoyUnlimitedAccessPremiumFeatures =>
      'Enjoy unlimited access to all premium features.';

  @override
  String get enterEmailForceExpiryDate =>
      'Enter email to force expiry date to yesterday.';

  @override
  String get enterTransactionID => 'Enter Transaction ID';

  @override
  String get enterValidTargetAmount => 'Enter a valid target amount';

  @override
  String get entries => 'Entries';

  @override
  String get errorLoadingCategories => 'Error loading categories';

  @override
  String get est => 'est.';

  @override
  String get evenSplit => 'Even split';

  @override
  String get expireNow => 'Expire Now';

  @override
  String get expired => 'Expired';

  @override
  String get expiryDate => 'Expiry Date:';

  @override
  String get exportCSV => 'Export CSV';

  @override
  String get exportPDF => 'Export PDF';

  @override
  String get failedLoadWealthDataPull =>
      'Failed to load wealth data. Pull down to retry.';

  @override
  String get female => 'Female';

  @override
  String get financialSummary => 'Financial Summary';

  @override
  String get freeTrialActive => 'Free Trial Active';

  @override
  String get freeTrialBeenEnded => 'Your free trial has been ended.';

  @override
  String get freeTrialEnded => 'Your free trial has ended';

  @override
  String get fullProAccessDuringTrial =>
      'You have full Pro access during your trial. Subscribe before it ends to keep everything.';

  @override
  String get gender => 'Gender';

  @override
  String get general => 'General';

  @override
  String get goBack => 'Go Back';

  @override
  String get goProfile => 'Go to Profile';

  @override
  String get goalNameRequired => 'Goal name is required';

  @override
  String goalsAddTo(Object name) {
    return 'Add to $name';
  }

  @override
  String get goalsAmountToAdd => 'Amount to add';

  @override
  String goalsDaysLeft(Object count) {
    return '$count days left';
  }

  @override
  String goalsDaysOverdue(Object count) {
    return '$count days overdue';
  }

  @override
  String goalsDeleteConfirm(Object name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get goalsYet => 'No goals yet';

  @override
  String get grantPermission => 'Grant Permission';

  @override
  String get backupAndRestore => 'Backup & Restore';

  @override
  String get backupAndRestoreAllData => 'Backup & Restore All Data';

  @override
  String get backupDownload => 'Download Backup';

  @override
  String get backupDownloadExplain =>
      'Saves a .json file you choose the location for. Keep it somewhere safe (email it to yourself, or a cloud drive) — a backup on the same device is not a backup.';

  @override
  String backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String backupIncompleteWarning(String collections) {
    return 'Last backup was incomplete — these could not be read: $collections. Try again before relying on that file.';
  }

  @override
  String get backupKeepOwnCopy => 'Keep your own copy';

  @override
  String get backupKeepOwnCopyBody =>
      'A backup is a single file holding every transaction, category, budget, goal, loan and asset, plus your profile. It downloads to your device and works without the app — so even a deleted account can be rebuilt from it.';

  @override
  String get backupRestoreCancel => 'Cancel';

  @override
  String get backupRestoreConfirm => 'Restore';

  @override
  String backupRestoreConfirmItems(int count) {
    return '$count items will be written back.';
  }

  @override
  String get backupRestoreConfirmTitle => 'Restore this backup?';

  @override
  String get backupRestoreExistingKept =>
      'Existing items are kept — restoring adds anything missing and updates items that are already there. Nothing is deleted.';

  @override
  String get backupRestoreExplain =>
      'Pick a backup file to restore. Existing items are kept; nothing is deleted.';

  @override
  String backupRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get backupRestoreFromFile => 'Restore From Backup File';

  @override
  String backupRestorePartial(
    int count,
    int failed,
    String names,
    String details,
  ) {
    return 'Restored $count items, but $failed collection(s) failed: $names. $details';
  }

  @override
  String backupRestoreSuccess(int count) {
    return 'Restored $count items.';
  }

  @override
  String backupRestoreTaken(String when) {
    return 'Backup taken $when';
  }

  @override
  String backupRestoreWrongAccount(String backupEmail, String currentEmail) {
    return 'Warning: this backup was made for $backupEmail, but you are signed in as $currentEmail.';
  }

  @override
  String backupSaved(int count, int collections) {
    return 'Backup saved: $count items across $collections collections';
  }

  @override
  String get backupSectionTitle => 'Backup';

  @override
  String get backupWorking => 'Working…';

  @override
  String get a11yProfilePhoto => 'Your profile';

  @override
  String get a11yPreviousMonth => 'Previous month';

  @override
  String get a11yNextMonth => 'Next month';

  @override
  String get addCustomAsset => 'Add Custom Asset';

  @override
  String get updateValueOrTarget => 'Update Value / Target';

  @override
  String get a11yProStatus => 'Pro status and subscription';

  @override
  String get a11ySearchTransactions => 'Search transactions';

  @override
  String get a11yRecurringPayments => 'Recurring payments';

  @override
  String get a11yLentMoney => 'Lent money';

  @override
  String get a11ySpendingForecast => 'Spending forecast';

  @override
  String get a11ySavingsGoals => 'Savings goals';

  @override
  String get a11ySavingsChallenges => 'Savings challenges';

  @override
  String get a11yMoreActions => 'More actions';

  @override
  String get a11yScanQrToPay => 'Scan a QR code to pay';

  @override
  String get a11yQuickSendUpi => 'Send money with UPI';

  @override
  String a11yQuickSendTo(String name) {
    return 'Send money with UPI to $name';
  }

  @override
  String get a11ySendMoney => 'Send money';

  @override
  String get a11yReceiveMoney => 'Receive money';

  @override
  String get backupNotSignedIn => 'You are not signed in.';

  @override
  String get backupNoDeviceSnapshot =>
      'No snapshot is stored on this device yet. One is taken automatically once a day.';

  @override
  String get backupRestoreFromDeviceSnapshot => 'Restore From Device Snapshot';

  @override
  String get backupRestoreFromDeviceSnapshotExplain =>
      'Your app keeps an automatic copy of the whole account on this device, refreshed once a day. Use it if something was deleted by accident.';

  @override
  String get backupHadNoTransactions => 'Backup had no transactions to restore';

  @override
  String restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String restoredFromBackup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restored $count transactions',
      one: 'Restored 1 transaction',
    );
    return '$_temp0 from backup';
  }

  @override
  String restoredFromPreservedBackup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restored $count transactions',
      one: 'Restored 1 transaction',
    );
    return '$_temp0 from backup — the preserved pre-deletion copy';
  }

  @override
  String get handlesRestoringLocalCacheMerge =>
      'This handles restoring from local cache. Merge restored transactions with current data?';

  @override
  String get homeWidget => 'Home Widget';

  @override
  String get howCategoryCountsTowardSmart =>
      'How this category counts toward your Smart Daily Limit. Ignored categories (e.g. investments/SIPs) never reduce it.';

  @override
  String get icon => 'Icon';

  @override
  String get idealIncome => 'Ideal Income';

  @override
  String get imageSelected => 'No image selected';

  @override
  String get importAnyway => 'Import Anyway';

  @override
  String get importBankCSV => 'Import Bank CSV';

  @override
  String get importData => 'Import Data';

  @override
  String get imported => 'Imported';

  @override
  String get incomeSource => 'Income Source';

  @override
  String get insurancePolicies => 'Insurance Policies';

  @override
  String get invalidSubscriptionDataFormat =>
      'Invalid subscription data format';

  @override
  String get inviteFriends => 'Invite Friends';

  @override
  String get inviteFriendsGetProFree => 'Invite friends, get Pro free';

  @override
  String get issuesFound => 'No issues found';

  @override
  String get keepPlan => 'Keep Plan';

  @override
  String get keepTrial => 'Keep Trial';

  @override
  String get keywordsYetTapAdd => 'No keywords yet — tap Add';

  @override
  String get ledgerCopiedClipboard => 'Ledger copied to clipboard';

  @override
  String get ledgerEntries => 'No ledger entries';

  @override
  String get limit => 'Limit';

  @override
  String get link => 'Link';

  @override
  String get linkTransaction => 'Link Transaction';

  @override
  String get linkTransaction2 => 'Link Transaction?';

  @override
  String get linked => 'LINKED';

  @override
  String get loading => 'Loading...';

  @override
  String get loanTracker => 'Loan Tracker';

  @override
  String get loansTrackedYet => 'No loans tracked yet';

  @override
  String get localBackupFoundTapBackup =>
      'No local backup found. Tap \'Backup Data\' first.';

  @override
  String get logged => 'Not logged in';

  @override
  String get loseProAccessImmediatelyCannot =>
      'You will lose Pro access immediately. This cannot be undone.';

  @override
  String get male => 'Male';

  @override
  String get manageSubscription => 'Manage Subscription';

  @override
  String get manageUsers => 'Manage Users';

  @override
  String get manageVisibility => 'Manage Visibility';

  @override
  String get manualMonthlyIncome => 'Manual Monthly Income';

  @override
  String get markPaid => 'Mark Paid';

  @override
  String get markPaid2 => 'Mark as Paid?';

  @override
  String get masterToggleOffNothingPosted =>
      'Master toggle is off — nothing will be posted until you turn it back on.';

  @override
  String get matchCSVHeadersAppFields => 'Match CSV headers to app fields';

  @override
  String get migrate => 'Migrate to:';

  @override
  String get migrateDelete => 'Migrate & Delete';

  @override
  String get missingRecurringPayment => 'Missing Recurring Payment';

  @override
  String get monthlyCommitment => 'Monthly Commitment';

  @override
  String get monthlyEMI => 'Monthly EMI';

  @override
  String get newCategory2 => 'New category';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsYet => 'No notifications yet';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get openUPIApp => 'Open UPI App';

  @override
  String get opening => 'Opening: ';

  @override
  String get other => 'Other';

  @override
  String get out => ' Out';

  @override
  String get out2 => 'Out';

  @override
  String get outstanding => 'Outstanding';

  @override
  String get paid => 'Paid';

  @override
  String get payViaUPI => 'Pay via UPI';

  @override
  String get paymentHistory => 'Payment History';

  @override
  String get paymentHistoryLinkedYet => 'No payment history linked yet.';

  @override
  String get paymentMode => 'Payment Mode';

  @override
  String get paymentSettings => 'Payment Settings';

  @override
  String get pendingRequests => 'No Pending Requests';

  @override
  String get pleaseEnterValidAmount => 'Please enter a valid amount';

  @override
  String get policies => 'Policies';

  @override
  String get policiesAdded => 'No policies added';

  @override
  String get preferSay => 'Prefer not to say';

  @override
  String get previewingFirst5Rows => 'Previewing first 5 rows:';

  @override
  String get proStatus => 'Pro Status:';

  @override
  String get proSubscriptionBeenCancelled =>
      'Your Pro subscription has been cancelled.';

  @override
  String get progress => 'In Progress';

  @override
  String get properties => 'Properties';

  @override
  String get propertiesAdded => 'No properties added';

  @override
  String get quickOverview => 'Quick Overview';

  @override
  String get reImport => 'Re-import';

  @override
  String get reImportTransactions => 'Re-import Transactions';

  @override
  String get realEstate => 'Real Estate';

  @override
  String get receiptScanner => 'Receipt Scanner';

  @override
  String get received => 'Received';

  @override
  String get recordPayment => 'Record Payment';

  @override
  String get recurringAutoPayHint =>
      'When due, a transaction is created automatically.';

  @override
  String get recurringCategoryLabel => 'Category';

  @override
  String get recurringFrequencyLabel => 'Frequency';

  @override
  String get recurringManualPayHint =>
      'Remind me when due — I\'ll mark it paid manually.';

  @override
  String get recurringNameLabel => 'Name (e.g. Netflix)';

  @override
  String get recurringRequired => 'Required';

  @override
  String get recurringSaveFailed => 'Failed to save. Please try again.';

  @override
  String get recurringEditSubscription => 'Edit Subscription';

  @override
  String get recurringEditTooltip => 'Edit subscription';

  @override
  String get recurringNewSubscription => 'New Subscription';

  @override
  String get recurringNextPaymentLabel => 'Next Payment:';

  @override
  String get recurringPaidLabel => 'PAID';

  @override
  String get recurringPausedLabel => 'PAUSED';

  @override
  String get recurringPendingLabel => 'PENDING';

  @override
  String get referralCODE => 'YOUR REFERRAL CODE';

  @override
  String get reject => 'Reject';

  @override
  String get remove => 'Remove';

  @override
  String get removeEntry => 'Remove entry?';

  @override
  String get removeEntry2 => 'Remove this entry?';

  @override
  String get removeLoan => 'Remove Loan';

  @override
  String get removeLoanItsLinkedRecurring =>
      'This will remove the loan and its linked recurring payment (if any).';

  @override
  String get removePolicy => 'Remove this policy?';

  @override
  String get removeProperty => 'Remove this property?';

  @override
  String get removeVehicle => 'Remove this vehicle?';

  @override
  String get repaymentHistory => 'Repayment History';

  @override
  String get repaymentsRecordedYet => 'No repayments recorded yet.';

  @override
  String get requestReviewedAdminNotifiedOnce =>
      'Your request will be reviewed by the admin. You will be notified once approved.';

  @override
  String get restore => 'Restore';

  @override
  String get restoreData => 'Restore Data';

  @override
  String get restorePurchases => 'Restore Purchases';

  @override
  String get retry => 'Retry';

  @override
  String get salaryDetected => 'Salary Detected';

  @override
  String get save33 => 'SAVE 33%';

  @override
  String get saveSettings => 'Save Settings';

  @override
  String get saveTRANSACTION => 'SAVE TRANSACTION';

  @override
  String get savedLocally => 'Saved locally';

  @override
  String get savingRate => 'Saving rate';

  @override
  String get savingsChallenges => 'Savings Challenges';

  @override
  String get savingsTarget => 'Savings Target';

  @override
  String get scanAgain => 'Scan Again';

  @override
  String get scanQR => 'Scan QR';

  @override
  String get scannedTextSave => 'No scanned text to save.';

  @override
  String get securityPrivacy => 'Security & Privacy';

  @override
  String get selectCategory2 => 'Select category';

  @override
  String get selectColumn => 'Select Column';

  @override
  String get selectCurrency => 'Select Currency';

  @override
  String get selectGender => 'Select Gender';

  @override
  String get selectSubscriptionViewDetails =>
      'Select a subscription to view details';

  @override
  String get selectTransactionViewDetails =>
      'Select a transaction to view details';

  @override
  String get setAgeFirst => 'Set Your Age First';

  @override
  String get setSavingsPurchaseGoalTrack =>
      'Set a savings or purchase goal\\nand track your progress.';

  @override
  String get shareReport => 'Share Report';

  @override
  String get shareSetAsideBeforeAI =>
      'This share is set aside before your AI Insights daily spending limit is calculated.';

  @override
  String get signConventionError => 'Sign Convention Error';

  @override
  String get signCorrected => 'Sign corrected';

  @override
  String get skip => 'Skip';

  @override
  String get skipPayment => 'Skip this Payment';

  @override
  String get skipPayment2 => 'Skip this payment?';

  @override
  String get smartMode => 'Smart Mode';

  @override
  String get smartModeVisibilityFollowsAge =>
      'Smart Mode is on — visibility follows your age recommendations. Turn it off to customize manually.';

  @override
  String get smartSuggestions => 'Smart Suggestions';

  @override
  String get smsPermissionPreviouslyDeniedPlease =>
      'SMS permission was previously denied. Please enable \"SMS\" permission in app settings to import transactions.';

  @override
  String get smsPermissionRequired => 'SMS Permission Required';

  @override
  String get smsTransactionsMatchingKeywordAuto =>
      'SMS transactions matching any keyword are auto-tagged to that category. Grey chips are defaults (read-only).';

  @override
  String get spendingHeatmap => 'Spending Heatmap';

  @override
  String get spendingPersonality => 'Your Spending Personality';

  @override
  String get spentOtherItems => 'Spent on other items';

  @override
  String get splitBill => 'Split a Bill';

  @override
  String get splashContinue => 'Continue';

  @override
  String get splashGetStarted => 'Get Started';

  @override
  String get splashHeadlineFillWallet => 'Fill Your Wallet';

  @override
  String get splashHeadlineSaveMoney => 'Save your Money';

  @override
  String get splashHeadlineTrackExpenses => 'Track Your Expenses';

  @override
  String get splashLetsStart => 'Let\'s Start';

  @override
  String get splashSubtitleFillWallet =>
      'Take control of your earnings by working smarter and building your own success story.';

  @override
  String get splashSubtitleSaveMoney =>
      'Discover smart ways to manage your finances and grow your savings—start making your money work for you, effortlessly and securely.';

  @override
  String get splashSubtitleTrackExpenses =>
      'Monitor your spending habits effortlessly and take control of your financial goals in real time.';

  @override
  String get start => 'Start';

  @override
  String get startChallenge => 'Start Challenge';

  @override
  String get startFirstChallenge => 'Start your first challenge 🎯';

  @override
  String get submitVerification => 'Submit for Verification';

  @override
  String get subscriptionDataFound => 'Subscription data not found';

  @override
  String get subscriptionDetails => 'Subscription Details';

  @override
  String get subscriptionFound => 'Subscription not found';

  @override
  String get subscriptionsYet => 'No subscriptions yet';

  @override
  String get suggestedRules => 'Suggested Rules';

  @override
  String get suggestionsYetAddDataGet =>
      'No suggestions yet. Add data to get insights!';

  @override
  String get superchargeFinancialControlPremiumFeat =>
      'Supercharge your financial control with premium features designed for growth.';

  @override
  String get sureWantCancelLoseAccess =>
      'Are you sure you want to cancel? You will lose access to Pro features at the end of the billing period.';

  @override
  String get sureWantDeleteSubscriptionPast =>
      'Are you sure you want to delete this subscription? Past transactions will remain, but future reminders will stop.';

  @override
  String get sureWantDeleteTransaction =>
      'Are you sure you want to delete this transaction?';

  @override
  String get tapAddFirstEntry => 'Tap + to add your first entry';

  @override
  String get tapResolve => 'Tap to resolve';

  @override
  String get tapTrackCardOutstanding => 'Tap + to track your card outstanding';

  @override
  String get tapTrackLifeInsuranceULIPs =>
      'Tap + to track life insurance and ULIPs';

  @override
  String get tapTrackRealEstate => 'Tap + to track your real estate';

  @override
  String get tapTrackVehicles => 'Tap + to track your vehicles';

  @override
  String get taxSummaryPDF => 'Tax Summary PDF';

  @override
  String get theseNonBillExpensesRent =>
      'These are your non-bill expenses. Rent, EMIs, bills, subscriptions and other fixed payments are excluded — open the excluded list below to see them.';

  @override
  String get topMerchants => 'Top Merchants';

  @override
  String get totalNetWorth => 'Total Net Worth';

  @override
  String get totalOutstanding => 'Total Outstanding';

  @override
  String get trackNetflixRentSpotifyEtc => 'Track Netflix, Rent, Spotify, etc.';

  @override
  String get trackingOnly => 'Tracking only';

  @override
  String get transactionAlreadyImportedCreateDuplic =>
      'This transaction was already imported. Create a duplicate?';

  @override
  String get transactionAudit => 'Transaction Audit';

  @override
  String get transactionDetails => 'Transaction Details';

  @override
  String get transactionIDShownUPIApp =>
      'The transaction ID is shown in your UPI app after payment.';

  @override
  String get transactionsFound => 'No transactions found.';

  @override
  String get typeUPIIDInstead => 'Type UPI ID instead';

  @override
  String get unlockProAccess => 'Unlock Pro Access';

  @override
  String get updateDueDateCreatingTransaction =>
      'This will update the due date and creating a transaction record.';

  @override
  String get upgradeProNow => 'Upgrade to Pro Now';

  @override
  String get upgradeRequestCurrentlyUnderReview =>
      'Your upgrade request is currently under review by the administration. You will be notified once your account is upgraded to Pro.';

  @override
  String get upiID => 'Your UPI ID';

  @override
  String get upiQRCodeTryAgain => 'Not a UPI QR code — try again';

  @override
  String get userLogged => 'User not logged in';

  @override
  String get usersAskedPayUPIID =>
      'Users will be asked to pay this UPI ID and enter the resulting transaction ID.';

  @override
  String get usersFound => 'No users found.';

  @override
  String get vehicles => 'Vehicles';

  @override
  String get vehicles2 => 'Your Vehicles';

  @override
  String get vehiclesAdded => 'No vehicles added';

  @override
  String get verificationProgress => 'Verification In Progress';

  @override
  String get viewAdvancedCategoryTrends => 'View Advanced Category Trends';

  @override
  String get visibleAssets => 'No visible assets';

  @override
  String get wealthBuilder => 'Wealth Builder';

  @override
  String get wealthBuilderPersonalisesEveryTarget =>
      'Wealth Builder personalises every target — emergency fund, equity allocation, retirement corpus — based on your age.\\n\\nAdd your date of birth in your profile to get started.';

  @override
  String get wealthsync => '💰 WealthSync';

  @override
  String get wealthsyncNeedsCameraAccessScan =>
      'WealthSync needs camera access to scan UPI QR codes. Open Settings to grant it.';

  @override
  String get wealthsyncWeb => 'WealthSync Web';

  @override
  String get whatShouldEarnStayTrack => 'What you should earn to stay on track';

  @override
  String get whenFriendSignsUpCode =>
      'When a friend signs up with your code, you both get +30 days of Pro — and every additional friend adds 30 more.';
}
