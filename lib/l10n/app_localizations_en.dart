// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Money Control';

  @override
  String get welcomeBack => 'Welcome back,';

  @override
  String get loginTitle => 'Login to your account';

  @override
  String get loginSubtitle => 'Welcome back! Please enter your details.';

  @override
  String get emailHint => 'Email Address';

  @override
  String get passwordHint => 'Password';

  @override
  String get loginButton => 'Login';

  @override
  String get googleLogin => 'Sign in with Google';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get signUp => 'Sign Up';

  @override
  String get home => 'Home';

  @override
  String get analytics => 'Analytics';

  @override
  String get transactions => 'Transactions';

  @override
  String get settings => 'Settings';

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get quickSend => 'Quick Send';

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
  String deleteCategoryContent(String category) {
    return 'Do you want to delete \'$category\'?\n\n• This will NOT delete existing transactions.\n• Category will simply be removed from your list.';
  }

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get transactionSaved => 'Transaction saved successfully';

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
  String welcomeUser(String name) {
    return 'Welcome, $name';
  }

  @override
  String get onboardingSubtitle =>
      'Let\'s set up your financial goals in 2 steps.';

  @override
  String get chooseCurrencyStep => '1. Choose Currency';

  @override
  String get setBudgetStep => '2. Set Monthly Budget';

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
}
