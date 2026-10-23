import 'package:flutter/material.dart';
import 'package:money_control/Config/asset_screen_configs.dart';
import 'package:money_control/Models/wealth_data.dart';
import 'package:money_control/Screens/asset_detail_screen.dart';

/// The sections the wealth screen groups the asset cards into in Custom Mode.
enum WealthAssetGroup {
  liquidAndFixedIncome,
  equityAndGrowth,
  retirement,
  alternativeAssets,
  physicalAssets,
  protectionAndBusiness,
  liabilities,
}

/// Where an asset card's tap goes.
enum WealthAssetDestination {
  /// The card is not tappable — the cash balance comes from the transaction
  /// stream, not from a detail screen.
  none,

  /// A screen built from an [AssetScreenConfig].
  config,

  /// One of the four hand-written detail screens.
  realEstate,
  vehicle,
  insurance,

  /// The two liability screens.
  creditCard,
  loans,
}

/// One asset type on the wealth screen.
class WealthAssetDescriptor {
  const WealthAssetDescriptor({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.color,
    required this.group,
    required this.destination,
    this.config,
    this.readOnly = false,
    this.coverageStyle = false,
    this.minAge = 0,
    this.maxAge = 100,
  });

  /// The portfolio field this asset is stored under.
  final String key;

  /// The name on the asset card.
  final String label;

  /// The name on the allocation chart, where there is no room for the full
  /// one.
  final String shortLabel;

  final IconData icon;
  final Color color;

  /// The Custom Mode section this asset belongs to.
  final WealthAssetGroup group;

  /// Where a tap on the card goes.
  final WealthAssetDestination destination;

  /// The detail screen's configuration, for [WealthAssetDestination.config].
  final AssetScreenConfig? config;

  /// The card shows a value it does not own and cannot be edited.
  final bool readOnly;

  /// The card shows a coverage figure rather than an amount.
  final bool coverageStyle;

  /// The ages this asset is recommended for in Smart Mode.
  final int minAge;
  final int maxAge;

  bool isRecommendedFor(int age) => age >= minAge && age <= maxAge;

  /// Liabilities are not assets.
  bool get isLiability => group == WealthAssetGroup.liabilities;

  /// Whether the asset counts towards the allocation chart.
  bool get includedInAllocation => !isLiability && !coverageStyle;
}

/// The 26 asset types the wealth screen knows about.
class WealthAssetRegistry {
  WealthAssetRegistry._();

  // ── Liquid & Fixed Income ─────────────────────────────────────────────────

  static final bank = WealthAssetDescriptor(
    key: 'bank',
    label: 'Cash / Bank',
    shortLabel: 'Bank',
    icon: Icons.account_balance,
    color: Colors.teal,
    group: WealthAssetGroup.liquidAndFixedIncome,
    destination: WealthAssetDestination.none,
    readOnly: true,
  );

  static final fd = WealthAssetDescriptor(
    key: 'fd',
    label: 'FD / RD',
    shortLabel: 'FD',
    icon: Icons.savings,
    color: Colors.orange,
    group: WealthAssetGroup.liquidAndFixedIncome,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.fd,
    minAge: 18,
  );

  static final ppf = WealthAssetDescriptor(
    key: 'ppf',
    label: 'PPF',
    shortLabel: 'PPF',
    icon: Icons.savings_outlined,
    color: Colors.lightBlue,
    group: WealthAssetGroup.liquidAndFixedIncome,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.ppf,
    minAge: 18,
    maxAge: 55,
  );

  static final postOffice = WealthAssetDescriptor(
    key: 'postOffice',
    label: 'Post Office Schemes',
    shortLabel: 'Post Office',
    icon: Icons.local_post_office,
    color: Colors.red.shade300,
    group: WealthAssetGroup.liquidAndFixedIncome,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.postOffice,
    minAge: 18,
  );

  static final bonds = WealthAssetDescriptor(
    key: 'bonds',
    label: 'Bonds (Govt/Corp)',
    shortLabel: 'Bonds',
    icon: Icons.receipt_long,
    color: Colors.blueGrey,
    group: WealthAssetGroup.liquidAndFixedIncome,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.bonds,
    minAge: 18,
    maxAge: 70,
  );

  static final chitFund = WealthAssetDescriptor(
    key: 'chitFund',
    label: 'Chit Fund',
    shortLabel: 'Chit Fund',
    icon: Icons.groups,
    color: Colors.teal.shade300,
    group: WealthAssetGroup.liquidAndFixedIncome,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.chitFund,
    minAge: 21,
    maxAge: 60,
  );

  // ── Equity & Growth ───────────────────────────────────────────────────────

  static final stocks = WealthAssetDescriptor(
    key: 'stocks',
    label: 'Stocks',
    shortLabel: 'Stocks',
    icon: Icons.show_chart,
    color: Colors.purple,
    group: WealthAssetGroup.equityAndGrowth,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.stocks,
    minAge: 18,
    maxAge: 55,
  );

  static final sip = WealthAssetDescriptor(
    key: 'sip',
    label: 'Mutual Funds (SIP)',
    shortLabel: 'SIP',
    icon: Icons.pie_chart,
    color: Colors.blue,
    group: WealthAssetGroup.equityAndGrowth,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.sip,
    minAge: 18,
    maxAge: 60,
  );

