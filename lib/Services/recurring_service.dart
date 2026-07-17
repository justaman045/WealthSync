import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
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

  // Link an existing transaction to this payment
  Future<void> linkTransaction(String paymentId, String transactionId) async {
    final email = _userEmail;
    if (email == null) return;

    await _db
        .collection('users')
        .doc(email)
        .collection('transactions')
        .doc(transactionId)
        .update({'recurringPaymentId': paymentId});
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
        'amount': -payment.amount,
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
  }

  // Process Due Payments (called by Background Worker). uid is passed explicitly
  // because FirebaseAuth.currentUser may be null in a background isolate.
  static Future<void> processDuePayments(
    String userEmail,
    String uid,
  ) async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final snapshot = await db
        .collection('users')
        .doc(userEmail)
        .collection('recurring_payments')
        .where('isActive', isEqualTo: true)
        .where('nextDueDate', isLessThanOrEqualTo: Timestamp.fromDate(today))
        .get();

    for (var doc in snapshot.docs) {
      final payment = RecurringPayment.fromMap(doc.id, doc.data());

      // Idempotency: skip if a transaction for this payment was already
      // created for the current billing cycle.
      final existingSnap = await db
          .collection('users')
          .doc(userEmail)
          .collection('transactions')
          .where('recurringPaymentId', isEqualTo: payment.id)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .limit(1)
          .get();
      if (existingSnap.docs.isNotEmpty) continue;

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
        'amount': -payment.amount,
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
    }
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
