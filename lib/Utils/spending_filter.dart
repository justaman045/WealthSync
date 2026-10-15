import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Utils/wealth_math.dart';

/// A month's expenses split into the three buckets the AI daily limit cares
/// about: discretionary ("other items"), fixed/committed (bills, rent, EMIs,
/// subscriptions …), and ignored (investments/SIPs/transfers the user excluded
/// from the limit).
///
/// The split uses [resolveDailyLimitRole] — the same resolver the daily limit
/// card uses — so the totals here always reconcile with the card's
/// "spent … on other items" figure.
class MonthlyExpenseSplit {
  final List<TransactionModel> discretionary;
  final List<TransactionModel> fixed;
  final List<TransactionModel> ignored;

  const MonthlyExpenseSplit({
    required this.discretionary,
    required this.fixed,
    required this.ignored,
  });

  double get discretionaryTotal =>
      discretionary.fold(0.0, (sum, tx) => sum + tx.amount.abs());

  double get fixedTotal => fixed.fold(0.0, (sum, tx) => sum + tx.amount.abs());

  double get ignoredTotal =>
      ignored.fold(0.0, (sum, tx) => sum + tx.amount.abs());

  int get discretionaryCount => discretionary.length;
  int get fixedCount => fixed.length;
  int get ignoredCount => ignored.length;
}

/// True when [tx] is an expense paid by [uid] inside [month]'s calendar month.
///
/// Expenses carry `senderId == uid` (income carries `recipientId == uid`), so
/// this also excludes income without inspecting the amount sign.
bool _isExpenseInMonth(TransactionModel tx, String uid, DateTime month) =>
    tx.senderId == uid &&
    tx.date.year == month.year &&
    tx.date.month == month.month;

/// Splits [all] into the discretionary, fixed and ignored expenses paid by
/// [uid] during [month], each sorted newest first. The three lists partition
/// every expense of that month — together they account for all of the user's
/// spending.
MonthlyExpenseSplit splitMonthlyExpenses(
  List<TransactionModel> all, {
  required String uid,
  required DateTime month,
  Map<String, String> treatmentOverrides = const {},
}) {
  final discretionary = <TransactionModel>[];
  final fixed = <TransactionModel>[];
  final ignored = <TransactionModel>[];
  for (final tx in all) {
    if (!_isExpenseInMonth(tx, uid, month)) continue;
    switch (resolveDailyLimitRole(
      tx.category,
      treatmentOverrides: treatmentOverrides,
    )) {
      case DailyLimitRole.fixed:
        fixed.add(tx);
      case DailyLimitRole.ignored:
        ignored.add(tx);
      case DailyLimitRole.variable:
        discretionary.add(tx);
    }
  }
  int byDateDesc(TransactionModel a, TransactionModel b) =>
      b.date.compareTo(a.date);
  discretionary.sort(byDateDesc);
  fixed.sort(byDateDesc);
  ignored.sort(byDateDesc);
  return MonthlyExpenseSplit(
    discretionary: discretionary,
    fixed: fixed,
    ignored: ignored,
  );
}