  static final etf = WealthAssetDescriptor(
    key: 'etf',
    label: 'ETFs',
    shortLabel: 'ETF',
    icon: Icons.stacked_line_chart,
    color: Colors.cyan,
    group: WealthAssetGroup.equityAndGrowth,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.etf,
    minAge: 18,
    maxAge: 55,
  );

  static final foreignStocks = WealthAssetDescriptor(
    key: 'foreignStocks',
    label: 'Foreign Stocks',
    shortLabel: 'Foreign',
    icon: Icons.language,
    color: Colors.deepPurple,
    group: WealthAssetGroup.equityAndGrowth,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.foreignStocks,
    minAge: 25,
    maxAge: 50,
  );

  static final startupEquity = WealthAssetDescriptor(
    key: 'startupEquity',
    label: 'Angel / Startup',
    shortLabel: 'Startup',
    icon: Icons.rocket_launch,
    color: Colors.orange,
    group: WealthAssetGroup.equityAndGrowth,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.startupEquity,
    minAge: 30,
    maxAge: 50,
  );

  // ── Retirement ────────────────────────────────────────────────────────────

  static final pf = WealthAssetDescriptor(
    key: 'pf',
    label: 'PF / EPF',
    shortLabel: 'PF',
    icon: Icons.account_balance_wallet,
    color: Colors.green,
    group: WealthAssetGroup.retirement,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.pf,
    minAge: 18,
    maxAge: 60,
  );

  static final vpf = WealthAssetDescriptor(
    key: 'vpf',
    label: 'Voluntary PF',
    shortLabel: 'VPF',
    icon: Icons.account_balance_wallet_outlined,
    color: Colors.green.shade300,
    group: WealthAssetGroup.retirement,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.vpf,
    minAge: 25,
    maxAge: 55,
  );

  static final nps = WealthAssetDescriptor(
    key: 'nps',
    label: 'NPS',
    shortLabel: 'NPS',
    icon: Icons.elderly,
    color: Colors.indigo,
    group: WealthAssetGroup.retirement,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.nps,
    minAge: 25,
    maxAge: 60,
  );

  // ── Alternative Assets ────────────────────────────────────────────────────

  static final gold = WealthAssetDescriptor(
    key: 'gold',
    label: 'Gold / Silver',
    shortLabel: 'Gold',
    icon: Icons.grid_goldenratio,
    color: Colors.amber,
    group: WealthAssetGroup.alternativeAssets,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.gold,
  );

  static final sgb = WealthAssetDescriptor(
    key: 'sgb',
    label: 'Sovereign Gold Bonds',
    shortLabel: 'SGB',
    icon: Icons.monetization_on,
    color: Colors.amber.shade300,
    group: WealthAssetGroup.alternativeAssets,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.sgb,
    minAge: 18,
    maxAge: 65,
  );

  static final jewelry = WealthAssetDescriptor(
    key: 'jewelry',
    label: 'Jewelry / Diamonds',
    shortLabel: 'Jewelry',
    icon: Icons.diamond,
    color: Colors.pink.shade300,
    group: WealthAssetGroup.alternativeAssets,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.jewelry,
  );

  static final crypto = WealthAssetDescriptor(
    key: 'crypto',
    label: 'Crypto',
    shortLabel: 'Crypto',
    icon: Icons.currency_bitcoin,
    color: Colors.deepOrange,
    group: WealthAssetGroup.alternativeAssets,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.crypto,
    minAge: 21,
    maxAge: 45,
  );

  static final reit = WealthAssetDescriptor(
    key: 'reit',
    label: 'REITs',
    shortLabel: 'REIT',
    icon: Icons.apartment,
    color: Colors.tealAccent.shade700,
    group: WealthAssetGroup.alternativeAssets,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.reit,
    minAge: 25,
    maxAge: 60,
  );

  static final p2p = WealthAssetDescriptor(
    key: 'p2p',
    label: 'P2P Lending',
    shortLabel: 'P2P',
    icon: Icons.people_alt,
    color: Colors.lime,
    group: WealthAssetGroup.alternativeAssets,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.p2p,
    minAge: 25,
    maxAge: 50,
  );

  // ── Physical Assets ───────────────────────────────────────────────────────

  static final realEstate = WealthAssetDescriptor(
    key: 'realEstate',
    label: 'Real Estate',
    shortLabel: 'RE',
    icon: Icons.domain,
    color: Colors.brown,
    group: WealthAssetGroup.physicalAssets,
    destination: WealthAssetDestination.realEstate,
    minAge: 25,
  );

  static final agriLand = WealthAssetDescriptor(
    key: 'agriLand',
    label: 'Agricultural Land',
    shortLabel: 'Agri Land',
    icon: Icons.grass,
    color: Colors.green,
    group: WealthAssetGroup.physicalAssets,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.agriLand,
    minAge: 25,
  );

