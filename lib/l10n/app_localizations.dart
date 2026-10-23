import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get welcomeBack;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No Transactions'**
  String get noTransactions;

  /// No description provided for @noTransactionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t made any transactions yet.'**
  String get noTransactionsSubtitle;

  /// No description provided for @sendMoney.
  ///
  /// In en, this message translates to:
  /// **'Send Money'**
  String get sendMoney;

  /// No description provided for @receiveMoney.
  ///
  /// In en, this message translates to:
  /// **'Receive Money'**
  String get receiveMoney;

  /// No description provided for @activeTab.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeTab;

  /// No description provided for @libraryTab.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTab;

  /// No description provided for @aiInsights.
  ///
  /// In en, this message translates to:
  /// **'AI Insights'**
  String get aiInsights;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @recipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipient;

  /// No description provided for @sender.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get sender;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get selectCategory;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get deleteCategoryTitle;

  /// No description provided for @deleteCategoryContent.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete \'{category}\'?\n\n• This will NOT delete existing transactions.\n• Category will simply be removed from your list.'**
  String deleteCategoryContent(Object category);

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get newCategory;

  /// No description provided for @categoryNameHint.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryNameHint;

  /// No description provided for @enterNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get enterNameHint;

  /// No description provided for @addNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note...'**
  String get addNoteHint;

  /// No description provided for @selectCategoryError.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get selectCategoryError;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcomeUser(Object name);

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s set up your financial goals in 2 steps.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingReferralHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. AMAN05'**
  String get onboardingReferralHint;

  /// No description provided for @onboardingReferralOptional.
  ///
  /// In en, this message translates to:
  /// **'Referral Code (Optional)'**
  String get onboardingReferralOptional;

  /// No description provided for @onboardingReferralPitch.
  ///
  /// In en, this message translates to:
  /// **'Have a friend’s code? Get 1 month free!'**
  String get onboardingReferralPitch;

  /// No description provided for @chooseCurrencyStep.
  ///
  /// In en, this message translates to:
  /// **'1. Choose Currency'**
  String get chooseCurrencyStep;

  /// No description provided for @setBudgetStep.
  ///
  /// In en, this message translates to:
  /// **'2. Set Monthly Budget'**
  String get setBudgetStep;

  /// No description provided for @budgetProUpsell.
  ///
  /// In en, this message translates to:
  /// **'Create budgets, track spending, and get alerts with Pro.'**
  String get budgetProUpsell;

  /// No description provided for @budgetSetLimit.
  ///
  /// In en, this message translates to:
  /// **'Set Limit'**
  String get budgetSetLimit;

  /// No description provided for @budgetUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get budgetUpdate;

  /// No description provided for @budgetHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 20000'**
  String get budgetHint;

  /// No description provided for @startTracking.
  ///
  /// In en, this message translates to:
  /// **'Start Tracking'**
  String get startTracking;

  /// No description provided for @enterBudgetError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a budget'**
  String get enterBudgetError;

  /// No description provided for @invalidNumberError.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumberError;

  /// No description provided for @transactionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistoryTitle;

  /// No description provided for @importSmsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import from SMS'**
  String get importSmsTooltip;

  /// No description provided for @tabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tabAll;

  /// No description provided for @tabIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get tabIncome;

  /// No description provided for @tabOutcome.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get tabOutcome;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @unknownRecipient.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownRecipient;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @monthlyForecastTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Forecast'**
  String get monthlyForecastTitle;

  /// No description provided for @incomeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'INCOME'**
  String get incomeSectionTitle;

  /// No description provided for @expenseSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'EXPENSES'**
  String get expenseSectionTitle;

  /// No description provided for @incomeSoFar.
  ///
  /// In en, this message translates to:
  /// **'Income So Far'**
  String get incomeSoFar;

  /// No description provided for @projectedRemaining.
  ///
  /// In en, this message translates to:
  /// **'Projected Remaining'**
  String get projectedRemaining;

  /// No description provided for @expensesSoFar.
  ///
  /// In en, this message translates to:
  /// **'Expenses So Far'**
  String get expensesSoFar;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get accessDenied;

  /// No description provided for @accessDevice.
  ///
  /// In en, this message translates to:
  /// **'Access from any device'**
  String get accessDevice;

  /// No description provided for @activeLoans.
  ///
  /// In en, this message translates to:
  /// **'Active Loans'**
  String get activeLoans;

  /// No description provided for @add2.
  ///
  /// In en, this message translates to:
  /// **'+ Add'**
  String get add2;

  /// No description provided for @addCard.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get addCard;

  /// No description provided for @addFirstGoal.
  ///
  /// In en, this message translates to:
  /// **'Add your first goal'**
  String get addFirstGoal;

  /// No description provided for @addLink.
  ///
  /// In en, this message translates to:
  /// **'Add Link'**
  String get addLink;

  /// No description provided for @addLoan.
  ///
  /// In en, this message translates to:
  /// **'Add Loan'**
  String get addLoan;

  /// No description provided for @addLoanTrackEMIsSee.
  ///
  /// In en, this message translates to:
  /// **'Add a loan to track EMIs and\\nsee your repayment schedule'**
  String get addLoanTrackEMIsSee;

  /// No description provided for @addPerson.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get addPerson;

  /// No description provided for @addPolicy.
  ///
  /// In en, this message translates to:
  /// **'Add Policy'**
  String get addPolicy;

  /// No description provided for @addProgress.
  ///
  /// In en, this message translates to:
  /// **'Add Progress'**
  String get addProgress;

  /// No description provided for @addProperty.
  ///
  /// In en, this message translates to:
  /// **'Add Property'**
  String get addProperty;

  /// No description provided for @addRule.
  ///
  /// In en, this message translates to:
  /// **'Add Rule'**
  String get addRule;

  /// No description provided for @addSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add Subscription'**
  String get addSubscription;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add Vehicle'**
  String get addVehicle;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @adminUtils.
  ///
  /// In en, this message translates to:
  /// **'Admin Utils'**
  String get adminUtils;

  /// No description provided for @advanceDueDateNextCycle.
  ///
  /// In en, this message translates to:
  /// **'This will advance the due date to the next cycle without recording a payment.'**
  String get advanceDueDateNextCycle;

  /// No description provided for @alignUPIQRCodeWithin.
  ///
  /// In en, this message translates to:
  /// **'Align the UPI QR code within the frame'**
  String get alignUPIQRCodeWithin;

  /// No description provided for @allocation.
  ///
  /// In en, this message translates to:
  /// **'Allocation'**
  String get allocation;

  /// No description provided for @alreadyImported.
  ///
  /// In en, this message translates to:
  /// **'Already Imported'**
  String get alreadyImported;

  /// No description provided for @analysisAddIncomeHint.
  ///
  /// In en, this message translates to:
  /// **'Add your income (a received Salary/Income entry) to see how much you can safely spend per day.'**
  String get analysisAddIncomeHint;

  /// No description provided for @analysisBillPaid.
  ///
  /// In en, this message translates to:
  /// **'You have paid your usual {category} bill.'**
  String analysisBillPaid(Object category);

  /// No description provided for @analysisBillPartial.
  ///
  /// In en, this message translates to:
  /// **'{category} payment seems partial.'**
  String analysisBillPartial(Object category);

  /// No description provided for @analysisBillPending.
  ///
  /// In en, this message translates to:
  /// **'Pending: you usually pay ~{amount}.'**
  String analysisBillPending(Object amount);

  /// No description provided for @analysisCarefulSpending.
  ///
  /// In en, this message translates to:
  /// **'Careful, you\'re slightly above today\'s safe limit.'**
  String get analysisCarefulSpending;

  /// No description provided for @analysisCategoryInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Category Insights'**
  String get analysisCategoryInsightsTitle;

  /// No description provided for @analysisDaySpend.
  ///
  /// In en, this message translates to:
  /// **'Day {day}: {amount}'**
  String analysisDaySpend(Object amount, Object day);

  /// No description provided for @analysisEmpty.
  ///
  /// In en, this message translates to:
  /// **'No expense transactions yet.\nAdd a \'Send\' transaction to see AI insights.'**
  String get analysisEmpty;

  /// No description provided for @analysisError.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis Error: {error}'**
  String analysisError(Object error);

  /// No description provided for @analysisForecastTitle.
  ///
  /// In en, this message translates to:
  /// **'This Month Forecast'**
  String get analysisForecastTitle;

  /// No description provided for @analysisHeatmapLegend.
  ///
  /// In en, this message translates to:
  /// **'Darker boxes indicate higher spending days.'**
  String get analysisHeatmapLegend;

  /// No description provided for @analysisIncomeBreakdown.
  ///
  /// In en, this message translates to:
  /// **'From ~{income} income: saving {saving} ({rate}%) and {bills} for bills. Already spent {spent} on other items, leaving {remaining} over {days, plural, =1{1 day} other{{days} days}}.'**
  String analysisIncomeBreakdown(
    Object bills,
    num days,
    Object income,
    Object rate,
    Object remaining,
    Object saving,
    Object spent,
  );

  /// No description provided for @analysisItemsSpent.
  ///
  /// In en, this message translates to:
  /// **'Items spent this month'**
  String get analysisItemsSpent;

  /// No description provided for @analysisItemsSummary.
  ///
  /// In en, this message translates to:
  /// **'{amount} · {count, plural, =1{transaction} other{{count} transactions}}'**
  String analysisItemsSummary(Object amount, num count);

  /// No description provided for @analysisManualNotSet.
  ///
  /// In en, this message translates to:
  /// **'Manual not set — using Auto – Blend'**
  String get analysisManualNotSet;

  /// No description provided for @analysisMode.
  ///
  /// In en, this message translates to:
  /// **'Mode: {mode}'**
  String analysisMode(Object mode);

  /// No description provided for @analysisMonthlyHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Monthly Spend Heatmap'**
  String get analysisMonthlyHeatmap;

  /// No description provided for @analysisNoOtherItems.
  ///
  /// In en, this message translates to:
  /// **'No other items yet — every expense is a bill'**
  String get analysisNoOtherItems;

  /// No description provided for @analysisNoSalaryWindow.
  ///
  /// In en, this message translates to:
  /// **'No salary credits found in window (current month first week or previous month last working day)'**
  String get analysisNoSalaryWindow;

  /// No description provided for @analysisNoSpendingMonth.
  ///
  /// In en, this message translates to:
  /// **'No spending recorded this month yet.\nAs you spend, this calendar will light up day by day.'**
  String get analysisNoSpendingMonth;

  /// No description provided for @analysisNoSpendingYet.
  ///
  /// In en, this message translates to:
  /// **'No spending yet. Great start to saving!'**
  String get analysisNoSpendingYet;

  /// No description provided for @analysisOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track with usual spending.'**
  String get analysisOnTrack;

  /// No description provided for @analysisOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get analysisOthers;

  /// No description provided for @analysisOvershooting.
  ///
  /// In en, this message translates to:
  /// **'Overshooting by ~{percent}%'**
  String analysisOvershooting(Object percent);

  /// No description provided for @analysisPredicted.
  ///
  /// In en, this message translates to:
  /// **'Predicted: {amount}'**
  String analysisPredicted(Object amount);

  /// No description provided for @analysisProjectedOvershoot.
  ///
  /// In en, this message translates to:
  /// **'Projected +{percent}% vs usual.'**
  String analysisProjectedOvershoot(Object percent);

  /// No description provided for @analysisSeeOtherItems.
  ///
  /// In en, this message translates to:
  /// **'See which transactions count as other items'**
  String get analysisSeeOtherItems;

  /// No description provided for @analysisSmartDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Smart Daily Limit'**
  String get analysisSmartDailyLimit;

  /// No description provided for @analysisSpendPerDay.
  ///
  /// In en, this message translates to:
  /// **'Spend per day'**
  String get analysisSpendPerDay;

  /// No description provided for @analysisSpendingFaster.
  ///
  /// In en, this message translates to:
  /// **'Spending on {category} is faster than usual.'**
  String analysisSpendingFaster(Object category);

  /// No description provided for @analysisSpendingLower.
  ///
  /// In en, this message translates to:
  /// **'Good job! {category} spending is lower than usual.'**
  String analysisSpendingLower(Object category);

  /// No description provided for @analysisSpendingNone.
  ///
  /// In en, this message translates to:
  /// **'No spending on {category} yet.'**
  String analysisSpendingNone(Object category);

  /// No description provided for @analysisSpendingOnTrack.
  ///
  /// In en, this message translates to:
  /// **'{category} spending is on track.'**
  String analysisSpendingOnTrack(Object category);

  /// No description provided for @analysisSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent: {amount}'**
  String analysisSpent(Object amount);

  /// No description provided for @analysisStopSpending.
  ///
  /// In en, this message translates to:
  /// **'Stop! You\'re well above today\'s safe limit.'**
  String get analysisStopSpending;

  /// No description provided for @analysisTarget.
  ///
  /// In en, this message translates to:
  /// **'Target: {amount}'**
  String analysisTarget(Object amount);

  /// No description provided for @analysisUsual.
  ///
  /// In en, this message translates to:
  /// **'Usual: {amount}'**
  String analysisUsual(Object amount);

  /// No description provided for @analysisWithinLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'re within today\'s safe limit.'**
  String get analysisWithinLimit;

  /// No description provided for @analyticsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced Analytics'**
  String get analyticsAdvanced;

  /// No description provided for @analyticsAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get analyticsAllCategories;

  /// No description provided for @analyticsCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get analyticsCategory;

  /// No description provided for @analyticsDataExport.
  ///
  /// In en, this message translates to:
  /// **'Data Export'**
  String get analyticsDataExport;

  /// No description provided for @analyticsExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get analyticsExpense;

  /// No description provided for @analyticsExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get analyticsExpenses;

  /// No description provided for @analyticsExportCsvDesc.
  ///
  /// In en, this message translates to:
  /// **'Export your transaction history as CSV.'**
  String get analyticsExportCsvDesc;

  /// No description provided for @analyticsExportPdfDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate detailed PDF reports for analysis.'**
  String get analyticsExportPdfDesc;

  /// No description provided for @analyticsHeatmapBillDue.
  ///
  /// In en, this message translates to:
  /// **'Bill/EMI due'**
  String get analyticsHeatmapBillDue;

  /// No description provided for @analyticsHeatmapHighSpend.
  ///
  /// In en, this message translates to:
  /// **'High spend'**
  String get analyticsHeatmapHighSpend;

  /// No description provided for @analyticsHeatmapLowSpend.
  ///
  /// In en, this message translates to:
  /// **'Low spend'**
  String get analyticsHeatmapLowSpend;

  /// No description provided for @analyticsHeatmapSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get analyticsHeatmapSalary;

  /// No description provided for @analyticsIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get analyticsIn;

  /// No description provided for @analyticsNetBalance.
  ///
  /// In en, this message translates to:
  /// **'Net Balance'**
  String get analyticsNetBalance;

  /// No description provided for @analyticsInLegend.
  ///
  /// In en, this message translates to:
  /// **' In'**
  String get analyticsInLegend;

  /// No description provided for @analyticsNotEnoughDataForTrend.
  ///
  /// In en, this message translates to:
  /// **'Not enough data for trend.'**
  String get analyticsNotEnoughDataForTrend;

  /// No description provided for @analyticsOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get analyticsOthers;

  /// No description provided for @analyticsPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get analyticsPeriod;

  /// No description provided for @analyticsPersonalityBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced Spender'**
  String get analyticsPersonalityBalanced;

  /// No description provided for @analyticsPersonalityBalancedDesc.
  ///
  /// In en, this message translates to:
  /// **'Your spending is well-distributed across categories.'**
  String get analyticsPersonalityBalancedDesc;

  /// No description provided for @analyticsPersonalityBigSpender.
  ///
  /// In en, this message translates to:
  /// **'Big Spender'**
  String get analyticsPersonalityBigSpender;

  /// No description provided for @analyticsPersonalityBigSpenderDesc.
  ///
  /// In en, this message translates to:
  /// **'Your average transaction is over {amount} — you go big.'**
  String analyticsPersonalityBigSpenderDesc(Object amount);

  /// No description provided for @analyticsPersonalityCommuter.
  ///
  /// In en, this message translates to:
  /// **'Commuter'**
  String get analyticsPersonalityCommuter;

  /// No description provided for @analyticsPersonalityCommuterDesc.
  ///
  /// In en, this message translates to:
  /// **'Transport accounts for {pct}% of your expenses.'**
  String analyticsPersonalityCommuterDesc(Object pct);

  /// No description provided for @analyticsPersonalityFoodie.
  ///
  /// In en, this message translates to:
  /// **'Foodie'**
  String get analyticsPersonalityFoodie;

  /// No description provided for @analyticsPersonalityFoodieDesc.
  ///
  /// In en, this message translates to:
  /// **'Food & dining makes up {pct}% of your spending.'**
  String analyticsPersonalityFoodieDesc(Object pct);

  /// No description provided for @analyticsPersonalityFrequentSpender.
  ///
  /// In en, this message translates to:
  /// **'Frequent Spender'**
  String get analyticsPersonalityFrequentSpender;

  /// No description provided for @analyticsPersonalityFrequentSpenderDesc.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction in the last 30 days} other{{count} transactions in the last 30 days}} — always on the move.'**
  String analyticsPersonalityFrequentSpenderDesc(num count);

  /// No description provided for @analyticsPersonalityFunSeeker.
  ///
  /// In en, this message translates to:
  /// **'Fun Seeker'**
  String get analyticsPersonalityFunSeeker;

  /// No description provided for @analyticsPersonalityFunSeekerDesc.
  ///
  /// In en, this message translates to:
  /// **'Entertainment & leisure is your top spending category.'**
  String get analyticsPersonalityFunSeekerDesc;

  /// No description provided for @analyticsPersonalityJustStarting.
  ///
  /// In en, this message translates to:
  /// **'Just Getting Started'**
  String get analyticsPersonalityJustStarting;

  /// No description provided for @analyticsPersonalityJustStartingDesc.
  ///
  /// In en, this message translates to:
  /// **'Add more transactions to unlock your spending personality.'**
  String get analyticsPersonalityJustStartingDesc;

  /// No description provided for @analyticsPersonalityShopaholic.
  ///
  /// In en, this message translates to:
  /// **'Shopaholic'**
  String get analyticsPersonalityShopaholic;

  /// No description provided for @analyticsPersonalityShopaholicDesc.
  ///
  /// In en, this message translates to:
  /// **'Shopping takes {pct}% of your budget.'**
  String analyticsPersonalityShopaholicDesc(Object pct);

  /// No description provided for @analyticsPersonalitySmartSaver.
  ///
  /// In en, this message translates to:
  /// **'Smart Saver'**
  String get analyticsPersonalitySmartSaver;

  /// No description provided for @analyticsPersonalitySmartSaverDesc.
  ///
  /// In en, this message translates to:
  /// **'You save over 40% of your income — great financial discipline!'**
  String get analyticsPersonalitySmartSaverDesc;

  /// No description provided for @analyticsShareReportDesc.
  ///
  /// In en, this message translates to:
  /// **'Share your monthly report as an image.'**
  String get analyticsShareReportDesc;

  /// No description provided for @analyticsShareReportFileName.
  ///
  /// In en, this message translates to:
  /// **'My {period} Financial Report — Money Control'**
  String analyticsShareReportFileName(Object period);

  /// No description provided for @analyticsSpendingExceedsIncome.
  ///
  /// In en, this message translates to:
  /// **'Spending exceeds income by {pct}%'**
  String analyticsSpendingExceedsIncome(Object pct);

  /// No description provided for @analyticsTaxSummary.
  ///
  /// In en, this message translates to:
  /// **'Tax Summary'**
  String get analyticsTaxSummary;

  /// No description provided for @analyticsTaxSummaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Export categorized annual tax summary PDF.'**
  String get analyticsTaxSummaryDesc;

  /// No description provided for @analyticsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get analyticsThisMonth;

  /// No description provided for @analyticsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get analyticsThisWeek;

  /// No description provided for @analyticsTransactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String analyticsTransactionCount(num count);

  /// No description provided for @analyticsUnknownMerchant.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get analyticsUnknownMerchant;

  /// No description provided for @analyticsUnlockHistory.
  ///
  /// In en, this message translates to:
  /// **'Unlock full history and custom date ranges.'**
  String get analyticsUnlockHistory;

  /// No description provided for @analyticsReports.
  ///
  /// In en, this message translates to:
  /// **'Analytics & Reports'**
  String get analyticsReports;

  /// No description provided for @annually.
  ///
  /// In en, this message translates to:
  /// **'annually'**
  String get annually;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @assetsLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Assets − All Liabilities'**
  String get assetsLiabilities;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'AUTO'**
  String get auto;

  /// No description provided for @autoPAYMISSED.
  ///
  /// In en, this message translates to:
  /// **'AUTO-PAY MISSED'**
  String get autoPAYMISSED;

  /// No description provided for @autoPay.
  ///
  /// In en, this message translates to:
  /// **'Auto-pay'**
  String get autoPay;

  /// No description provided for @autoTagRules.
  ///
  /// In en, this message translates to:
  /// **'Auto-Tag Rules'**
  String get autoTagRules;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @bankDataImported.
  ///
  /// In en, this message translates to:
  /// **'No bank data imported'**
  String get bankDataImported;

  /// No description provided for @balanceAddLent.
  ///
  /// In en, this message translates to:
  /// **'+ Add Lent'**
  String get balanceAddLent;

  /// No description provided for @balanceDeductDues.
  ///
  /// In en, this message translates to:
  /// **'Deduct this month\'s dues from the total balance'**
  String get balanceDeductDues;

  /// No description provided for @balanceDuesDeducted.
  ///
  /// In en, this message translates to:
  /// **'Dues Deducted'**
  String get balanceDuesDeducted;

  /// No description provided for @balanceDuesDue.
  ///
  /// In en, this message translates to:
  /// **'- {amount} due'**
  String balanceDuesDue(String amount);

  /// No description provided for @balanceDuesHidden.
  ///
  /// In en, this message translates to:
  /// **'- •••• due'**
  String get balanceDuesHidden;

  /// No description provided for @balanceHidden.
  ///
  /// In en, this message translates to:
  /// **'••••'**
  String get balanceHidden;

  /// No description provided for @balanceHiddenAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'{title}. Hidden'**
  String balanceHiddenAnnouncement(String title);

  /// No description provided for @balanceIncludeLent.
  ///
  /// In en, this message translates to:
  /// **'Include lent money in the total balance'**
  String get balanceIncludeLent;

  /// No description provided for @balanceLentIncluded.
  ///
  /// In en, this message translates to:
  /// **'Lent Included'**
  String get balanceLentIncluded;

  /// No description provided for @balanceNoDues.
  ///
  /// In en, this message translates to:
  /// **'- No Dues'**
  String get balanceNoDues;

  /// No description provided for @balanceStreak.
  ///
  /// In en, this message translates to:
  /// **'{days} day streak'**
  String balanceStreak(int days);

  /// No description provided for @balanceTapToHide.
  ///
  /// In en, this message translates to:
  /// **'{title}. Tap to hide'**
  String balanceTapToHide(String title);

  /// No description provided for @balanceVersusLastMonth.
  ///
  /// In en, this message translates to:
  /// **'{percent}% vs last month'**
  String balanceVersusLastMonth(String percent);

  /// No description provided for @bankTransactionsFound.
  ///
  /// In en, this message translates to:
  /// **'No bank transactions found.'**
  String get bankTransactionsFound;

  /// No description provided for @bestVALUE.
  ///
  /// In en, this message translates to:
  /// **'BEST VALUE'**
  String get bestVALUE;

  /// No description provided for @borrowedFriend.
  ///
  /// In en, this message translates to:
  /// **'Borrowed from Friend'**
  String get borrowedFriend;

  /// No description provided for @browseLibraryTabTapCustom.
  ///
  /// In en, this message translates to:
  /// **'Browse the Library tab or tap + Custom'**
  String get browseLibraryTabTapCustom;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission required'**
  String get cameraPermissionRequired;

  /// No description provided for @cancelAnytimeQuestionsAsked.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime. No questions asked.'**
  String get cancelAnytimeQuestionsAsked;

  /// No description provided for @cancelPlan.
  ///
  /// In en, this message translates to:
  /// **'Cancel Plan'**
  String get cancelPlan;

  /// No description provided for @cancelSubscription.
  ///
  /// In en, this message translates to:
  /// **'Cancel Subscription'**
  String get cancelSubscription;

  /// No description provided for @cancelSubscription2.
  ///
  /// In en, this message translates to:
  /// **'Cancel Subscription?'**
  String get cancelSubscription2;

  /// No description provided for @cards.
  ///
  /// In en, this message translates to:
  /// **'Your Cards'**
  String get cards;

  /// No description provided for @categoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get categoriesFound;

  /// No description provided for @categoryUse.
  ///
  /// In en, this message translates to:
  /// **'Category in Use'**
  String get categoryUse;

  /// No description provided for @challengeCustomDescription.
  ///
  /// In en, this message translates to:
  /// **'Custom challenge'**
  String get challengeCustomDescription;

  /// No description provided for @challengeCustomDaysHint.
  ///
  /// In en, this message translates to:
  /// **'Or enter custom days'**
  String get challengeCustomDaysHint;

  /// No description provided for @challengeCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Challenge'**
  String get challengeCustomTitle;

  /// No description provided for @challengeDaysLeftShort.
  ///
  /// In en, this message translates to:
  /// **'{days}d left'**
  String challengeDaysLeftShort(Object days);

  /// No description provided for @challengeDaysOption.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String challengeDaysOption(Object days);

  /// No description provided for @challengeEndsOn.
  ///
  /// In en, this message translates to:
  /// **'Ends: {date}'**
  String challengeEndsOn(Object date);

  /// No description provided for @challengeNameHint.
  ///
  /// In en, this message translates to:
  /// **'Challenge Name'**
  String get challengeNameHint;

  /// No description provided for @challengeSaved.
  ///
  /// In en, this message translates to:
  /// **'{amount} saved'**
  String challengeSaved(Object amount);

  /// No description provided for @challengeSpent.
  ///
  /// In en, this message translates to:
  /// **'{amount} spent'**
  String challengeSpent(Object amount);

  /// No description provided for @challengeStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start {name}'**
  String challengeStartTitle(Object name);

  /// No description provided for @challengeTarget.
  ///
  /// In en, this message translates to:
  /// **'Target: {amount}'**
  String challengeTarget(Object amount);

  /// No description provided for @challengeTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Target Amount ({symbol})'**
  String challengeTargetHint(Object symbol);

  /// No description provided for @challengeZeroSpendGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal: {amount} on {category}'**
  String challengeZeroSpendGoal(Object amount, Object category);

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @chooseUPIApp.
  ///
  /// In en, this message translates to:
  /// **'Choose UPI App'**
  String get chooseUPIApp;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History?'**
  String get clearHistory;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Your code: '**
  String get code;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @couldLoadForecast.
  ///
  /// In en, this message translates to:
  /// **'Could not load forecast'**
  String get couldLoadForecast;

  /// No description provided for @couldOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Could not open browser'**
  String get couldOpenBrowser;

  /// No description provided for @couldOpenWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp'**
  String get couldOpenWhatsApp;

  /// No description provided for @couldnTLoadPaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load payment history.'**
  String get couldnTLoadPaymentHistory;

  /// No description provided for @couldnTLoadSubscriptionCheck.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load subscription. Check your connection.'**
  String get couldnTLoadSubscriptionCheck;

  /// No description provided for @couldnTLoadSubscriptionsCheck.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load subscriptions. Check your connection.'**
  String get couldnTLoadSubscriptionsCheck;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createRecurringPaymentEMI.
  ///
  /// In en, this message translates to:
  /// **'Create recurring payment for EMI'**
  String get createRecurringPaymentEMI;

  /// No description provided for @createSplitEntries.
  ///
  /// In en, this message translates to:
  /// **'Create Split Entries'**
  String get createSplitEntries;

  /// No description provided for @creditCards.
  ///
  /// In en, this message translates to:
  /// **'Credit Cards'**
  String get creditCards;

  /// No description provided for @creditCardsAdded.
  ///
  /// In en, this message translates to:
  /// **'No credit cards added'**
  String get creditCardsAdded;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get currentPlan;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @customizeWhichCategoriesCount.
  ///
  /// In en, this message translates to:
  /// **'Customize which categories count'**
  String get customizeWhichCategoriesCount;

  /// No description provided for @dailyLimitTreatment.
  ///
  /// In en, this message translates to:
  /// **'Daily limit treatment'**
  String get dailyLimitTreatment;

  /// No description provided for @dataBackedUpSecurely.
  ///
  /// In en, this message translates to:
  /// **'Data backed up securely'**
  String get dataBackedUpSecurely;

  /// No description provided for @dataFilters.
  ///
  /// In en, this message translates to:
  /// **'Data Filters'**
  String get dataFilters;

  /// No description provided for @dataSupport.
  ///
  /// In en, this message translates to:
  /// **'Data & Support'**
  String get dataSupport;

  /// No description provided for @debugForceExpiry.
  ///
  /// In en, this message translates to:
  /// **'Debug: Force Expiry'**
  String get debugForceExpiry;

  /// No description provided for @defaultRulesCanTDeleted.
  ///
  /// In en, this message translates to:
  /// **'Default rules can\'t be deleted'**
  String get defaultRulesCanTDeleted;

  /// No description provided for @delete2.
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get delete2;

  /// No description provided for @deleteAnyway.
  ///
  /// In en, this message translates to:
  /// **'Delete Anyway'**
  String get deleteAnyway;

  /// No description provided for @deleteGoal.
  ///
  /// In en, this message translates to:
  /// **'Delete Goal?'**
  String get deleteGoal;

  /// No description provided for @deleteItemPermanently.
  ///
  /// In en, this message translates to:
  /// **'This will delete this item permanently.'**
  String get deleteItemPermanently;

  /// No description provided for @deleteNotificationHistory.
  ///
  /// In en, this message translates to:
  /// **'This will delete all your notification history.'**
  String get deleteNotificationHistory;

  /// No description provided for @deleteSubscription.
  ///
  /// In en, this message translates to:
  /// **'Delete Subscription?'**
  String get deleteSubscription;

  /// No description provided for @deleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Delete Transaction'**
  String get deleteTransaction;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get done;

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get due;

  /// No description provided for @duplicateTransaction.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Transaction'**
  String get duplicateTransaction;

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'Duration (days)'**
  String get durationDays;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get editTransaction;

  /// No description provided for @endFreeTrial.
  ///
  /// In en, this message translates to:
  /// **'End Free Trial?'**
  String get endFreeTrial;

  /// No description provided for @endTrial.
  ///
  /// In en, this message translates to:
  /// **'End Trial'**
  String get endTrial;

  /// No description provided for @enjoyUnlimitedAccessPremiumFeatures.
  ///
  /// In en, this message translates to:
  /// **'Enjoy unlimited access to all premium features.'**
  String get enjoyUnlimitedAccessPremiumFeatures;

  /// No description provided for @enterEmailForceExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Enter email to force expiry date to yesterday.'**
  String get enterEmailForceExpiryDate;

  /// No description provided for @enterTransactionID.
  ///
  /// In en, this message translates to:
  /// **'Enter Transaction ID'**
  String get enterTransactionID;

  /// No description provided for @enterValidTargetAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid target amount'**
  String get enterValidTargetAmount;

  /// No description provided for @entries.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get entries;

  /// No description provided for @errorLoadingCategories.
  ///
  /// In en, this message translates to:
  /// **'Error loading categories'**
  String get errorLoadingCategories;

  /// No description provided for @est.
  ///
  /// In en, this message translates to:
  /// **'est.'**
  String get est;

  /// No description provided for @evenSplit.
  ///
  /// In en, this message translates to:
  /// **'Even split'**
  String get evenSplit;

  /// No description provided for @expireNow.
  ///
  /// In en, this message translates to:
  /// **'Expire Now'**
  String get expireNow;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date:'**
  String get expiryDate;

  /// No description provided for @exportCSV.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCSV;

  /// No description provided for @exportPDF.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPDF;

  /// No description provided for @failedLoadWealthDataPull.
  ///
  /// In en, this message translates to:
  /// **'Failed to load wealth data. Pull down to retry.'**
  String get failedLoadWealthDataPull;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @financialSummary.
  ///
  /// In en, this message translates to:
  /// **'Financial Summary'**
  String get financialSummary;

  /// No description provided for @freeTrialActive.
  ///
  /// In en, this message translates to:
  /// **'Free Trial Active'**
  String get freeTrialActive;

  /// No description provided for @freeTrialBeenEnded.
  ///
  /// In en, this message translates to:
  /// **'Your free trial has been ended.'**
  String get freeTrialBeenEnded;

  /// No description provided for @freeTrialEnded.
  ///
  /// In en, this message translates to:
  /// **'Your free trial has ended'**
  String get freeTrialEnded;

  /// No description provided for @fullProAccessDuringTrial.
  ///
  /// In en, this message translates to:
  /// **'You have full Pro access during your trial. Subscribe before it ends to keep everything.'**
  String get fullProAccessDuringTrial;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @goProfile.
  ///
  /// In en, this message translates to:
  /// **'Go to Profile'**
  String get goProfile;

  /// No description provided for @goalNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Goal name is required'**
  String get goalNameRequired;

  /// No description provided for @goalsAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to {name}'**
  String goalsAddTo(Object name);

  /// No description provided for @goalsAmountToAdd.
  ///
  /// In en, this message translates to:
  /// **'Amount to add'**
  String get goalsAmountToAdd;

  /// No description provided for @goalsDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} days left'**
  String goalsDaysLeft(Object count);

  /// No description provided for @goalsDaysOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count} days overdue'**
  String goalsDaysOverdue(Object count);

  /// No description provided for @goalsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String goalsDeleteConfirm(Object name);

  /// No description provided for @goalsYet.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get goalsYet;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get grantPermission;

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupAndRestore;

  /// No description provided for @backupAndRestoreAllData.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore All Data'**
  String get backupAndRestoreAllData;

  /// No description provided for @backupDownload.
  ///
  /// In en, this message translates to:
  /// **'Download Backup'**
  String get backupDownload;

  /// No description provided for @backupDownloadExplain.
  ///
  /// In en, this message translates to:
  /// **'Saves a .json file you choose the location for. Keep it somewhere safe (email it to yourself, or a cloud drive) — a backup on the same device is not a backup.'**
  String get backupDownloadExplain;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String backupFailed(String error);

  /// No description provided for @backupIncompleteWarning.
  ///
  /// In en, this message translates to:
  /// **'Last backup was incomplete — these could not be read: {collections}. Try again before relying on that file.'**
  String backupIncompleteWarning(String collections);

  /// No description provided for @backupKeepOwnCopy.
  ///
  /// In en, this message translates to:
  /// **'Keep your own copy'**
  String get backupKeepOwnCopy;

  /// No description provided for @backupKeepOwnCopyBody.
  ///
  /// In en, this message translates to:
  /// **'A backup is a single file holding every transaction, category, budget, goal, loan and asset, plus your profile. It downloads to your device and works without the app — so even a deleted account can be rebuilt from it.'**
  String get backupKeepOwnCopyBody;

  /// No description provided for @backupRestoreCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get backupRestoreCancel;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestoreConfirmItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items will be written back.'**
  String backupRestoreConfirmItems(int count);

  /// No description provided for @backupRestoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get backupRestoreConfirmTitle;

  /// No description provided for @backupRestoreExistingKept.
  ///
  /// In en, this message translates to:
  /// **'Existing items are kept — restoring adds anything missing and updates items that are already there. Nothing is deleted.'**
  String get backupRestoreExistingKept;

  /// No description provided for @backupRestoreExplain.
  ///
  /// In en, this message translates to:
  /// **'Pick a backup file to restore. Existing items are kept; nothing is deleted.'**
  String get backupRestoreExplain;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String backupRestoreFailed(String error);

  /// No description provided for @backupRestoreFromFile.
  ///
  /// In en, this message translates to:
  /// **'Restore From Backup File'**
  String get backupRestoreFromFile;

  /// No description provided for @backupRestorePartial.
  ///
  /// In en, this message translates to:
  /// **'Restored {count} items, but {failed} collection(s) failed: {names}. {details}'**
  String backupRestorePartial(
    int count,
    int failed,
    String names,
    String details,
  );

  /// No description provided for @backupRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restored {count} items.'**
  String backupRestoreSuccess(int count);

  /// No description provided for @backupRestoreTaken.
  ///
  /// In en, this message translates to:
  /// **'Backup taken {when}'**
  String backupRestoreTaken(String when);

  /// No description provided for @backupRestoreWrongAccount.
  ///
  /// In en, this message translates to:
  /// **'Warning: this backup was made for {backupEmail}, but you are signed in as {currentEmail}.'**
  String backupRestoreWrongAccount(String backupEmail, String currentEmail);

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved: {count} items across {collections} collections'**
  String backupSaved(int count, int collections);

  /// No description provided for @backupSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupSectionTitle;

  /// No description provided for @backupWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get backupWorking;

  /// No description provided for @a11yProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get a11yProfilePhoto;

  /// No description provided for @a11yPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get a11yPreviousMonth;

  /// No description provided for @a11yNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get a11yNextMonth;

  /// No description provided for @addCustomAsset.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Asset'**
  String get addCustomAsset;

  /// No description provided for @updateValueOrTarget.
  ///
  /// In en, this message translates to:
  /// **'Update Value / Target'**
  String get updateValueOrTarget;

  /// No description provided for @a11yProStatus.
  ///
  /// In en, this message translates to:
  /// **'Pro status and subscription'**
  String get a11yProStatus;

  /// No description provided for @a11ySearchTransactions.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get a11ySearchTransactions;

  /// No description provided for @a11yRecurringPayments.
  ///
  /// In en, this message translates to:
  /// **'Recurring payments'**
  String get a11yRecurringPayments;

  /// No description provided for @a11yLentMoney.
  ///
  /// In en, this message translates to:
  /// **'Lent money'**
  String get a11yLentMoney;

  /// No description provided for @a11ySpendingForecast.
  ///
  /// In en, this message translates to:
  /// **'Spending forecast'**
  String get a11ySpendingForecast;

  /// No description provided for @a11ySavingsGoals.
  ///
  /// In en, this message translates to:
  /// **'Savings goals'**
  String get a11ySavingsGoals;

  /// No description provided for @a11ySavingsChallenges.
  ///
  /// In en, this message translates to:
  /// **'Savings challenges'**
  String get a11ySavingsChallenges;

  /// No description provided for @a11yMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get a11yMoreActions;

  /// No description provided for @a11yScanQrToPay.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code to pay'**
  String get a11yScanQrToPay;

  /// No description provided for @a11yQuickSendUpi.
  ///
  /// In en, this message translates to:
  /// **'Send money with UPI'**
  String get a11yQuickSendUpi;

  /// No description provided for @a11yQuickSendTo.
  ///
  /// In en, this message translates to:
  /// **'Send money with UPI to {name}'**
  String a11yQuickSendTo(String name);

  /// No description provided for @a11ySendMoney.
  ///
  /// In en, this message translates to:
  /// **'Send money'**
  String get a11ySendMoney;

  /// No description provided for @a11yReceiveMoney.
  ///
  /// In en, this message translates to:
  /// **'Receive money'**
  String get a11yReceiveMoney;

  /// No description provided for @backupNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'You are not signed in.'**
  String get backupNotSignedIn;

  /// No description provided for @backupNoDeviceSnapshot.
  ///
  /// In en, this message translates to:
  /// **'No snapshot is stored on this device yet. One is taken automatically once a day.'**
  String get backupNoDeviceSnapshot;

  /// No description provided for @backupRestoreFromDeviceSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Restore From Device Snapshot'**
  String get backupRestoreFromDeviceSnapshot;

  /// No description provided for @backupRestoreFromDeviceSnapshotExplain.
  ///
  /// In en, this message translates to:
  /// **'Your app keeps an automatic copy of the whole account on this device, refreshed once a day. Use it if something was deleted by accident.'**
  String get backupRestoreFromDeviceSnapshotExplain;

  /// No description provided for @backupHadNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'Backup had no transactions to restore'**
  String get backupHadNoTransactions;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String restoreFailed(String error);

  /// No description provided for @restoredFromBackup.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Restored 1 transaction} other{Restored {count} transactions}} from backup'**
  String restoredFromBackup(int count);

  /// No description provided for @restoredFromPreservedBackup.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Restored 1 transaction} other{Restored {count} transactions}} from backup — the preserved pre-deletion copy'**
  String restoredFromPreservedBackup(int count);

  /// No description provided for @handlesRestoringLocalCacheMerge.
  ///
  /// In en, this message translates to:
  /// **'This handles restoring from local cache. Merge restored transactions with current data?'**
  String get handlesRestoringLocalCacheMerge;

  /// No description provided for @homeWidget.
  ///
  /// In en, this message translates to:
  /// **'Home Widget'**
  String get homeWidget;

  /// No description provided for @howCategoryCountsTowardSmart.
  ///
  /// In en, this message translates to:
  /// **'How this category counts toward your Smart Daily Limit. Ignored categories (e.g. investments/SIPs) never reduce it.'**
  String get howCategoryCountsTowardSmart;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @idealIncome.
  ///
  /// In en, this message translates to:
  /// **'Ideal Income'**
  String get idealIncome;

  /// No description provided for @imageSelected.
  ///
  /// In en, this message translates to:
  /// **'No image selected'**
  String get imageSelected;

  /// No description provided for @importAnyway.
  ///
  /// In en, this message translates to:
  /// **'Import Anyway'**
  String get importAnyway;

  /// No description provided for @importBankCSV.
  ///
  /// In en, this message translates to:
  /// **'Import Bank CSV'**
  String get importBankCSV;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// No description provided for @imported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get imported;

  /// No description provided for @incomeModeBlend.
  ///
  /// In en, this message translates to:
  /// **'Auto – Blend (3-month average)'**
  String get incomeModeBlend;

  /// No description provided for @incomeModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get incomeModeManual;

  /// No description provided for @incomeModeSalaryWindow.
  ///
  /// In en, this message translates to:
  /// **'Auto – Salary window (current month first week or previous month last working day)'**
  String get incomeModeSalaryWindow;

  /// No description provided for @incomeSource.
  ///
  /// In en, this message translates to:
  /// **'Income Source'**
  String get incomeSource;

  /// No description provided for @insurancePolicies.
  ///
  /// In en, this message translates to:
  /// **'Insurance Policies'**
  String get insurancePolicies;

  /// No description provided for @invalidSubscriptionDataFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid subscription data format'**
  String get invalidSubscriptionDataFormat;

  /// No description provided for @inviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite Friends'**
  String get inviteFriends;

  /// No description provided for @inviteFriendsGetProFree.
  ///
  /// In en, this message translates to:
  /// **'Invite friends, get Pro free'**
  String get inviteFriendsGetProFree;

  /// No description provided for @issuesFound.
  ///
  /// In en, this message translates to:
  /// **'No issues found'**
  String get issuesFound;

  /// No description provided for @keepPlan.
  ///
  /// In en, this message translates to:
  /// **'Keep Plan'**
  String get keepPlan;

  /// No description provided for @keepTrial.
  ///
  /// In en, this message translates to:
  /// **'Keep Trial'**
  String get keepTrial;

  /// No description provided for @keywordsYetTapAdd.
  ///
  /// In en, this message translates to:
  /// **'No keywords yet — tap Add'**
  String get keywordsYetTapAdd;

  /// No description provided for @ledgerCopiedClipboard.
  ///
  /// In en, this message translates to:
  /// **'Ledger copied to clipboard'**
  String get ledgerCopiedClipboard;

  /// No description provided for @ledgerEntries.
  ///
  /// In en, this message translates to:
  /// **'No ledger entries'**
  String get ledgerEntries;

  /// No description provided for @limit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get limit;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @linkTransaction.
  ///
  /// In en, this message translates to:
  /// **'Link Transaction'**
  String get linkTransaction;

  /// No description provided for @linkTransaction2.
  ///
  /// In en, this message translates to:
  /// **'Link Transaction?'**
  String get linkTransaction2;

  /// No description provided for @linked.
  ///
  /// In en, this message translates to:
  /// **'LINKED'**
  String get linked;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @lentAmountLeft.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String lentAmountLeft(Object amount);

  /// No description provided for @lentAlreadySettled.
  ///
  /// In en, this message translates to:
  /// **'Already Settled'**
  String get lentAlreadySettled;

  /// No description provided for @lentBorrowedFrom.
  ///
  /// In en, this message translates to:
  /// **'Borrowed from'**
  String get lentBorrowedFrom;

  /// No description provided for @lentGrandSum.
  ///
  /// In en, this message translates to:
  /// **'Grand Sum ({label})'**
  String lentGrandSum(Object label);

  /// No description provided for @lentEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track what you lend to friends and what you borrow from them, and settle up in one tap.'**
  String get lentEmptySubtitle;

  /// No description provided for @lentLentTo.
  ///
  /// In en, this message translates to:
  /// **'Lent to'**
  String get lentLentTo;

  /// No description provided for @lentNetOwedToYou.
  ///
  /// In en, this message translates to:
  /// **'Net Owed to You'**
  String get lentNetOwedToYou;

  /// No description provided for @lentNetYouOwe.
  ///
  /// In en, this message translates to:
  /// **'Net You Owe'**
  String get lentNetYouOwe;

  /// No description provided for @lentNoActiveRecords.
  ///
  /// In en, this message translates to:
  /// **'No active lent money records.'**
  String get lentNoActiveRecords;

  /// No description provided for @lentOwedToYou.
  ///
  /// In en, this message translates to:
  /// **'Owed to You'**
  String get lentOwedToYou;

  /// No description provided for @lentPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get lentPending;

  /// No description provided for @lentRepay.
  ///
  /// In en, this message translates to:
  /// **'Repay'**
  String get lentRepay;

  /// No description provided for @lentRepaid.
  ///
  /// In en, this message translates to:
  /// **'Repaid {amount}'**
  String lentRepaid(Object amount);

  /// No description provided for @lentSelectEntryDetails.
  ///
  /// In en, this message translates to:
  /// **'Select an entry to view details'**
  String get lentSelectEntryDetails;

  /// No description provided for @lentSettle.
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get lentSettle;

  /// No description provided for @lentSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get lentSettled;

  /// No description provided for @lentYouOwe.
  ///
  /// In en, this message translates to:
  /// **'You Owe'**
  String get lentYouOwe;

  /// No description provided for @loanBalanceCol.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get loanBalanceCol;

  /// No description provided for @loanInterestCol.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get loanInterestCol;

  /// No description provided for @loanMonthCol.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get loanMonthCol;

  /// No description provided for @loanMonthlyAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount}/mo'**
  String loanMonthlyAmount(Object amount);

  /// No description provided for @loanMonthsPaidOf.
  ///
  /// In en, this message translates to:
  /// **'{paid}/{total} mo paid'**
  String loanMonthsPaidOf(Object paid, Object total);

  /// No description provided for @loanOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding: {amount}'**
  String loanOutstanding(Object amount);

  /// No description provided for @loanPercentPaid.
  ///
  /// In en, this message translates to:
  /// **'{percent}% paid'**
  String loanPercentPaid(Object percent);

  /// No description provided for @loanPrincipalCol.
  ///
  /// In en, this message translates to:
  /// **'Principal'**
  String get loanPrincipalCol;

  /// No description provided for @loanRatePerAnnum.
  ///
  /// In en, this message translates to:
  /// **'{type} • {rate}% p.a.'**
  String loanRatePerAnnum(Object rate, Object type);

  /// No description provided for @loanScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} — Schedule'**
  String loanScheduleTitle(Object name);

  /// No description provided for @loanStartedOn.
  ///
  /// In en, this message translates to:
  /// **'Started {date}'**
  String loanStartedOn(Object date);

  /// No description provided for @loanTotalInterest.
  ///
  /// In en, this message translates to:
  /// **'Total interest: {amount}'**
  String loanTotalInterest(Object amount);

  /// No description provided for @loanTracker.
  ///
  /// In en, this message translates to:
  /// **'Loan Tracker'**
  String get loanTracker;

  /// No description provided for @loansTrackedYet.
  ///
  /// In en, this message translates to:
  /// **'No loans tracked yet'**
  String get loansTrackedYet;

  /// No description provided for @localBackupFoundTapBackup.
  ///
  /// In en, this message translates to:
  /// **'No local backup found. Tap \'Backup Data\' first.'**
  String get localBackupFoundTapBackup;

  /// No description provided for @logged.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get logged;

  /// No description provided for @loseProAccessImmediatelyCannot.
  ///
  /// In en, this message translates to:
  /// **'You will lose Pro access immediately. This cannot be undone.'**
  String get loseProAccessImmediatelyCannot;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription;

  /// No description provided for @manageUsers.
  ///
  /// In en, this message translates to:
  /// **'Manage Users'**
  String get manageUsers;

  /// No description provided for @manageVisibility.
  ///
  /// In en, this message translates to:
  /// **'Manage Visibility'**
  String get manageVisibility;

  /// No description provided for @manualMonthlyIncome.
  ///
  /// In en, this message translates to:
  /// **'Manual Monthly Income'**
  String get manualMonthlyIncome;

  /// No description provided for @markPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark Paid'**
  String get markPaid;

  /// No description provided for @markPaid2.
  ///
  /// In en, this message translates to:
  /// **'Mark as Paid?'**
  String get markPaid2;

  /// No description provided for @masterToggleOffNothingPosted.
  ///
  /// In en, this message translates to:
  /// **'Master toggle is off — nothing will be posted until you turn it back on.'**
  String get masterToggleOffNothingPosted;

  /// No description provided for @matchCSVHeadersAppFields.
  ///
  /// In en, this message translates to:
  /// **'Match CSV headers to app fields'**
  String get matchCSVHeadersAppFields;

  /// No description provided for @migrate.
  ///
  /// In en, this message translates to:
  /// **'Migrate to:'**
  String get migrate;

  /// No description provided for @migrateDelete.
  ///
  /// In en, this message translates to:
  /// **'Migrate & Delete'**
  String get migrateDelete;

  /// No description provided for @missingRecurringPayment.
  ///
  /// In en, this message translates to:
  /// **'Missing Recurring Payment'**
  String get missingRecurringPayment;

  /// No description provided for @monthlyCommitment.
  ///
  /// In en, this message translates to:
  /// **'Monthly Commitment'**
  String get monthlyCommitment;

  /// No description provided for @monthlyEMI.
  ///
  /// In en, this message translates to:
  /// **'Monthly EMI'**
  String get monthlyEMI;

  /// No description provided for @newCategory2.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory2;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsYet;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @openUPIApp.
  ///
  /// In en, this message translates to:
  /// **'Open UPI App'**
  String get openUPIApp;

  /// No description provided for @opening.
  ///
  /// In en, this message translates to:
  /// **'Opening: '**
  String get opening;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @out.
  ///
  /// In en, this message translates to:
  /// **' Out'**
  String get out;

  /// No description provided for @out2.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get out2;

  /// No description provided for @outstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstanding;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @payViaUPI.
  ///
  /// In en, this message translates to:
  /// **'Pay via UPI'**
  String get payViaUPI;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistory;

  /// No description provided for @paymentHistoryLinkedYet.
  ///
  /// In en, this message translates to:
  /// **'No payment history linked yet.'**
  String get paymentHistoryLinkedYet;

  /// No description provided for @paymentMode.
  ///
  /// In en, this message translates to:
  /// **'Payment Mode'**
  String get paymentMode;

  /// No description provided for @paymentSettings.
  ///
  /// In en, this message translates to:
  /// **'Payment Settings'**
  String get paymentSettings;

  /// No description provided for @pendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No Pending Requests'**
  String get pendingRequests;

  /// No description provided for @pleaseEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get pleaseEnterValidAmount;

  /// No description provided for @policies.
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get policies;

  /// No description provided for @policiesAdded.
  ///
  /// In en, this message translates to:
  /// **'No policies added'**
  String get policiesAdded;

  /// No description provided for @preferSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get preferSay;

  /// No description provided for @previewingFirst5Rows.
  ///
  /// In en, this message translates to:
  /// **'Previewing first 5 rows:'**
  String get previewingFirst5Rows;

  /// No description provided for @proStatus.
  ///
  /// In en, this message translates to:
  /// **'Pro Status:'**
  String get proStatus;

  /// No description provided for @proSubscriptionBeenCancelled.
  ///
  /// In en, this message translates to:
  /// **'Your Pro subscription has been cancelled.'**
  String get proSubscriptionBeenCancelled;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get progress;

  /// No description provided for @properties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get properties;

  /// No description provided for @propertiesAdded.
  ///
  /// In en, this message translates to:
  /// **'No properties added'**
  String get propertiesAdded;

  /// No description provided for @quickOverview.
  ///
  /// In en, this message translates to:
  /// **'Quick Overview'**
  String get quickOverview;

  /// No description provided for @reImport.
  ///
  /// In en, this message translates to:
  /// **'Re-import'**
  String get reImport;

  /// No description provided for @reImportTransactions.
  ///
  /// In en, this message translates to:
  /// **'Re-import Transactions'**
  String get reImportTransactions;

  /// No description provided for @realEstate.
  ///
  /// In en, this message translates to:
  /// **'Real Estate'**
  String get realEstate;

  /// No description provided for @receiptScanner.
  ///
  /// In en, this message translates to:
  /// **'Receipt Scanner'**
  String get receiptScanner;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get recordPayment;

  /// No description provided for @recurringAutoPayHint.
  ///
  /// In en, this message translates to:
  /// **'When due, a transaction is created automatically.'**
  String get recurringAutoPayHint;

  /// No description provided for @recurringCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get recurringCategoryLabel;

  /// No description provided for @recurringFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get recurringFrequencyLabel;

  /// No description provided for @recurringManualPayHint.
  ///
  /// In en, this message translates to:
  /// **'Remind me when due — I\'ll mark it paid manually.'**
  String get recurringManualPayHint;

  /// No description provided for @recurringNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. Netflix)'**
  String get recurringNameLabel;

  /// No description provided for @recurringRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get recurringRequired;

  /// No description provided for @recurringSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save. Please try again.'**
  String get recurringSaveFailed;

  /// No description provided for @recurringEditSubscription.
  ///
  /// In en, this message translates to:
  /// **'Edit Subscription'**
  String get recurringEditSubscription;

  /// No description provided for @recurringEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit subscription'**
  String get recurringEditTooltip;

  /// No description provided for @recurringNewSubscription.
  ///
  /// In en, this message translates to:
  /// **'New Subscription'**
  String get recurringNewSubscription;

  /// No description provided for @recurringNextPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Next Payment:'**
  String get recurringNextPaymentLabel;

  /// No description provided for @recurringPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'PAID'**
  String get recurringPaidLabel;

  /// No description provided for @recurringPausedLabel.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get recurringPausedLabel;

  /// No description provided for @recurringPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get recurringPendingLabel;

  /// No description provided for @referralCODE.
  ///
  /// In en, this message translates to:
  /// **'YOUR REFERRAL CODE'**
  String get referralCODE;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove entry?'**
  String get removeEntry;

  /// No description provided for @removeEntry2.
  ///
  /// In en, this message translates to:
  /// **'Remove this entry?'**
  String get removeEntry2;

  /// No description provided for @removeLoan.
  ///
  /// In en, this message translates to:
  /// **'Remove Loan'**
  String get removeLoan;

  /// No description provided for @removeLoanItsLinkedRecurring.
  ///
  /// In en, this message translates to:
  /// **'This will remove the loan and its linked recurring payment (if any).'**
  String get removeLoanItsLinkedRecurring;

  /// No description provided for @removePolicy.
  ///
  /// In en, this message translates to:
  /// **'Remove this policy?'**
  String get removePolicy;

  /// No description provided for @removeProperty.
  ///
  /// In en, this message translates to:
  /// **'Remove this property?'**
  String get removeProperty;

  /// No description provided for @removeVehicle.
  ///
  /// In en, this message translates to:
  /// **'Remove this vehicle?'**
  String get removeVehicle;

  /// No description provided for @repaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Repayment History'**
  String get repaymentHistory;

  /// No description provided for @repaymentsRecordedYet.
  ///
  /// In en, this message translates to:
  /// **'No repayments recorded yet.'**
  String get repaymentsRecordedYet;

  /// No description provided for @requestReviewedAdminNotifiedOnce.
  ///
  /// In en, this message translates to:
  /// **'Your request will be reviewed by the admin. You will be notified once approved.'**
  String get requestReviewedAdminNotifiedOnce;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreData.
  ///
  /// In en, this message translates to:
  /// **'Restore Data'**
  String get restoreData;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @salaryDetected.
  ///
  /// In en, this message translates to:
  /// **'Salary Detected'**
  String get salaryDetected;

  /// No description provided for @save33.
  ///
  /// In en, this message translates to:
  /// **'SAVE 33%'**
  String get save33;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @saveTRANSACTION.
  ///
  /// In en, this message translates to:
  /// **'SAVE TRANSACTION'**
  String get saveTRANSACTION;

  /// No description provided for @savedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved locally'**
  String get savedLocally;

  /// No description provided for @savingRate.
  ///
  /// In en, this message translates to:
  /// **'Saving rate'**
  String get savingRate;

  /// No description provided for @savingsChallenges.
  ///
  /// In en, this message translates to:
  /// **'Savings Challenges'**
  String get savingsChallenges;

  /// No description provided for @savingsTarget.
  ///
  /// In en, this message translates to:
  /// **'Savings Target'**
  String get savingsTarget;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan Again'**
  String get scanAgain;

  /// No description provided for @scanQR.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQR;

  /// No description provided for @scannedTextSave.
  ///
  /// In en, this message translates to:
  /// **'No scanned text to save.'**
  String get scannedTextSave;

  /// No description provided for @securityPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Security & Privacy'**
  String get securityPrivacy;

  /// No description provided for @selectCategory2.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get selectCategory2;

  /// No description provided for @selectColumn.
  ///
  /// In en, this message translates to:
  /// **'Select Column'**
  String get selectColumn;

  /// No description provided for @selectCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get selectCurrency;

  /// No description provided for @selectGender.
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get selectGender;

  /// No description provided for @selectSubscriptionViewDetails.
  ///
  /// In en, this message translates to:
  /// **'Select a subscription to view details'**
  String get selectSubscriptionViewDetails;

  /// No description provided for @selectTransactionViewDetails.
  ///
  /// In en, this message translates to:
  /// **'Select a transaction to view details'**
  String get selectTransactionViewDetails;

  /// No description provided for @setAgeFirst.
  ///
  /// In en, this message translates to:
  /// **'Set Your Age First'**
  String get setAgeFirst;

  /// No description provided for @setSavingsPurchaseGoalTrack.
  ///
  /// In en, this message translates to:
  /// **'Set a savings or purchase goal\\nand track your progress.'**
  String get setSavingsPurchaseGoalTrack;

  /// No description provided for @shareReport.
  ///
  /// In en, this message translates to:
  /// **'Share Report'**
  String get shareReport;

  /// No description provided for @shareSetAsideBeforeAI.
  ///
  /// In en, this message translates to:
  /// **'This share is set aside before your AI Insights daily spending limit is calculated.'**
  String get shareSetAsideBeforeAI;

  /// No description provided for @signConventionError.
  ///
  /// In en, this message translates to:
  /// **'Sign Convention Error'**
  String get signConventionError;

  /// No description provided for @signCorrected.
  ///
  /// In en, this message translates to:
  /// **'Sign corrected'**
  String get signCorrected;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @skipPayment.
  ///
  /// In en, this message translates to:
  /// **'Skip this Payment'**
  String get skipPayment;

  /// No description provided for @skipPayment2.
  ///
  /// In en, this message translates to:
  /// **'Skip this payment?'**
  String get skipPayment2;

  /// No description provided for @smartMode.
  ///
  /// In en, this message translates to:
  /// **'Smart Mode'**
  String get smartMode;

  /// No description provided for @smartModeVisibilityFollowsAge.
  ///
  /// In en, this message translates to:
  /// **'Smart Mode is on — visibility follows your age recommendations. Turn it off to customize manually.'**
  String get smartModeVisibilityFollowsAge;

  /// No description provided for @smartSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Smart Suggestions'**
  String get smartSuggestions;

  /// No description provided for @smsPermissionPreviouslyDeniedPlease.
  ///
  /// In en, this message translates to:
  /// **'SMS permission was previously denied. Please enable \"SMS\" permission in app settings to import transactions.'**
  String get smsPermissionPreviouslyDeniedPlease;

  /// No description provided for @smsPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'SMS Permission Required'**
  String get smsPermissionRequired;

  /// No description provided for @smsTransactionsMatchingKeywordAuto.
  ///
  /// In en, this message translates to:
  /// **'SMS transactions matching any keyword are auto-tagged to that category. Grey chips are defaults (read-only).'**
  String get smsTransactionsMatchingKeywordAuto;

  /// No description provided for @spendingHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Spending Heatmap'**
  String get spendingHeatmap;

  /// No description provided for @spendingPersonality.
  ///
  /// In en, this message translates to:
  /// **'Your Spending Personality'**
  String get spendingPersonality;

  /// No description provided for @spentOtherItems.
  ///
  /// In en, this message translates to:
  /// **'Spent on other items'**
  String get spentOtherItems;

  /// No description provided for @splitBill.
  ///
  /// In en, this message translates to:
  /// **'Split a Bill'**
  String get splitBill;

  /// No description provided for @splashContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get splashContinue;

  /// No description provided for @splashGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get splashGetStarted;

  /// No description provided for @splashHeadlineFillWallet.
  ///
  /// In en, this message translates to:
  /// **'Fill Your Wallet'**
  String get splashHeadlineFillWallet;

  /// No description provided for @splashHeadlineSaveMoney.
  ///
  /// In en, this message translates to:
  /// **'Save your Money'**
  String get splashHeadlineSaveMoney;

  /// No description provided for @splashHeadlineTrackExpenses.
  ///
  /// In en, this message translates to:
  /// **'Track Your Expenses'**
  String get splashHeadlineTrackExpenses;

  /// No description provided for @splashLetsStart.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Start'**
  String get splashLetsStart;

  /// No description provided for @splashSubtitleFillWallet.
  ///
  /// In en, this message translates to:
  /// **'Take control of your earnings by working smarter and building your own success story.'**
  String get splashSubtitleFillWallet;

  /// No description provided for @splashSubtitleSaveMoney.
  ///
  /// In en, this message translates to:
  /// **'Discover smart ways to manage your finances and grow your savings—start making your money work for you, effortlessly and securely.'**
  String get splashSubtitleSaveMoney;

  /// No description provided for @splashSubtitleTrackExpenses.
  ///
  /// In en, this message translates to:
  /// **'Monitor your spending habits effortlessly and take control of your financial goals in real time.'**
  String get splashSubtitleTrackExpenses;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @startChallenge.
  ///
  /// In en, this message translates to:
  /// **'Start Challenge'**
  String get startChallenge;

  /// No description provided for @startFirstChallenge.
  ///
  /// In en, this message translates to:
  /// **'Start your first challenge 🎯'**
  String get startFirstChallenge;

  /// No description provided for @submitVerification.
  ///
  /// In en, this message translates to:
  /// **'Submit for Verification'**
  String get submitVerification;

  /// No description provided for @subscriptionDataFound.
  ///
  /// In en, this message translates to:
  /// **'Subscription data not found'**
  String get subscriptionDataFound;

  /// No description provided for @subscriptionDetails.
  ///
  /// In en, this message translates to:
  /// **'Subscription Details'**
  String get subscriptionDetails;

  /// No description provided for @subscriptionFound.
  ///
  /// In en, this message translates to:
  /// **'Subscription not found'**
  String get subscriptionFound;

  /// No description provided for @subscriptionsYet.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet'**
  String get subscriptionsYet;

  /// No description provided for @suggestedRules.
  ///
  /// In en, this message translates to:
  /// **'Suggested Rules'**
  String get suggestedRules;

  /// No description provided for @suggestionsYetAddDataGet.
  ///
  /// In en, this message translates to:
  /// **'No suggestions yet. Add data to get insights!'**
  String get suggestionsYetAddDataGet;

  /// No description provided for @superchargeFinancialControlPremiumFeat.
  ///
  /// In en, this message translates to:
  /// **'Supercharge your financial control with premium features designed for growth.'**
  String get superchargeFinancialControlPremiumFeat;

  /// No description provided for @sureWantCancelLoseAccess.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel? You will lose access to Pro features at the end of the billing period.'**
  String get sureWantCancelLoseAccess;

  /// No description provided for @sureWantDeleteSubscriptionPast.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this subscription? Past transactions will remain, but future reminders will stop.'**
  String get sureWantDeleteSubscriptionPast;

  /// No description provided for @sureWantDeleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this transaction?'**
  String get sureWantDeleteTransaction;

  /// No description provided for @tapAddFirstEntry.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first entry'**
  String get tapAddFirstEntry;

  /// No description provided for @tapResolve.
  ///
  /// In en, this message translates to:
  /// **'Tap to resolve'**
  String get tapResolve;

  /// No description provided for @tapTrackCardOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Tap + to track your card outstanding'**
  String get tapTrackCardOutstanding;

  /// No description provided for @tapTrackLifeInsuranceULIPs.
  ///
  /// In en, this message translates to:
  /// **'Tap + to track life insurance and ULIPs'**
  String get tapTrackLifeInsuranceULIPs;

  /// No description provided for @tapTrackRealEstate.
  ///
  /// In en, this message translates to:
  /// **'Tap + to track your real estate'**
  String get tapTrackRealEstate;

  /// No description provided for @tapTrackVehicles.
  ///
  /// In en, this message translates to:
  /// **'Tap + to track your vehicles'**
  String get tapTrackVehicles;

  /// No description provided for @taxSummaryPDF.
  ///
  /// In en, this message translates to:
  /// **'Tax Summary PDF'**
  String get taxSummaryPDF;

  /// No description provided for @theseNonBillExpensesRent.
  ///
  /// In en, this message translates to:
  /// **'These are your non-bill expenses. Rent, EMIs, bills, subscriptions and other fixed payments are excluded — open the excluded list below to see them.'**
  String get theseNonBillExpensesRent;

  /// No description provided for @topMerchants.
  ///
  /// In en, this message translates to:
  /// **'Top Merchants'**
  String get topMerchants;

  /// No description provided for @totalNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Total Net Worth'**
  String get totalNetWorth;

  /// No description provided for @totalOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Total Outstanding'**
  String get totalOutstanding;

  /// No description provided for @trackNetflixRentSpotifyEtc.
  ///
  /// In en, this message translates to:
  /// **'Track Netflix, Rent, Spotify, etc.'**
  String get trackNetflixRentSpotifyEtc;

  /// No description provided for @trackingOnly.
  ///
  /// In en, this message translates to:
  /// **'Tracking only'**
  String get trackingOnly;

  /// No description provided for @transactionAlreadyImportedCreateDuplic.
  ///
  /// In en, this message translates to:
  /// **'This transaction was already imported. Create a duplicate?'**
  String get transactionAlreadyImportedCreateDuplic;

  /// No description provided for @transactionAudit.
  ///
  /// In en, this message translates to:
  /// **'Transaction Audit'**
  String get transactionAudit;

  /// No description provided for @transactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactionDetails;

  /// No description provided for @transactionIDShownUPIApp.
  ///
  /// In en, this message translates to:
  /// **'The transaction ID is shown in your UPI app after payment.'**
  String get transactionIDShownUPIApp;

  /// No description provided for @transactionsFound.
  ///
  /// In en, this message translates to:
  /// **'No transactions found.'**
  String get transactionsFound;

  /// No description provided for @typeUPIIDInstead.
  ///
  /// In en, this message translates to:
  /// **'Type UPI ID instead'**
  String get typeUPIIDInstead;

  /// No description provided for @unlockProAccess.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pro Access'**
  String get unlockProAccess;

  /// No description provided for @updateDueDateCreatingTransaction.
  ///
  /// In en, this message translates to:
  /// **'This will update the due date and creating a transaction record.'**
  String get updateDueDateCreatingTransaction;

  /// No description provided for @upgradeProNow.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro Now'**
  String get upgradeProNow;

  /// No description provided for @upgradeRequestCurrentlyUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Your upgrade request is currently under review by the administration. You will be notified once your account is upgraded to Pro.'**
  String get upgradeRequestCurrentlyUnderReview;

  /// No description provided for @upiID.
  ///
  /// In en, this message translates to:
  /// **'Your UPI ID'**
  String get upiID;

  /// No description provided for @upiQRCodeTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Not a UPI QR code — try again'**
  String get upiQRCodeTryAgain;

  /// No description provided for @userLogged.
  ///
  /// In en, this message translates to:
  /// **'User not logged in'**
  String get userLogged;

  /// No description provided for @usersAskedPayUPIID.
  ///
  /// In en, this message translates to:
  /// **'Users will be asked to pay this UPI ID and enter the resulting transaction ID.'**
  String get usersAskedPayUPIID;

  /// No description provided for @usersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get usersFound;

  /// No description provided for @vehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vehicles;

  /// No description provided for @vehicles2.
  ///
  /// In en, this message translates to:
  /// **'Your Vehicles'**
  String get vehicles2;

  /// No description provided for @vehiclesAdded.
  ///
  /// In en, this message translates to:
  /// **'No vehicles added'**
  String get vehiclesAdded;

  /// No description provided for @verificationProgress.
  ///
  /// In en, this message translates to:
  /// **'Verification In Progress'**
  String get verificationProgress;

  /// No description provided for @viewAdvancedCategoryTrends.
  ///
  /// In en, this message translates to:
  /// **'View Advanced Category Trends'**
  String get viewAdvancedCategoryTrends;

  /// No description provided for @visibleAssets.
  ///
  /// In en, this message translates to:
  /// **'No visible assets'**
  String get visibleAssets;

  /// No description provided for @wealthBuilder.
  ///
  /// In en, this message translates to:
  /// **'Wealth Builder'**
  String get wealthBuilder;

  /// No description provided for @wealthBuilderPersonalisesEveryTarget.
  ///
  /// In en, this message translates to:
  /// **'Wealth Builder personalises every target — emergency fund, equity allocation, retirement corpus — based on your age.\\n\\nAdd your date of birth in your profile to get started.'**
  String get wealthBuilderPersonalisesEveryTarget;

  /// No description provided for @wealthsync.
  ///
  /// In en, this message translates to:
  /// **'💰 WealthSync'**
  String get wealthsync;

  /// No description provided for @wealthsyncNeedsCameraAccessScan.
  ///
  /// In en, this message translates to:
  /// **'WealthSync needs camera access to scan UPI QR codes. Open Settings to grant it.'**
  String get wealthsyncNeedsCameraAccessScan;

  /// No description provided for @wealthsyncWeb.
  ///
  /// In en, this message translates to:
  /// **'WealthSync Web'**
  String get wealthsyncWeb;

  /// No description provided for @whatShouldEarnStayTrack.
  ///
  /// In en, this message translates to:
  /// **'What you should earn to stay on track'**
  String get whatShouldEarnStayTrack;

  /// No description provided for @whenFriendSignsUpCode.
  ///
  /// In en, this message translates to:
  /// **'When a friend signs up with your code, you both get +30 days of Pro — and every additional friend adds 30 more.'**
  String get whenFriendSignsUpCode;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
