import 'package:flutter/material.dart';
import 'package:money_control/Screens/asset_detail_screen.dart';

class AssetConfigs {
  AssetConfigs._();

  // ── Liquid & Fixed Income ──────────────────────────────────────────────────

  static const fd = AssetScreenConfig(
    title: "FD / RD",
    collection: "fd_accounts",
    assetKey: "fd",
    accentColor: Colors.orange,
    icon: Icons.savings,
    fabLabel: "Add FD / RD",
    emptyMessage: "No FDs or RDs added yet",
    summaryLabel: "Total Fixed Deposits",
    fields: [
      AssetFieldDef(label: "Bank / NBFC", key: "bank", required: true),
      AssetFieldDef(
        label: "Type",
        key: "type",
        type: AssetFieldType.dropdown,
        options: ["Fixed Deposit", "Recurring Deposit", "SCSS", "Tax Saver FD"],
      ),
      AssetFieldDef(
          label: "Principal amount",
          key: "principal",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Interest rate (%)",
          key: "interestRate",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Maturity date",
          key: "maturityDate",
          type: AssetFieldType.date),
    ],
  );

  static const ppf = AssetScreenConfig(
    title: "PPF",
    collection: "ppf_accounts",
    assetKey: "ppf",
    accentColor: Colors.lightBlue,
    icon: Icons.savings_outlined,
    fabLabel: "Add PPF Account",
    emptyMessage: "No PPF accounts added",
    summaryLabel: "Total PPF Corpus",
    fields: [
      AssetFieldDef(label: "Bank / Post Office", key: "bank", required: true),
      AssetFieldDef(
          label: "Current balance",
          key: "balance",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Annual contribution",
          key: "annualContribution",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Account opened year",
          key: "startYear",
          type: AssetFieldType.number),
    ],
  );

  static const postOffice = AssetScreenConfig(
    title: "Post Office Schemes",
    collection: "post_office_schemes",
    assetKey: "postOffice",
    accentColor: Color(0xFFEF9A9A),
    icon: Icons.local_post_office,
    fabLabel: "Add Scheme",
    emptyMessage: "No post office schemes added",
    summaryLabel: "Total Post Office Investments",
    fields: [
      AssetFieldDef(
        label: "Scheme",
        key: "scheme",
        type: AssetFieldType.dropdown,
        options: ["NSC", "KVP", "MIS", "SSY (Sukanya)", "SCSS", "Mahila Samman", "POMIS"],
      ),
      AssetFieldDef(
          label: "Investment amount",
          key: "amount",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Maturity date",
          key: "maturityDate",
          type: AssetFieldType.date),
    ],
  );

  static const bonds = AssetScreenConfig(
    title: "Bonds",
    collection: "bonds",
    assetKey: "bonds",
    accentColor: Colors.blueGrey,
    icon: Icons.receipt_long,
    fabLabel: "Add Bond",
    emptyMessage: "No bonds added",
    summaryLabel: "Total Bond Investments",
    fields: [
      AssetFieldDef(label: "Bond name / issuer", key: "name", required: true),
      AssetFieldDef(
        label: "Type",
        key: "type",
        type: AssetFieldType.dropdown,
        options: ["Govt Bond", "Corporate Bond", "Tax-Free Bond", "SGrB", "InvIT"],
      ),
      AssetFieldDef(
          label: "Face / investment value",
          key: "currentValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Coupon rate (%)",
          key: "couponRate",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Maturity date",
          key: "maturityDate",
          type: AssetFieldType.date),
    ],
  );

  static const chitFund = AssetScreenConfig(
    title: "Chit Fund",
    collection: "chit_funds",
    assetKey: "chitFund",
    accentColor: Color(0xFF4DB6AC),
    icon: Icons.groups,
    fabLabel: "Add Chit Fund",
    emptyMessage: "No chit funds added",
    summaryLabel: "Total Chit Fund Value",
    fields: [
      AssetFieldDef(label: "Organizer / company", key: "organizer", required: true),
      AssetFieldDef(
          label: "Monthly contribution",
          key: "monthlyContribution",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Total chit value",
          key: "totalValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Duration (months)",
          key: "durationMonths",
          type: AssetFieldType.number),
    ],
  );

  // ── Equity & Growth ────────────────────────────────────────────────────────