  static final vehicle = WealthAssetDescriptor(
    key: 'vehicle',
    label: 'Vehicle(s)',
    shortLabel: 'Vehicle',
    icon: Icons.directions_car,
    color: Colors.blueGrey.shade300,
    group: WealthAssetGroup.physicalAssets,
    destination: WealthAssetDestination.vehicle,
    minAge: 18,
  );

  // ── Protection & Business ─────────────────────────────────────────────────

  static final insurance = WealthAssetDescriptor(
    key: 'insurance',
    label: 'Life Insurance / ULIP',
    shortLabel: 'Insurance',
    icon: Icons.health_and_safety,
    color: Colors.pink,
    group: WealthAssetGroup.protectionAndBusiness,
    destination: WealthAssetDestination.insurance,
    coverageStyle: true,
    minAge: 21,
    maxAge: 65,
  );

  static final business = WealthAssetDescriptor(
    key: 'business',
    label: 'Business Capital',
    shortLabel: 'Business',
    icon: Icons.business_center,
    color: Colors.brown.shade300,
    group: WealthAssetGroup.protectionAndBusiness,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.business,
    minAge: 21,
    maxAge: 65,
  );

  // ── Liabilities ───────────────────────────────────────────────────────────

  static final loans = WealthAssetDescriptor(
    key: 'loans',
    label: 'Loans / Liabilities',
    shortLabel: 'Loans',
    icon: Icons.money_off,
    color: Colors.red,
    group: WealthAssetGroup.liabilities,
    destination: WealthAssetDestination.loans,
  );

  static final creditCard = WealthAssetDescriptor(
    key: 'creditCard',
    label: 'Credit Card Outstanding',
    shortLabel: 'Credit Card',
    icon: Icons.credit_card,
    color: Colors.red.shade700,
    group: WealthAssetGroup.liabilities,
    destination: WealthAssetDestination.creditCard,
    minAge: 18,
  );

  static final bnpl = WealthAssetDescriptor(
    key: 'bnpl',
    label: 'BNPL / Pay Later',
    shortLabel: 'BNPL',
    icon: Icons.schedule,
    color: Colors.deepOrange.shade700,
    group: WealthAssetGroup.liabilities,
    destination: WealthAssetDestination.config,
    config: AssetConfigs.bnpl,
    minAge: 18,
    maxAge: 60,
  );

  /// Every asset type, in the order the Custom Mode sections list them.
  static final List<WealthAssetDescriptor> assets = [
    bank,
    fd,
    ppf,
    postOffice,
    bonds,
    chitFund,
    stocks,
    sip,
    etf,
    foreignStocks,
    startupEquity,
    pf,
    vpf,
    nps,
    gold,
    sgb,
    jewelry,
    crypto,
    reit,
    p2p,
    realEstate,
    agriLand,
    vehicle,
    insurance,
    business,
    loans,
    creditCard,
    bnpl,
  ];

  static final Map<String, WealthAssetDescriptor> _byKey = {
    for (final a in assets) a.key: a,
  };

  /// The descriptor for an asset key, or null for a custom asset.
  static WealthAssetDescriptor? byKey(String key) => _byKey[key];

  /// The assets that make up the allocation chart.
  static List<WealthAssetDescriptor> get allocationAssets =>
      assets.where((a) => a.includedInAllocation).toList();

  /// The assets in one Custom Mode section.
  static List<WealthAssetDescriptor> inGroup(WealthAssetGroup group) =>
      assets.where((a) => a.group == group).toList();

  /// The names of the Custom Mode sections, in order.
  static const List<WealthAssetGroup> groupOrder = [
    WealthAssetGroup.liquidAndFixedIncome,
    WealthAssetGroup.equityAndGrowth,
    WealthAssetGroup.retirement,
    WealthAssetGroup.alternativeAssets,
    WealthAssetGroup.physicalAssets,
    WealthAssetGroup.protectionAndBusiness,
    WealthAssetGroup.liabilities,
  ];

  /// The asset types recommended for an age, in Smart Mode.
  static Set<String> recommendedFor(int age) => assets
      .where((a) => a.isRecommendedFor(age))
      .map((a) => a.key)
      .toSet();
}

/// The portfolio amount behind an asset key.
double wealthAssetValue(WealthPortfolio p, String key) => switch (key) {
  'sip' => p.sip,
  'fd' => p.fd,
  'stocks' => p.stocks,
  'pf' => p.pf,
  'crypto' => p.crypto,
  'gold' => p.gold,
  'realEstate' => p.realEstate,
  'nps' => p.nps,
  'loans' => p.loans,
  'etf' => p.etf,
  'reit' => p.reit,
  'p2p' => p.p2p,
  'ppf' => p.ppf,
  'sgb' => p.sgb,
  'bonds' => p.bonds,
  'insurance' => p.insurance,
  'foreignStocks' => p.foreignStocks,
  'vpf' => p.vpf,
  'postOffice' => p.postOffice,
  'chitFund' => p.chitFund,
  'startupEquity' => p.startupEquity,
  'business' => p.business,
  'vehicle' => p.vehicle,
  'jewelry' => p.jewelry,
  'agriLand' => p.agriLand,
  'creditCard' => p.creditCard,
  'bnpl' => p.bnpl,
  _ => 0,
};
