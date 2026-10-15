import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Utils/wealth_math.dart';

/// A month's expenses split into the two buckets the AI daily limit cares
/// about: discretionary ("other items") and fixed/committed (bills, rent,
/// EMIs, subscriptions …).
///
/// The split uses [isFixedExpenseCategory] — the same classifier the daily
/// limit card uses — so the totals here always reconcile with the card's
/// "spent … on other items" figure.
class MonthlyExpenseSplit {
  final List<TransactionModel> discretionary;
  final List<TransactionModel> fixed;

  const MonthlyExpenseSplit({
    required this.discretionary,
    required this.fixed,
  });

  double get discretionaryTotal =>
      discretionary.fold(0.0, (sum, tx) => sum + tx.amount.abs());

  double get fixedTotal => fixed.fold(0.0, (sum, tx) => sum + tx.amount.abs());

  int get discretionaryCount => discretionary.length;
  int get fixedCount => fixed.length;
}

/// True when [tx] is an expense paid by [uid] inside [month]'s calendar month.
///
/// Expenses carry `senderId == uid` (income carries `recipientId == uid`), so
/// this also excludes income without inspecting the amount sign.
bool _isExpenseInMonth(TransactionModel tx, String uid, DateTime month) =>
    tx.senderId == uid &&
    tx.date.year == month.year &&
    tx.date.month == month.month;

/// Splits [all] into the discretionary and fixed expenses paid by [uid] during
/// [month], each sorted newest first. The two lists partition every expense of
/// that month — together they account for all of the user's spending.
MonthlyExpenseSplit splitMonthlyExpenses(
  List<TransactionModel> all, {
  required String uid,
  required DateTime month,
}) {
  final discretionary = <TransactionModel>[];
  final fixed = <TransactionModel>[];
  for (final tx in all) {
    if (!_isExpenseInMonth(tx, uid, month)) continue;
    if (isFixedExpenseCategory(tx.category)) {
      fixed.add(tx);
    } else {
      discretionary.add(tx);
    }
  }
  int byDateDesc(TransactionModel a, TransactionModel b) =>
      b.date.compareTo(a.date);
  discretionary.sort(byDateDesc);
  fixed.sort(byDateDesc);
  return MonthlyExpenseSplit(discretionary: discretionary, fixed: fixed);
}