  static const stocks = AssetScreenConfig(
    title: "Stocks",
    collection: "stock_holdings",
    assetKey: "stocks",
    accentColor: Colors.purple,
    icon: Icons.show_chart,
    fabLabel: "Add Stock",
    emptyMessage: "No stocks added",
    summaryLabel: "Total Portfolio Value",
    fields: [
      AssetFieldDef(label: "Company name", key: "company", required: true),
      AssetFieldDef(label: "Ticker symbol", key: "ticker"),
      AssetFieldDef(
          label: "Quantity (shares)",
          key: "quantity",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Average buy price",
          key: "avgPrice",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Current value",
          key: "currentValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
    ],
  );

  static const sip = AssetScreenConfig(
    title: "Mutual Funds (SIP)",
    collection: "sip_holdings",
    assetKey: "sip",
    accentColor: Colors.blue,
    icon: Icons.pie_chart,
    fabLabel: "Add Fund",
    emptyMessage: "No mutual funds added",
    summaryLabel: "Total Fund Value",
    fields: [
      AssetFieldDef(label: "Fund name", key: "fundName", required: true),
      AssetFieldDef(label: "AMC / fund house", key: "amc"),
      AssetFieldDef(
        label: "Fund type",
        key: "type",
        type: AssetFieldType.dropdown,
        options: ["Equity", "Debt", "Hybrid", "ELSS", "Index", "Liquid", "Sectoral"],
      ),
      AssetFieldDef(
          label: "Monthly SIP amount",
          key: "monthlySip",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Current value",
          key: "currentValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
    ],
  );

  static const etf = AssetScreenConfig(
    title: "ETFs",
    collection: "etf_holdings",
    assetKey: "etf",
    accentColor: Colors.cyan,
    icon: Icons.stacked_line_chart,
    fabLabel: "Add ETF",
    emptyMessage: "No ETFs added",
    summaryLabel: "Total ETF Value",
    fields: [
      AssetFieldDef(label: "ETF name", key: "name", required: true),
      AssetFieldDef(
        label: "Category",
        key: "category",
        type: AssetFieldType.dropdown,
        options: ["Nifty 50", "Sensex", "Gold ETF", "Bank ETF", "IT ETF", "International ETF", "Other"],
      ),
      AssetFieldDef(
          label: "Units held",
          key: "units",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Current value",
          key: "currentValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
    ],
  );

  static const foreignStocks = AssetScreenConfig(
    title: "Foreign Stocks",
    collection: "foreign_stocks",
    assetKey: "foreignStocks",
    accentColor: Colors.deepPurple,
    icon: Icons.language,
    fabLabel: "Add Foreign Stock",
    emptyMessage: "No foreign stocks added",
    summaryLabel: "Total Foreign Portfolio",
    fields: [
      AssetFieldDef(label: "Company name", key: "company", required: true),
      AssetFieldDef(label: "Exchange / country", key: "exchange"),
      AssetFieldDef(
        label: "Platform",
        key: "platform",
        type: AssetFieldType.dropdown,
        options: ["Vested", "IndMoney", "Stockal", "INDmoney", "Winvesta", "Other"],
      ),
      AssetFieldDef(
          label: "Current value (₹ equivalent)",
          key: "currentValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
    ],
  );

  static const startupEquity = AssetScreenConfig(
    title: "Angel / Startup Investments",
    collection: "startup_investments",
    assetKey: "startupEquity",
    accentColor: Colors.orange,
    icon: Icons.rocket_launch,
    fabLabel: "Add Investment",
    emptyMessage: "No startup investments added",
    summaryLabel: "Total Invested Capital",
    fields: [
      AssetFieldDef(label: "Startup / company", key: "company", required: true),
      AssetFieldDef(
        label: "Stage",
        key: "stage",
        type: AssetFieldType.dropdown,
        options: ["Pre-Seed", "Seed", "Series A", "Series B", "Series C+", "IPO/Listed"],
      ),
      AssetFieldDef(
          label: "Investment amount",
          key: "amount",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Equity stake (%)",
          key: "stakePercent",
          type: AssetFieldType.number),
    ],
  );

  // ── Retirement ─────────────────────────────────────────────────────────────

  static const pf = AssetScreenConfig(
    title: "PF / EPF",
    collection: "pf_accounts",
    assetKey: "pf",
    accentColor: Colors.green,
    icon: Icons.account_balance_wallet,
    fabLabel: "Add PF Account",
    emptyMessage: "No PF accounts added",
    summaryLabel: "Total PF Corpus",
    fields: [
      AssetFieldDef(label: "Employer / organisation", key: "employer", required: true),
      AssetFieldDef(
          label: "Current balance",
          key: "balance",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Monthly employee contribution",
          key: "monthlyContribution",
          type: AssetFieldType.number),
    ],
  );

  static const vpf = AssetScreenConfig(
    title: "Voluntary PF (VPF)",
    collection: "vpf_accounts",
    assetKey: "vpf",
    accentColor: Color(0xFF81C784),
    icon: Icons.account_balance_wallet_outlined,
    fabLabel: "Add VPF",
    emptyMessage: "No VPF accounts added",
    summaryLabel: "Total VPF Balance",
    fields: [
      AssetFieldDef(label: "Employer", key: "employer", required: true),
      AssetFieldDef(
          label: "Current balance",
          key: "balance",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Monthly VPF contribution",
          key: "monthlyContribution",
          type: AssetFieldType.number),
    ],
  );

  static const nps = AssetScreenConfig(
    title: "NPS",
    collection: "nps_accounts",
    assetKey: "nps",
    accentColor: Colors.indigo,
    icon: Icons.elderly,
    fabLabel: "Add NPS Account",
    emptyMessage: "No NPS accounts added",
    summaryLabel: "Total NPS Corpus",
    fields: [
      AssetFieldDef(
        label: "Tier",
        key: "tier",
        type: AssetFieldType.dropdown,
        options: ["Tier I", "Tier II"],
      ),
      AssetFieldDef(label: "PRAN (optional)", key: "pran"),
      AssetFieldDef(
        label: "Fund manager",
        key: "fundManager",
        type: AssetFieldType.dropdown,
        options: ["SBI Pension", "LIC Pension", "HDFC Pension", "ICICI Pru Pension", "Kotak Pension", "Aditya Birla Pension", "UTI Retirement"],
      ),
      AssetFieldDef(
          label: "Current value",
          key: "currentValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Monthly contribution",
          key: "monthlyContribution",
          type: AssetFieldType.number),
    ],
  );

  // ── Alternative Assets ─────────────────────────────────────────────────────

  static const gold = AssetScreenConfig(
    title: "Gold / Silver",
    collection: "gold_holdings",
    assetKey: "gold",
    accentColor: Colors.amber,
    icon: Icons.grid_goldenratio,
    fabLabel: "Add Holding",
    emptyMessage: "No gold or silver holdings added",
    summaryLabel: "Total Gold / Silver Value",
    fields: [
      AssetFieldDef(
        label: "Form",
        key: "form",
        type: AssetFieldType.dropdown,
        options: ["Coins", "Bar / Biscuit", "Physical Jewellery", "Gold ETF", "Digital Gold", "Silver Coins", "Silver Bar"],
      ),
      AssetFieldDef(label: "Description", key: "description"),
      AssetFieldDef(
          label: "Weight (grams)",
          key: "weightGrams",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Current market value",
          key: "currentValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
    ],
  );

  static const sgb = AssetScreenConfig(
    title: "Sovereign Gold Bonds",
    collection: "sgb_holdings",
    assetKey: "sgb",
    accentColor: Color(0xFFFFCA28),
    icon: Icons.monetization_on,
    fabLabel: "Add SGB",
    emptyMessage: "No SGBs added",
    summaryLabel: "Total SGB Value",
    fields: [
      AssetFieldDef(label: "Series (e.g. SGB 2019-20 III)", key: "series", required: true),
      AssetFieldDef(
          label: "Units / grams",
          key: "units",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Current value",
          key: "currentValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Maturity date",
          key: "maturityDate",
          type: AssetFieldType.date),
    ],
  );

  static const jewelry = AssetScreenConfig(
    title: "Jewelry / Diamonds",
    collection: "jewelry_items",
    assetKey: "jewelry",
    accentColor: Color(0xFFF48FB1),
    icon: Icons.diamond,
    fabLabel: "Add Item",
    emptyMessage: "No jewelry items added",
    summaryLabel: "Total Jewelry Value",
    fields: [
      AssetFieldDef(label: "Description (e.g. Gold necklace)", key: "description", required: true),
      AssetFieldDef(
        label: "Material",
        key: "material",
        type: AssetFieldType.dropdown,
        options: ["Gold", "Silver", "Diamond", "Platinum", "Gemstone", "Mixed"],
      ),
      AssetFieldDef(label: "Weight (grams, optional)", key: "weightGrams"),
      AssetFieldDef(
          label: "Estimated value",
          key: "value",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
    ],
  );

  static const crypto = AssetScreenConfig(
    title: "Crypto",
    collection: "crypto_holdings",
    assetKey: "crypto",
    accentColor: Colors.deepOrange,
    icon: Icons.currency_bitcoin,
    fabLabel: "Add Crypto",
    emptyMessage: "No crypto holdings added",
    summaryLabel: "Total Crypto Value",
    fields: [
      AssetFieldDef(label: "Coin name (e.g. Bitcoin)", key: "coin", required: true),
      AssetFieldDef(label: "Ticker (e.g. BTC)", key: "ticker"),
      AssetFieldDef(
        label: "Exchange",
        key: "exchange",
        type: AssetFieldType.dropdown,
        options: ["WazirX", "CoinDCX", "Binance", "Coinbase", "Kraken", "Zebpay", "Other"],
      ),
      AssetFieldDef(
          label: "Quantity held",
          key: "quantity",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Current value (₹)",
          key: "currentValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
    ],
  );

  static const reit = AssetScreenConfig(
    title: "REITs",
    collection: "reit_holdings",
    assetKey: "reit",
    accentColor: Color(0xFF1DE9B6),
    icon: Icons.apartment,
    fabLabel: "Add REIT",
    emptyMessage: "No REITs added",
    summaryLabel: "Total REIT Value",
    fields: [
      AssetFieldDef(
        label: "REIT name",
        key: "name",
        type: AssetFieldType.dropdown,
        options: ["Embassy REIT", "Mindspace REIT", "Brookfield REIT", "Nexus Select Trust", "Other"],
      ),
      AssetFieldDef(
          label: "Units held",
          key: "units",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Current value",
          key: "currentValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
    ],
  );

  static const p2p = AssetScreenConfig(
    title: "P2P Lending",
    collection: "p2p_loans",
    assetKey: "p2p",
    accentColor: Colors.lime,
    icon: Icons.people_alt,
    fabLabel: "Add P2P Lending",
    emptyMessage: "No P2P lending entries added",
    summaryLabel: "Total Amount Lent",
    fields: [
      AssetFieldDef(
        label: "Platform",
        key: "platform",
        type: AssetFieldType.dropdown,
        options: ["Faircent", "CRED Mint", "LiquiLoans", "12% Club", "IndiaP2P", "RupeeCircle", "Other"],
      ),
      AssetFieldDef(
          label: "Amount lent",
          key: "amountLent",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Expected return (%)",
          key: "expectedReturn",
          type: AssetFieldType.number),
    ],
  );

  // ── Physical Assets ────────────────────────────────────────────────────────

  static const agriLand = AssetScreenConfig(
    title: "Agricultural Land",
    collection: "agri_land",
    assetKey: "agriLand",
    accentColor: Colors.green,
    icon: Icons.grass,
    fabLabel: "Add Land",
    emptyMessage: "No agricultural land added",
    summaryLabel: "Total Land Value",
    fields: [
      AssetFieldDef(label: "Location / village", key: "location", required: true),
      AssetFieldDef(label: "District / state", key: "district"),
      AssetFieldDef(
          label: "Area (acres)",
          key: "areaAcres",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Current market value",
          key: "currentValue",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
    ],
  );

  // ── Protection & Business ──────────────────────────────────────────────────

  static const business = AssetScreenConfig(
    title: "Business Capital",
    collection: "business_assets",
    assetKey: "business",
    accentColor: Color(0xFFA1887F),
    icon: Icons.business_center,
    fabLabel: "Add Business",
    emptyMessage: "No business assets added",
    summaryLabel: "Total Business Capital",
    fields: [
      AssetFieldDef(label: "Business name", key: "name", required: true),
      AssetFieldDef(
        label: "Structure",
        key: "structure",
        type: AssetFieldType.dropdown,
        options: ["Sole Proprietorship", "Partnership", "LLP", "Private Ltd", "Startup / Unregistered"],
      ),
      AssetFieldDef(label: "Industry / sector", key: "sector"),
      AssetFieldDef(
          label: "Capital invested",
          key: "capital",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
    ],
  );

  // ── Liabilities ────────────────────────────────────────────────────────────

  static const bnpl = AssetScreenConfig(
    title: "BNPL / Pay Later",
    collection: "bnpl_entries",
    assetKey: "bnpl",
    accentColor: Color(0xFFFF6E40),
    icon: Icons.schedule,
    fabLabel: "Add BNPL Entry",
    emptyMessage: "No BNPL entries added",
    summaryLabel: "Total Outstanding",
    fields: [
      AssetFieldDef(
        label: "Platform",
        key: "platform",
        type: AssetFieldType.dropdown,
        options: ["Simpl", "LazyPay", "ZestMoney", "Amazon Pay Later", "Flipkart Pay Later", "HDFC Pay Later", "ICICI Pay Later", "Other"],
      ),
      AssetFieldDef(
          label: "Outstanding amount",
          key: "outstanding",
          type: AssetFieldType.number,
          required: true,
          isAmountField: true),
      AssetFieldDef(
          label: "Credit limit (optional)",
          key: "creditLimit",
          type: AssetFieldType.number),
      AssetFieldDef(
          label: "Due date",
          key: "dueDate",
          type: AssetFieldType.date),
    ],
  );
}
