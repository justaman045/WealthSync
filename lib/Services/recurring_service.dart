import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Services/local_backup_service.dart';
import 'package:uuid/uuid.dart';

/// Advance a date by one calendar month, clamping the day to the last day of
/// the target month (e.g. Jan 31 → Feb 28, not Mar 3).
DateTime _clampedNextMonth(DateTime date) {
  final targetMonth = date.month == 12 ? 1 : date.month + 1;
  final targetYear = date.month == 12 ? date.year + 1 : date.year;
  final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
  return DateTime(targetYear, targetMonth, date.day.clamp(1, lastDay));
}

class RecurringService {
  static final RecurringService _instance = RecurringService._();
  RecurringService._();
  factory RecurringService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userEmail => _auth.currentUser?.email;

  // Add new subscription
  Future<void> addPayment(RecurringPayment payment) async {
    final email = _userEmail;
    if (email == null) return;

    await _db
        .collection('users')
        .doc(email)
        .collection('recurring_payments')
        .doc(payment.id)
        .set(payment.toMap());
  }

  // Delete subscription
  Future<void> deletePayment(String id) async {
    final email = _userEmail;
    if (email == null) return;

    await _db
        .collection('users')
        .doc(email)
        .collection('recurring_payments')
        .doc(id)
        .delete();
  }

  // One-shot fetch of subscriptions
  Future<List<RecurringPayment>> getPaymentsOnce() async {
    final email = _userEmail;
    if (email == null) return [];

    final snap = await _db
        .collection('users')
        .doc(email)
        .collection('recurring_payments')
        .get();

    final list = snap.docs.map((doc) {
      return RecurringPayment.fromMap(doc.id, doc.data());
    }).toList();

    list.sort((a, b) {
      int dateComp = a.nextDueDate.compareTo(b.nextDueDate);
      if (dateComp != 0) return dateComp;
      return b.amount.compareTo(a.amount);
    });

    return list;
  }

