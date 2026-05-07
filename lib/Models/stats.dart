class StatsModel {
  final double totalIncome;
  final double totalExpense;
  final Map<String, double> incomeByDay;
  final Map<String, double> expenseByDay;

  StatsModel({
    required this.totalIncome,
    required this.totalExpense,
    required this.incomeByDay,
    required this.expenseByDay,
  });

  factory StatsModel.fromMap(Map<String, dynamic> map) {
    return StatsModel(
      totalIncome: _parseNum(map['totalIncome']),
      totalExpense: _parseNum(map['totalExpense']),
      incomeByDay: _toDoubleMap(map['incomeByDay']),
      expenseByDay: _toDoubleMap(map['expenseByDay']),
    );
  }

  static double _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static Map<String, double> _toDoubleMap(dynamic value) {
    if (value == null) return {};
    final raw = value as Map;
    return raw.map((k, v) {
      if (v == null) return MapEntry(k.toString(), 0.0);
      if (v is num) return MapEntry(k.toString(), v.toDouble());
      if (v is String) return MapEntry(k.toString(), double.tryParse(v) ?? 0.0);
      return MapEntry(k.toString(), 0.0);
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'incomeByDay': incomeByDay,
      'expenseByDay': expenseByDay,
    };
  }
}
