import 'package:money_control/Models/transaction.dart';

/// Aggregates for the home overview.
///
/// These live here (not in the controller) so month boundaries, tax handling
/// and the "same day last month" comparison are unit-tested without GetX,
/// Firestore or a widget tree.
class HomeMonthSummary {
  const HomeMonthSummary({
    required this.spend,
    required this.income,
    this.momPercent,
  });

  /// Money out this month-to-date, tax included.
  final double spend;

  /// Money in this month-to-date.
  final double income;

  /// Spending change versus the same day range last month, as a percentage.
  ///
  /// Null when there is nothing to compare against — no spending last month,
  /// or the 1st of the month (the comparable window is empty). The UI hides
  /// the chip rather than printing a meaningless +/-100%.
  final double? momPercent;

  /// Money kept this month (income minus spending). Can be negative.
  double get net => income - spend;

  bool get hasActivity => spend > 0 || income > 0;
}

/// Splits [txs] into this month's income/spending and the month-over-month
/// spending delta for [uid].
///
/// Only month-to-date is counted: a transaction dated later this month has not
/// happened yet, so including it would overstate the month and make the delta
/// swing every time a payment is scheduled.
///
/// A transaction where the user is both sender and recipient (a self-transfer)
/// is neither income nor spending.
HomeMonthSummary summarizeHomeMonth(
  Iterable<TransactionModel> txs, {
  required String uid,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final startThis = DateTime(today.year, today.month, 1);
  final startLast = DateTime(today.year, today.month - 1, 1);

  // Clamp the comparison day to the previous month's length. DateTime
  // normalises out-of-range days *forward* (Feb 31 becomes March 3), which
  // would silently widen the window on the 29th-31st.
  final lastMonthDays = DateTime(today.year, today.month, 0).day;
  final clampedDay = today.day > lastMonthDays ? lastMonthDays : today.day;
  // Exclusive end: the whole clamped day, so a 31 March comparison against
  // February stops on the 28th/29th instead of spilling into March.
  final sameDayLastMonthEnd = DateTime(
    startLast.year,
    startLast.month,
    clampedDay + 1,
  );

  var spend = 0.0;
  var income = 0.0;
  var lastSpend = 0.0;

  for (final tx in txs) {
    final isSender = tx.senderId == uid;
    final isRecipient = tx.recipientId == uid;
    // Neither id is this user (foreign doc), or both are (self-transfer).
    if (isSender == isRecipient) continue;

    final date = tx.date;
    // `total` is `amount - tax`, matching WealthService.calculateBankBalance.
    // Spending therefore includes the tax that actually left the account.
    if (isSender) {
      if (date.isAfter(today)) continue;
      final amount = -tx.total;
      if (!date.isBefore(startThis)) {
        spend += amount;
      } else if (!date.isBefore(startLast) &&
          date.isBefore(sameDayLastMonthEnd)) {
        lastSpend += amount;
      }
    } else if (!date.isBefore(startThis) && !date.isAfter(today)) {
      income += tx.total;
    }
  }

  final double? momPercent = (lastSpend <= 0 || clampedDay <= 1)
      ? null
      : (spend - lastSpend) / lastSpend * 100;

  return HomeMonthSummary(
    spend: spend,
    income: income,
    momPercent: momPercent,
  );
}

/// The [limit] most recent transactions for [uid].
///
/// Ordered by the transaction's own date (what the tile prints), not by
/// `createdAt`: a backdated entry used to jump to the top of the list wearing
/// an old date, while an entry recorded earlier but dated later sorted below
/// it. `createdAt` only breaks same-day ties.
List<TransactionModel> selectRecentTransactions(
  Iterable<TransactionModel> txs, {
  required String uid,
  int limit = 8,
}) {
  final mine = txs
      .where((tx) => tx.senderId == uid || tx.recipientId == uid)
      .toList();
  mine.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    final aCreated = a.createdAt;
    final bCreated = b.createdAt;
    if (aCreated == null || bCreated == null) {
      if (aCreated == null && bCreated == null) return 0;
      return aCreated == null ? 1 : -1;
    }
    return bCreated.compareTo(aCreated);
  });
  return mine.length > limit ? mine.sublist(0, limit) : mine;
}