  // Stream of subscriptions
  Stream<List<RecurringPayment>> getPayments() {
    if (_paymentsController == null) {
      final controller = StreamController<List<RecurringPayment>>.broadcast();
      _paymentsController = controller;
      _firestoreSub = _paymentsFromFirestore().listen(
        (list) {
          _lastPayments = list;
          if (!controller.isClosed) controller.add(list);
        },
        onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        },
        onDone: () {
          if (!controller.isClosed) controller.close();
        },
      );
    }
    return _replayOnSubscribe(_paymentsController!.stream);
  }

  // A plain broadcast stream only forwards events emitted AFTER subscription,
  // so a StreamBuilder that attaches once data is already flowing would sit on
  // ConnectionState.waiting until the next Firestore change. Replay the latest
  // known value to every new subscriber so late-comers render immediately.
  Stream<List<RecurringPayment>> _replayOnSubscribe(
    Stream<List<RecurringPayment>> source,
  ) {
    late final StreamController<List<RecurringPayment>> controller;
    StreamSubscription<List<RecurringPayment>>? sub;
    controller = StreamController<List<RecurringPayment>>.broadcast(
      onListen: () {
        final last = _lastPayments;
        if (last != null) controller.add(last);
        sub = source.listen(
          (list) {
            if (!controller.isClosed) controller.add(list);
          },
          onError: (e) {
            if (!controller.isClosed) controller.addError(e);
          },
          onDone: () {
            if (!controller.isClosed) controller.close();
          },
        );
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  // Single shared Firestore listener. Multiple callers (the recurring screen's
  // getMonthlyTotal() and the controller) reuse one snapshots() subscription
  // instead of opening one per subscriber on low-end devices / poor networks.
  Stream<List<RecurringPayment>> _paymentsFromFirestore() {
    final email = _userEmail;
    if (email == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(email)
        .collection('recurring_payments')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            return RecurringPayment.fromMap(doc.id, doc.data());
          }).toList();

          list.sort((a, b) {
            int dateComp = a.nextDueDate.compareTo(b.nextDueDate);
            if (dateComp != 0) return dateComp;
            return b.amount.compareTo(a.amount);
          });

          return list;
        });
  }

  /// Drop the shared stream so the next [getPayments] call opens a fresh
  /// Firestore subscription (called on logout to avoid leaking the previous
  /// user's listener).
  static void resetCache() {
    final s = _instance;
    s._firestoreSub?.cancel();
    s._firestoreSub = null;
    s._lastPayments = null;
    s._paymentsController?.close();
    s._paymentsController = null;
  }

  /// Fan-out controller for the single shared Firestore listener — see
  /// [getPayments].
  StreamController<List<RecurringPayment>>? _paymentsController;

  /// Underlying Firestore snapshots subscription backing [_paymentsController].
  StreamSubscription<List<RecurringPayment>>? _firestoreSub;

  /// Latest value, replayed to late subscribers by [_replayOnSubscribe].
  List<RecurringPayment>? _lastPayments;

  // Calculate total monthly commitment
  // Calculate total monthly commitment (remaining to pay this month)
  Stream<double> getMonthlyTotal() {
    return getPayments().map((payments) {
      double total = 0;
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      for (var p in payments) {
        if (!p.isActive) continue;

        // Count if the next due date is within the current month, OR if it's overdue
        // (nextDueDate is in the past but payment hasn't been made yet)
        if (p.nextDueDate.year == now.year &&
            p.nextDueDate.month == now.month) {
          total += p.amount;
        } else if (p.nextDueDate.isBefore(startOfMonth)) {
          // Overdue: include in current month's obligations
          total += p.amount;
        }
      }
      return total;
    });
  }

  // Update subscription details
  Future<void> updatePayment(RecurringPayment payment) async {
    final email = _userEmail;
    if (email == null) return;

    await _db
        .collection('users')
        .doc(email)
        .collection('recurring_payments')
        .doc(payment.id)
        .update(payment.toMap());
  }

  // Toggle active status
  Future<void> togglePaymentStatus(
    String id,
    bool isActive, {
    DateTime? nextDueDate,
  }) async {
    final email = _userEmail;
    if (email == null) return;

    final Map<String, dynamic> updates = {'isActive': isActive};
    if (nextDueDate != null) {
      updates['nextDueDate'] = Timestamp.fromDate(nextDueDate);
    }

    await _db
        .collection('users')
        .doc(email)
        .collection('recurring_payments')
        .doc(id)
        .update(updates);
  }

  // Toggle auto-pay for a single payment. Writes only the autoPay flag so
  // processDuePayments stops (or starts) auto-deducting this bill.
  Future<void> toggleAutoPay(String id, bool autoPay) async {
    final email = _userEmail;
    if (email == null) return;

    await _db
        .collection('users')
        .doc(email)
        .collection('recurring_payments')
        .doc(id)
        .update({'autoPay': autoPay});
  }

  // Link an existing transaction to this payment and advance the next due
  // date by one cycle from the linked transaction's date. Both writes are
  // batched atomically so the bill reads as paid and shows the history entry.
  Future<void> linkTransaction({
    required RecurringPayment payment,
    required String transactionId,
  }) async {
    final user = _auth.currentUser;
    final email = _userEmail;
    if (user == null || email == null) return;

    final txSnap = await _db
        .collection('users')
        .doc(email)
        .collection('transactions')
        .doc(transactionId)
        .get();
    if (!txSnap.exists) return;

    final txDate = ((txSnap.data()?['date'] as dynamic)?.toDate()) ??
        DateTime.now();
    final nextDate = _advanceDateStatic(payment, txDate);

    final batch = _db.batch();

    batch.update(
      _db
          .collection('users')
          .doc(email)
          .collection('transactions')
          .doc(transactionId),
      {'recurringPaymentId': payment.id},
    );
    batch.update(
      _db
          .collection('users')
          .doc(email)
          .collection('recurring_payments')
          .doc(payment.id),
      {'nextDueDate': Timestamp.fromDate(nextDate)},
    );

    await batch.commit();
  }

  // Backfill recurringPaymentId onto auto-pay transactions that lost their
  // link (field missing or mismatched on legacy data). Matched by senderId,
  // the "Auto-payment for <title>" note and date window — safe because
  // auto-pay transactions are always created with exactly those fields.
  // The amount is NOT required to match: a subscription's price legitimately
  // changes over time, so legacy transactions carry older amounts. It is only
  // used as a tiebreaker when another active payment shares the same title.
  // Returns the number of transactions repaired.
  Future<int> repairUnlinkedTransactions(RecurringPayment payment) async {
    final user = _auth.currentUser;
    final email = _userEmail;
    if (user == null || email == null) return 0;

    final paymentsSnap = await _db
        .collection('users')
        .doc(email)
        .collection('recurring_payments')
        .get();
    final sameTitleCount = paymentsSnap.docs
        .where((p) => p.id != payment.id && p.data()['title'] == payment.title)
        .length;
    final ambiguousTitle = sameTitleCount > 0;

    final snapshot = await _db
        .collection('users')
        .doc(email)
        .collection('transactions')
        .where('senderId', isEqualTo: user.uid)
        .get();

    final notePrefix = 'auto-payment for ${payment.title.toLowerCase()}';
    final windowStart = payment.startDate.subtract(const Duration(days: 2));
    final docs = snapshot.docs.where((d) {
      final data = d.data();
      final linked = data['recurringPaymentId'];
      if (linked != null && linked.toString().isNotEmpty) return false;
      final note = (data['note'] as String?)?.toLowerCase() ?? '';
      if (!note.contains(notePrefix)) return false;
      // Duplicate title? Require an amount match too so transactions are not
      // attributed to the wrong payment.
      if (ambiguousTitle) {
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        if ((amount.abs() - payment.amount).abs() > 0.01) return false;
      }
      final date = (data['date'] as dynamic)?.toDate();
      if (date == null || date.isBefore(windowStart)) return false;
      return true;
    }).toList();

    if (docs.isEmpty) return 0;

    final batch = _db.batch();
    for (final doc in docs) {
      batch.update(doc.reference, {'recurringPaymentId': payment.id});
    }
    await batch.commit();
    return docs.length;
  }

  // Manually link/mark as paid -> Advance due date & optionally create txn
  // Both the date update and optional transaction creation are batched atomically.
  Future<void> markAsPaid(
    RecurringPayment payment, {
    bool createTransaction = false,
  }) async {
    final user = _auth.currentUser;
    final email = _userEmail;
    if (user == null || email == null) return;

    final uid = user.uid;
    DateTime nextDate = _advanceDate(payment);

    // Idempotency: if the auto-pay already created a transaction for this
    // payment today (and advanced the due date), do nothing — otherwise a
    // manual "Mark Paid" would record a duplicate payment for the same cycle.
    if (createTransaction) {
      final existingSnap = await _db
          .collection('users')
          .doc(email)
          .collection('transactions')
          .where('recurringPaymentId', isEqualTo: payment.id)
          .get();
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final hasTodayTx = existingSnap.docs.any((d) {
        final date = (d.data()['date'] as dynamic)?.toDate();
        return date != null && !date.isBefore(todayStart);
      });
      if (hasTodayTx) return;
    }

    final batch = _db.batch();

    final paymentRef = _db
        .collection('users')
        .doc(email)
        .collection('recurring_payments')
        .doc(payment.id);
    batch.update(paymentRef, {'nextDueDate': Timestamp.fromDate(nextDate)});

    if (createTransaction) {
      final txId = const Uuid().v4();
      final txRef = _db
          .collection('users')
          .doc(email)
          .collection('transactions')
          .doc(txId);
      batch.set(txRef, {
        'id': txId,
        'amount': -RecurringPayment.roundAmount(payment.amount),
        'recipientName': payment.title,
        'recipientId': 'External',
        'senderId': uid,
        'date': Timestamp.fromDate(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
        'category': payment.category,
        'status': 'success',
        'type': 'debit',
        'note': 'Manual payment for ${payment.title}',
        'recurringPaymentId': payment.id,
      });
    }

    await batch.commit();

      LocalBackupService.backupUserTransactions(
        email,
        reportErrors: false,
      );
  }

  // Process Due Payments (called by Background Worker). uid is passed explicitly
  // because FirebaseAuth.currentUser may be null in a background isolate.
  //
  // auto-pay payments: create a transaction and advance nextDueDate (current
  // behavior). Non-auto-pay payments are left untouched (nextDueDate stays put)
  // so they remain overdue and are returned as the "pending" list for the caller
  // to remind the user about.
  static Future<List<RecurringPayment>> processDuePayments(
    String userEmail,
    String uid,
  ) async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfToday = today.add(const Duration(days: 1));

    // Single-field range query (no composite index required). The upper bound
    // is the END of today so a nextDueDate carrying a time-of-day still fires
    // on its due date instead of a day late.
    final snapshot = await db
        .collection('users')
        .doc(userEmail)
        .collection('recurring_payments')
        .where('nextDueDate', isLessThan: Timestamp.fromDate(endOfToday))
        .get();

    final pending = <RecurringPayment>[];

    for (var doc in snapshot.docs) {
      final payment = RecurringPayment.fromMap(doc.id, doc.data());

      if (!payment.isActive) continue;
      if (!payment.autoPay) {
        pending.add(payment);
        continue;
      }

      // Idempotency: skip if a transaction for this payment was already
      // created today. Equality-only query (no composite index required);
      // the date filter is applied in memory.
      final existingSnap = await db
          .collection('users')
          .doc(userEmail)
          .collection('transactions')
          .where('recurringPaymentId', isEqualTo: payment.id)
          .get();
      final hasTodayTx = existingSnap.docs.any((d) {
        final date = (d.data()['date'] as dynamic)?.toDate();
        return date != null && !date.isBefore(today);
      });
      if (hasTodayTx) continue;

      final nextDate = _advanceDateStatic(payment, today);
      final cycleKey = '${today.year}-${today.month}';

      // Atomically create transaction + advance due date in one batch.
      final batch = db.batch();

      final txId = const Uuid().v4();
      final txRef = db
          .collection('users')
          .doc(userEmail)
          .collection('transactions')
          .doc(txId);
      batch.set(txRef, {
        'id': txId,
        'amount': -RecurringPayment.roundAmount(payment.amount),
        'recipientName': payment.title,
        'recipientId': 'External',
        'senderId': uid,
        'date': Timestamp.fromDate(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
        'category': payment.category,
        'status': 'success',
        'type': 'debit',
        'note': 'Auto-payment for ${payment.title}',
        'recurringPaymentId': payment.id,
        'processedCycleKey': cycleKey,
      });

      batch.update(doc.reference, {
        'nextDueDate': Timestamp.fromDate(nextDate),
      });

      await batch.commit();
      LocalBackupService.backupUserTransactions(
        userEmail,
        reportErrors: false,
      );
    }

    return pending;
  }

  DateTime _advanceDate(RecurringPayment payment) =>
      _advanceDateStatic(payment, DateTime.now());

  /// Advance [payment.nextDueDate] by one cycle. When [referenceDate] is
  /// provided the next due date is computed from [referenceDate] instead of
  /// the (potentially stale) stored value — this prevents the catch-up bug
  /// where overdue payments create one transaction per day.
  static DateTime _advanceDateStatic(
    RecurringPayment payment, [
    DateTime? referenceDate,
  ]) {
    final d = referenceDate ?? payment.nextDueDate;
    if (payment.frequency == RecurringFrequency.monthly) {
      return _clampedNextMonth(d);
    } else if (payment.frequency == RecurringFrequency.weekly) {
      return d.add(const Duration(days: 7));
    } else if (payment.frequency == RecurringFrequency.yearly) {
      final targetYear = d.year + 1;
      final lastDay = DateTime(targetYear, d.month + 1, 0).day;
      return DateTime(targetYear, d.month, d.day.clamp(1, lastDay));
    }
    return d;
  }
}
