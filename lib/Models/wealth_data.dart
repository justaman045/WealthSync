import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Utils/num_parse.dart';

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
  final double? balance;

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
    this.balance,
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
      if (balance != null) 'balance': balance,
    };
  }

  factory WealthPortfolio.fromMap(Map<String, dynamic> map) {
    return WealthPortfolio(
      sip: safeToDouble(map['sip']),
      fd: safeToDouble(map['fd']),
      stocks: safeToDouble(map['stocks']),
      pf: safeToDouble(map['pf']),
      crypto: safeToDouble(map['crypto']),
      gold: safeToDouble(map['gold']),
      realEstate: safeToDouble(map['realEstate']),
      nps: safeToDouble(map['nps']),
      loans: safeToDouble(map['loans']),
      etf: safeToDouble(map['etf']),
      reit: safeToDouble(map['reit']),
      p2p: safeToDouble(map['p2p']),
      ppf: safeToDouble(map['ppf']),
      sgb: safeToDouble(map['sgb']),
      bonds: safeToDouble(map['bonds']),
      insurance: safeToDouble(map['insurance']),
      foreignStocks: safeToDouble(map['foreignStocks']),
      vpf: safeToDouble(map['vpf']),
      postOffice: safeToDouble(map['postOffice']),
      chitFund: safeToDouble(map['chitFund']),
      startupEquity: safeToDouble(map['startupEquity']),
      business: safeToDouble(map['business']),
      vehicle: safeToDouble(map['vehicle']),
      jewelry: safeToDouble(map['jewelry']),
      agriLand: safeToDouble(map['agriLand']),
      creditCard: safeToDouble(map['creditCard']),
      bnpl: safeToDouble(map['bnpl']),
      custom: _toDoubleMap(map['custom']),
      targets: _toDoubleMap(map['targets']),
      hiddenKeys: map['hiddenKeys'] is List
          ? (map['hiddenKeys'] as List).map((e) => e.toString()).toList()
          : [],
      lastUpdated: _toDateTime(map['lastUpdated']) ?? DateTime.now(),
      monthlyExpenseOverride: _toDoubleOrNull(map['monthly_expense_override']),
      balance: _toDoubleOrNull(map['balance']),
    );
  }

  /// Firestore may hold a String/num/null for these; never throw on a cast.
  static double? _toDoubleOrNull(dynamic value) =>
      value == null ? null : safeToDouble(value);

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, double> _toDoubleMap(dynamic value) {
    if (value is! Map) return {};
    return value.map(
      (k, v) => MapEntry(k.toString(), safeToDouble(v)),
    );
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
