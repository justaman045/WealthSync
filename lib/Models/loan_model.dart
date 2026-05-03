import 'package:cloud_firestore/cloud_firestore.dart';

enum LoanType { home, car, personal, education, other }

class AmortizationEntry {
  final int month;
  final double principalPaid;
  final double interestPaid;
  final double outstanding;

  const AmortizationEntry({
    required this.month,
    required this.principalPaid,
    required this.interestPaid,
    required this.outstanding,
  });
}

class LoanModel {
  final String id;
  final String name;
  final LoanType loanType;
  final double principalAmount;
  final double interestRate; // annual %
  final double emiAmount;
  final int tenureMonths;
  final DateTime startDate;
  final bool isActive;
  final String? linkedRecurringPaymentId;
  final Timestamp? createdAt;

  const LoanModel({
    required this.id,
    required this.name,
    required this.loanType,
    required this.principalAmount,
    required this.interestRate,
    required this.emiAmount,
    required this.tenureMonths,
    required this.startDate,
    this.isActive = true,
    this.linkedRecurringPaymentId,
    this.createdAt,
  });

  // Monthly rate
  double get _r => interestRate / 12 / 100;

  // Months elapsed since loan start (capped to tenure)
  int get monthsPaid {
    final now = DateTime.now();
    final months = (now.year - startDate.year) * 12 + (now.month - startDate.month);
    return months.clamp(0, tenureMonths);
  }

  // Outstanding balance using reducing balance formula
  double get outstandingBalance {
    final m = monthsPaid;
    if (m >= tenureMonths) return 0;
    if (_r == 0) return principalAmount - (emiAmount * m);
    final outstanding = principalAmount * _pow(1 + _r, m) -
        emiAmount * (_pow(1 + _r, m) - 1) / _r;
    return outstanding.clamp(0, principalAmount);
  }

  double get principalPaid => principalAmount - outstandingBalance;

  double get progressPercent =>
      principalAmount > 0 ? (principalPaid / principalAmount).clamp(0.0, 1.0) : 0;

  double get totalInterestPayable => emiAmount * tenureMonths - principalAmount;

  // Full amortization schedule
  List<AmortizationEntry> buildSchedule() {
    final schedule = <AmortizationEntry>[];
    double outstanding = principalAmount;
    for (int m = 1; m <= tenureMonths; m++) {
      final interest = outstanding * _r;
      final principal = emiAmount - interest;
      outstanding = (outstanding - principal).clamp(0, double.infinity);
      schedule.add(AmortizationEntry(
        month: m,
        principalPaid: principal,
        interestPaid: interest,
        outstanding: outstanding,
      ));
      if (outstanding == 0) break;
    }
    return schedule;
  }

  // Static EMI calculator
  static double calcEmi(double principal, double annualRate, int months) {
    if (annualRate == 0) return principal / months;
    final r = annualRate / 12 / 100;
    return principal * r * _pow(1 + r, months) / (_pow(1 + r, months) - 1);
  }

  static double _pow(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  factory LoanModel.fromMap(String id, Map<String, dynamic> map) {
    return LoanModel(
      id: id,
      name: map['name'] ?? '',
      loanType: LoanType.values.firstWhere(
        (e) => e.name == map['loanType'],
        orElse: () => LoanType.other,
      ),
      principalAmount: (map['principalAmount'] ?? 0).toDouble(),
      interestRate: (map['interestRate'] ?? 0).toDouble(),
      emiAmount: (map['emiAmount'] ?? 0).toDouble(),
      tenureMonths: (map['tenureMonths'] ?? 0) as int,
      startDate: ((map['startDate'] as Timestamp?) ?? Timestamp.now()).toDate(),
      isActive: map['isActive'] ?? true,
      linkedRecurringPaymentId: map['linkedRecurringPaymentId'] as String?,
      createdAt: map['createdAt'] is Timestamp
          ? map['createdAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'loanType': loanType.name,
      'principalAmount': principalAmount,
      'interestRate': interestRate,
      'emiAmount': emiAmount,
      'tenureMonths': tenureMonths,
      'startDate': Timestamp.fromDate(startDate),
      'isActive': isActive,
      'linkedRecurringPaymentId': linkedRecurringPaymentId,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  LoanModel copyWith({bool? isActive, String? linkedRecurringPaymentId}) {
    return LoanModel(
      id: id,
      name: name,
      loanType: loanType,
      principalAmount: principalAmount,
      interestRate: interestRate,
      emiAmount: emiAmount,
      tenureMonths: tenureMonths,
      startDate: startDate,
      isActive: isActive ?? this.isActive,
      linkedRecurringPaymentId:
          linkedRecurringPaymentId ?? this.linkedRecurringPaymentId,
      createdAt: createdAt,
    );
  }
}
