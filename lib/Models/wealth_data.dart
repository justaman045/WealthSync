import 'package:cloud_firestore/cloud_firestore.dart';

class WealthPortfolio {
  // ── Original assets ───────────────────────────────────────────────────────
  final double sip;
  final double fd;
  final double stocks;
  final double pf;
  final double crypto;
  final double gold;
  final double realEstate;
  final double nps;
  final double loans;
  final double etf;
  final double reit;
  final double p2p;

  // ── New asset categories ──────────────────────────────────────────────────
  final double ppf;
  final double sgb;
  final double bonds;
  final double insurance;
  final double foreignStocks;
  final double vpf;
  final double postOffice;
  final double chitFund;
  final double startupEquity;
  final double business;
  final double vehicle;
  final double jewelry;
  final double agriLand;

  // ── New liability categories ──────────────────────────────────────────────
  final double creditCard;
  final double bnpl;

  // ── Metadata ──────────────────────────────────────────────────────────────
  final Map<String, double> custom;
  final Map<String, double> targets;
  final List<String> hiddenKeys;
  final DateTime lastUpdated;
  final double? monthlyExpenseOverride;

  WealthPortfolio({
    this.sip = 0,
    this.fd = 0,
    this.stocks = 0,
    this.pf = 0,
    this.crypto = 0,
    this.gold = 0,
    this.realEstate = 0,
    this.nps = 0,
    this.loans = 0,
    this.etf = 0,
    this.reit = 0,
    this.p2p = 0,
    this.ppf = 0,
    this.sgb = 0,
    this.bonds = 0,
    this.insurance = 0,
    this.foreignStocks = 0,
    this.vpf = 0,
    this.postOffice = 0,
    this.chitFund = 0,
    this.startupEquity = 0,
    this.business = 0,
    this.vehicle = 0,
    this.jewelry = 0,
    this.agriLand = 0,
    this.creditCard = 0,
    this.bnpl = 0,
    this.custom = const {},
    this.targets = const {},
    this.hiddenKeys = const [],
    required this.lastUpdated,
    this.monthlyExpenseOverride,
  });

  Map<String, dynamic> toMap() {
    return {
      'sip': sip,
      'fd': fd,
      'stocks': stocks,
      'pf': pf,
      'crypto': crypto,
      'gold': gold,
      'realEstate': realEstate,
      'nps': nps,
      'loans': loans,
      'etf': etf,
      'reit': reit,
      'p2p': p2p,
      'ppf': ppf,
      'sgb': sgb,
      'bonds': bonds,
      'insurance': insurance,
      'foreignStocks': foreignStocks,
      'vpf': vpf,
      'postOffice': postOffice,
      'chitFund': chitFund,
      'startupEquity': startupEquity,
      'business': business,
      'vehicle': vehicle,
      'jewelry': jewelry,
      'agriLand': agriLand,
      'creditCard': creditCard,
      'bnpl': bnpl,
      'custom': custom,
      'targets': targets,
      'hiddenKeys': hiddenKeys,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      if (monthlyExpenseOverride != null)
        'monthly_expense_override': monthlyExpenseOverride,
    };
  }

  factory WealthPortfolio.fromMap(Map<String, dynamic> map) {
    return WealthPortfolio(
      sip: (map['sip'] ?? 0).toDouble(),
      fd: (map['fd'] ?? 0).toDouble(),
      stocks: (map['stocks'] ?? 0).toDouble(),
      pf: (map['pf'] ?? 0).toDouble(),
      crypto: (map['crypto'] ?? 0).toDouble(),
      gold: (map['gold'] ?? 0).toDouble(),
      realEstate: (map['realEstate'] ?? 0).toDouble(),
      nps: (map['nps'] ?? 0).toDouble(),
      loans: (map['loans'] ?? 0).toDouble(),
      etf: (map['etf'] ?? 0).toDouble(),
      reit: (map['reit'] ?? 0).toDouble(),
      p2p: (map['p2p'] ?? 0).toDouble(),
      ppf: (map['ppf'] ?? 0).toDouble(),
      sgb: (map['sgb'] ?? 0).toDouble(),
      bonds: (map['bonds'] ?? 0).toDouble(),
      insurance: (map['insurance'] ?? 0).toDouble(),
      foreignStocks: (map['foreignStocks'] ?? 0).toDouble(),
      vpf: (map['vpf'] ?? 0).toDouble(),
      postOffice: (map['postOffice'] ?? 0).toDouble(),
      chitFund: (map['chitFund'] ?? 0).toDouble(),
      startupEquity: (map['startupEquity'] ?? 0).toDouble(),
      business: (map['business'] ?? 0).toDouble(),
      vehicle: (map['vehicle'] ?? 0).toDouble(),
      jewelry: (map['jewelry'] ?? 0).toDouble(),
      agriLand: (map['agriLand'] ?? 0).toDouble(),
      creditCard: (map['creditCard'] ?? 0).toDouble(),
      bnpl: (map['bnpl'] ?? 0).toDouble(),
      custom: _toDoubleMap(map['custom']),
      targets: _toDoubleMap(map['targets']),
      hiddenKeys: (map['hiddenKeys'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      lastUpdated:
          (map['lastUpdated'] as dynamic)?.toDate() ?? DateTime.now(),
      monthlyExpenseOverride:
          (map['monthly_expense_override'] as num?)?.toDouble(),
    );
  }

  static Map<String, double> _toDoubleMap(dynamic value) {
    if (value == null) return {};
    if (value is! Map) return {};
    final raw = value as Map<String, dynamic>;
    return raw.map((k, v) {
      if (v == null) return MapEntry(k.toString(), 0.0);
      if (v is num) return MapEntry(k.toString(), v.toDouble());
      if (v is String) return MapEntry(k.toString(), double.tryParse(v) ?? 0.0);
      return MapEntry(k.toString(), 0.0);
    });
  }

  double get totalAssets =>
      sip +
      fd +
      stocks +
      pf +
      crypto +
      gold +
      realEstate +
      nps +
      etf +
      reit +
      p2p +
      ppf +
      sgb +
      bonds +
      insurance +
      foreignStocks +
      vpf +
      postOffice +
      chitFund +
      startupEquity +
      business +
      vehicle +
      jewelry +
      agriLand +
      custom.values.fold(0, (a, b) => a + b);

  double get totalLiabilities => loans + creditCard + bnpl;
}
