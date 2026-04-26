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
      totalIncome: (map['totalIncome'] ?? 0).toDouble(),
      totalExpense: (map['totalExpense'] ?? 0).toDouble(),
      incomeByDay: Map<String, double>.from(map['incomeByDay'] ?? {}),
      expenseByDay: Map<String, double>.from(map['expenseByDay'] ?? {}),
    );
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
