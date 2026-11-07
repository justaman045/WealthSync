import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Utils/insights_math.dart';
import 'package:money_control/Utils/wealth_math.dart';

void main() {
  RecurringPayment payment({
    required String id,
    required String category,
    required double amount,
    RecurringFrequency frequency = RecurringFrequency.monthly,
    required bool isActive,
  }) =>
      RecurringPayment(
        id: id,
        userId: 'uid',
        title: category,
        amount: amount,
        category: category,
        frequency: frequency,
        startDate: DateTime(2026, 10, 1),
        nextDueDate: DateTime(2026, 11, 10),
        isActive: isActive,
      );

  TransactionModel tx({
    required String category,
    required double amount,
    required int day,
  }) =>
      TransactionModel(
        id: 'tx',
        senderId: 'uid',
        recipientId: '',
        recipientName: 'Test',
        amount: -amount.abs(),
        currency: 'INR',
        tax: 0,
        note: '',
        category: category,
        date: DateTime(2026, 11, day),
        status: 'success',
        createdAt: DateTime(2026, 11, day),
      );

  test('emi / EMI / Emi transactions plus one recurring EMI produce exactly '
       'one bill, not three', () {
    final now = DateTime(2026, 11, 15);

    final insights = buildMonthInsights(
      transactions: [
        tx(category: 'emi', amount: 10000, day: 5),
        tx(category: 'EMI', amount: 10000, day: 10),
        tx(category: 'Emi', amount: 10000, day: 12),
      ],
      categories: [],
      recurring: [
        payment(
          id: 'emi-recurring',
          category: 'EMI',
          amount: 30000,
          isActive: true,
        ),
      ],
      uid: 'uid',
      incomeMode: IncomeMode.autoBlend,
      manualIncome: 0,
      now: now,
    );

    final emiBills = insights.categories
        .where((c) => c.key == 'emi')
        .toList();

    // One and only one bill for EMI across all three casings.
    expect(emiBills.length, 1);
    final emi = emiBills.first;
    expect(emi.displayName, 'EMI');
    expect(emi.spentThisMonth, 30000); // 10k + 10k + 10k
    expect(emi.recurringDue, 30000); // the recurring EMI
    expect(emi.plan, 30000); // max(0, 30000, 30000) — not 90000
    expect(emi.committed, 30000); // fixed role, committed in full

    // Forecast total == committed bills + variable forecast, not a sum of
    // duplicate rows.
    expect(insights.forecastTotal, 30000);

    // Committed total counts EMI once, not three times.
    expect(insights.committedBills, 30000);
  });

  test('investment with one transaction and one recurring produces one bill',
      () {
    final now = DateTime(2026, 11, 15);

    final insights = buildMonthInsights(
      transactions: [
        tx(category: 'investment', amount: 5000, day: 5),
        tx(category: 'Investment', amount: 5000, day: 10),
      ],
      categories: [],
      recurring: [
        payment(
          id: 'inv-recurring',
          category: 'Investment',
          amount: 10000,
          isActive: true,
        ),
      ],
      uid: 'uid',
      incomeMode: IncomeMode.autoBlend,
      manualIncome: 0,
      now: now,
    );

    final invBills = insights.categories
        .where((c) => c.key == 'investment')
        .toList();

    expect(invBills.length, 1);
    expect(invBills.first.displayName, 'Investment');
  });

  test('title case preserves acronyms: emi → EMI, sip → SIP', () {
    expect(categoryDisplay('emi'), 'EMI');
    expect(categoryDisplay('EMI'), 'EMI');
    expect(categoryDisplay('Emi'), 'EMI');
    expect(categoryDisplay('sip'), 'SIP');
    expect(categoryDisplay('SIP'), 'SIP');
    expect(categoryDisplay('credit card bill'), 'Credit Card Bill');
    expect(categoryDisplay('rent'), 'Rent');
  });

  test('duplicate recurring payments are detected, not deleted', () {
    final suspicions = duplicateRecurringPayments([
      payment(id: 'a', category: 'Rent', amount: 15000, isActive: true),
      payment(id: 'b', category: 'Rent', amount: 15000, isActive: true),
      payment(id: 'c', category: 'Rent', amount: 10000, isActive: true),
      payment(id: 'd', category: 'Rent', amount: 15000, isActive: false),
    ]);

    expect(suspicions.length, 1);
    expect(suspicions.first.categoryKey, 'rent');
    expect(suspicions.first.count, 2);
    expect(suspicions.first.totalMonthlyEquivalent, 30000);
  });
}
