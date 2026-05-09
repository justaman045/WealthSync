import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Models/wealth_data.dart';

void main() {
  group('WealthPortfolio', () {
    test('totalAssets sums all asset fields', () {
      final p = WealthPortfolio(
        sip: 100000,
        fd: 200000,
        stocks: 300000,
        pf: 400000,
        crypto: 50000,
        gold: 60000,
        realEstate: 5000000,
        nps: 150000,
        etf: 80000,
        reit: 90000,
        p2p: 25000,
        ppf: 180000,
        sgb: 70000,
        bonds: 110000,
        insurance: 500000,
        foreignStocks: 200000,
        vpf: 60000,
        postOffice: 100000,
        chitFund: 50000,
        startupEquity: 300000,
        business: 1000000,
        vehicle: 800000,
        jewelry: 400000,
        agriLand: 2000000,
        creditCard: 50000,
        bnpl: 10000,
        loans: 500000,
        lastUpdated: DateTime.now(),
      );
      // sum of all asset fields only (no liabilities)
      // 100000+200000+300000+400000+50000+60000+5000000+150000+80000+90000+25000+180000+70000+110000+500000+200000+60000+100000+50000+300000+1000000+800000+400000+2000000
      expect(p.totalAssets, closeTo(12225000, 1));
    });

    test('totalLiabilities sums liability fields', () {
      final p = WealthPortfolio(
        loans: 500000,
        creditCard: 50000,
        bnpl: 10000,
        lastUpdated: DateTime.now(),
      );
      expect(p.totalLiabilities, 560000);
    });

    test('totalAssets excludes liabilities', () {
      final p = WealthPortfolio(
        loans: 500000,
        creditCard: 50000,
        bnpl: 10000,
        sip: 100000,
        lastUpdated: DateTime.now(),
      );
      expect(p.totalAssets, 100000);
    });

    test('totalAssets includes custom entries', () {
      final p = WealthPortfolio(
        sip: 50000,
        custom: {'Painting': 200000, 'Vintage Car': 500000},
        lastUpdated: DateTime.now(),
      );
      expect(p.totalAssets, 750000);
    });

    test('totalAssets handles empty portfolio', () {
      final p = WealthPortfolio(lastUpdated: DateTime.now());
      expect(p.totalAssets, 0);
    });

    test('totalLiabilities handles empty portfolio', () {
      final p = WealthPortfolio(lastUpdated: DateTime.now());
      expect(p.totalLiabilities, 0);
    });

    test('fromMap parses all fields correctly', () {
      final map = {
        'sip': 1000.0,
        'fd': 2000.0,
        'stocks': 3000.0,
        'pf': 4000.0,
        'crypto': 500.0,
        'gold': 600.0,
        'realEstate': 50000.0,
        'nps': 1500.0,
        'loans': 10000.0,
        'etf': 800.0,
        'reit': 900.0,
        'p2p': 250.0,
        'ppf': 1800.0,
        'sgb': 700.0,
        'bonds': 1100.0,
        'insurance': 5000.0,
        'foreignStocks': 2000.0,
        'vpf': 600.0,
        'postOffice': 1000.0,
        'chitFund': 500.0,
        'startupEquity': 3000.0,
        'business': 10000.0,
        'vehicle': 8000.0,
        'jewelry': 4000.0,
        'agriLand': 20000.0,
        'creditCard': 500.0,
        'bnpl': 100.0,
        'custom': {'Extra': 5000.0},
        'targets': {'sip': 50000.0},
        'hiddenKeys': ['crypto'],
        'monthly_expense_override': 30000.0,
        'lastUpdated': TimestampMock(),
      };
      final p = WealthPortfolio.fromMap(map);
      expect(p.sip, 1000.0);
      expect(p.fd, 2000.0);
      expect(p.loans, 10000.0);
      expect(p.creditCard, 500.0);
      expect(p.bnpl, 100.0);
      expect(p.custom['Extra'], 5000.0);
      expect(p.targets['sip'], 50000.0);
      expect(p.hiddenKeys, ['crypto']);
      expect(p.monthlyExpenseOverride, 30000.0);
      expect(p.totalAssets, closeTo(127250, 1));
      expect(p.totalLiabilities, 10600);
    });
  });
}

class TimestampMock {
  DateTime toDate() => DateTime(2024, 6, 15);
}
