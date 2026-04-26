import 'package:cloud_firestore/cloud_firestore.dart';

class WealthPortfolio {
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
  final Map<String, double> custom;
  final Map<String, double> targets;
  final List<String> hiddenKeys;
  final DateTime lastUpdated;

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
    this.custom = const {},
    this.targets = const {},
    this.hiddenKeys = const [],
    required this.lastUpdated,
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
      'custom': custom,
      'targets': targets,
      'hiddenKeys': hiddenKeys,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
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
      custom: Map<String, double>.from(map['custom'] ?? {}),
      targets: Map<String, double>.from(map['targets'] ?? {}),
      hiddenKeys: List<String>.from(map['hiddenKeys'] ?? []),
      lastUpdated:
          (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      custom.values.fold(0, (a, b) => a + b);
}
