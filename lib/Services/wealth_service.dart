import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Models/wealth_data.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Models/user_model.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Utils/wealth_math.dart';

class WealthTarget {
  final double effective;
  final double formula;
  final bool isOverridden;
  /// True when calculated from a geo-baseline rather than real transaction data
  final bool isEstimated;

  WealthTarget({
    required this.effective,
    required this.formula,
    required this.isOverridden,
    this.isEstimated = false,
  });
}

class WealthService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _userEmail => _auth.currentUser?.email;
  static String get _cacheKey => 'portfolio_${_userEmail ?? ''}';

  // ── Age-milestone tables ────────────────────────────────────────────────
  // Values sourced from lib/Utils/wealth_math.dart (Fidelity model for India).
  // Linear interpolation via milestone() in the same file.

  static DocumentReference get _portfolioRef {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    return _db
        .collection('users')
        .doc(user.email)
        .collection('wealth')
        .doc('portfolio');
  }

  /// Fetch the current portfolio, or return a default empty one if not found.
  static Future<WealthPortfolio> getPortfolio() async {
    final cached = LocalCacheService.get(_cacheKey);
    if (cached != null) {
      final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(cached as Map));
      return WealthPortfolio.fromMap(map);
    }
    try {
      final doc = await _portfolioRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        LocalCacheService.put(_cacheKey, LocalCacheService.hiveSafe(data), ttl: LocalCacheService.wealth60);
        return WealthPortfolio.fromMap(data);
      }
    } catch (e) {
      log("Error fetching portfolio: $e");
    }
    return WealthPortfolio(lastUpdated: DateTime.now());
  }

  /// Update a specific asset value (e.g., 'sip', 'fd', etc.)
  static Future<void> updateAsset(String key, double value) async {
    try {
      await _portfolioRef.set({
        key: value,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
      LocalCacheService.invalidate(_cacheKey);
    } catch (e) {
      log("Error updating asset $key: $e");
    }
  }

  /// Add or update a custom asset entry in the custom map
  static Future<void> setCustomAsset(String key, double value) async {
    try {
      await _portfolioRef.set({
        'custom.$key': value,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
      LocalCacheService.invalidate(_cacheKey);
    } catch (e) {
      log("Error setting custom asset $key: $e");
    }
  }

  /// Remove a custom asset entry from the custom map
  static Future<void> deleteCustomAsset(String key) async {
    try {
      await _portfolioRef.set({
        'custom.$key': FieldValue.delete(),
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
      LocalCacheService.invalidate(_cacheKey);
    } catch (e) {
      log("Error deleting custom asset $key: $e");
    }
  }

  /// Update a specific asset's target value manually
  static Future<void> updateAssetTarget(String key, double targetValue) async {
    try {
      await _portfolioRef.set({
        'targets': {key: targetValue},
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
      LocalCacheService.invalidate(_cacheKey);
    } catch (e) {
      log("Error updating asset target $key: $e");
    }
  }

  /// Update the monthly expense override value
  static Future<void> updateMonthlyExpenseOverride(double? value) async {
    try {
      final data = <String, dynamic>{'lastUpdated': Timestamp.now()};
      if (value == null || value <= 0) {
        data['monthly_expense_override'] = FieldValue.delete();
      } else {
        data['monthly_expense_override'] = value;
      }
      await _portfolioRef.set(data, SetOptions(merge: true));
      LocalCacheService.invalidate(_cacheKey);
    } catch (e) {
      log("Error updating monthly expense override: $e");
    }
  }

  /// Update the list of hidden assets
  static Future<void> updateHiddenAssets(List<String> keys) async {
    try {
      await _portfolioRef.set({
        'hiddenKeys': keys,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
      LocalCacheService.invalidate(_cacheKey);
    } catch (e) {
      log("Error updating hidden assets: $e");
    }
  }

  /// Stream portfolio for real-time updates
  static Stream<WealthPortfolio> streamPortfolio() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(user.email)
        .collection('wealth')
        .doc('portfolio')
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data() as Map<String, dynamic>;
            LocalCacheService.put(_cacheKey, LocalCacheService.hiveSafe(data), ttl: LocalCacheService.wealth60);
            return WealthPortfolio.fromMap(data);
          }
          return WealthPortfolio(lastUpdated: DateTime.now());
        });
  }

  /// Calculate current bank balance from transaction history
  static double calculateBankBalance(List<TransactionModel> transactions) {
    final user = _auth.currentUser;
    if (user == null) return 0;

    double balance = 0;

    try {
      for (final tx in transactions) {
        if (tx.senderId == user.uid) {
          balance -= tx.amount.abs();
          balance -= tx.tax;
        }
        if (tx.recipientId == user.uid) {
          balance += tx.amount.abs();
        }
      }
    } catch (e) {
      log("Error calculating bank balance: $e");
    }
    return balance;
  }

  /// Generate smart financial insights based on transaction history and current portfolio
  static List<Map<String, dynamic>> generateSmartInsights(
    WealthPortfolio portfolio,
    List<TransactionModel> transactions,
  ) {
    final user = _auth.currentUser;
    if (user == null) return [];

    List<Map<String, dynamic>> insights = [];

    try {
      final now = DateTime.now();
      final threeMonthsAgo = now.subtract(const Duration(days: 90));

      final recentTx = transactions.where((tx) {
        return tx.date.isAfter(threeMonthsAgo);
      }).toList();

      double totalIncome = 0;
      double totalExpense = 0;
      Map<String, double> categoryExpenses = {};

      for (var tx in recentTx) {
        final amount = tx.amount.abs();

        if (tx.recipientId == user.uid) {
          totalIncome += amount;
        } else if (tx.senderId == user.uid) {
          totalExpense += amount;
          final cat = tx.category ?? 'Uncategorized';
          categoryExpenses[cat] = (categoryExpenses[cat] ?? 0) + amount;
        }
      }

      final avgMonthlyIncome = totalIncome / 3;
      final avgMonthlyExpense = totalExpense / 3;
      final avgMonthlySavings = avgMonthlyIncome - avgMonthlyExpense;
      final savingsRate = avgMonthlyIncome > 0
          ? (avgMonthlySavings / avgMonthlyIncome)
          : 0.0;

      if (savingsRate < 0.2 && avgMonthlyIncome > 0) {
        insights.add({
          'type': 'warning',
          'message':
              "⚠️ Low Savings Rate: You're saving only ${(savingsRate * 100).toStringAsFixed(1)}% of income. Aim for at least 20%.",
        });
      } else if (savingsRate > 0.4) {
        insights.add({
          'type': 'success',
          'message':
              "🌟 Great Savings! You're saving ${(savingsRate * 100).toStringAsFixed(0)}% of income. Consider boosting SIPs.",
        });
      }

      double getVisible(String key, double val) =>
          portfolio.hiddenKeys.contains(key) ? 0.0 : val;

      final visibleTotal =
          getVisible('sip', portfolio.sip) +
          getVisible('fd', portfolio.fd) +
          getVisible('stocks', portfolio.stocks) +
          getVisible('pf', portfolio.pf) +
          getVisible('crypto', portfolio.crypto) +
          getVisible('gold', portfolio.gold) +
          getVisible('realEstate', portfolio.realEstate) +
          getVisible('nps', portfolio.nps) +
          getVisible('etf', portfolio.etf) +
          getVisible('reit', portfolio.reit) +
          getVisible('p2p', portfolio.p2p) +
          getVisible('ppf', portfolio.ppf) +
          getVisible('sgb', portfolio.sgb) +
          getVisible('bonds', portfolio.bonds) +
          getVisible('insurance', portfolio.insurance) +
          getVisible('foreignStocks', portfolio.foreignStocks) +
          getVisible('vpf', portfolio.vpf) +
          getVisible('postOffice', portfolio.postOffice) +
          getVisible('chitFund', portfolio.chitFund) +
          getVisible('startupEquity', portfolio.startupEquity) +
          getVisible('business', portfolio.business) +
          getVisible('vehicle', portfolio.vehicle) +
          getVisible('jewelry', portfolio.jewelry) +
          getVisible('agriLand', portfolio.agriLand) +
          portfolio.custom.entries.fold(
            0,
            (accum, e) =>
                portfolio.hiddenKeys.contains(e.key) ? accum : accum + e.value,
          );

      final totalInvested = visibleTotal;
      if (avgMonthlySavings > avgMonthlyExpense * 0.2 &&
          totalInvested < avgMonthlySavings * 6 &&
          !portfolio.hiddenKeys.contains('sip')) {
        insights.add({
          'type': 'info',
          'message':
              "📈 Idle Cash? You save ~${Get.find<CurrencyController>().currencySymbol.value}${avgMonthlySavings.toStringAsFixed(0)}/mo. Consider starting a new SIP of ${Get.find<CurrencyController>().currencySymbol.value}${(avgMonthlySavings * 0.4).toStringAsFixed(0)}.",
        });
      }

      if (categoryExpenses.isNotEmpty) {
        final sortedCats = categoryExpenses.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topCat = sortedCats.first;
        final topCatShare = avgMonthlyExpense > 0
            ? (topCat.value / 3) / avgMonthlyExpense
            : 0;

        if (topCatShare > 0.25 &&
            topCat.key != 'Rent' &&
            topCat.key != 'Bills' &&
            !portfolio.hiddenKeys.contains('gold')) {
          insights.add({
            'type': 'alert',
            'message':
                "✂️ High Spending: '${topCat.key}' is ${(topCatShare * 100).toStringAsFixed(0)}% of your expenses. Cutting this could fund a Gold ETF.",
          });
        }
      }

      if (visibleTotal > 0) {
        if (!portfolio.hiddenKeys.contains('crypto') &&
            portfolio.crypto / visibleTotal > 0.15) {
          insights.add({
            'type': 'warning',
            'message':
                "⚠️ Crypto Alert: Crypto is ${(portfolio.crypto / visibleTotal * 100).toStringAsFixed(0)}% of assets. High risk!",
          });
        }
        if (!portfolio.hiddenKeys.contains('fd') &&
            portfolio.fd / visibleTotal > 0.60) {
          insights.add({
            'type': 'info',
            'message':
                "🔒 Low Growth: Heavy FD allocation. Stocks/Mutual Funds might beat inflation better.",
          });
        }
        if (!portfolio.hiddenKeys.contains('foreignStocks') &&
            portfolio.foreignStocks / visibleTotal < 0.05) {
          insights.add({
            'type': 'info',
            'message':
                "🌍 No Global Exposure: Consider 5–10% in US/global stocks for geographic diversification.",
          });
        }
      }

      // Insurance check (independent of visibleTotal)
      if (!portfolio.hiddenKeys.contains('insurance') &&
          portfolio.insurance == 0) {
        insights.add({
          'type': 'warning',
          'message':
              "🛡️ No Insurance Tracked: Add your life insurance / ULIP surrender value. Aim for at least 10× annual income in coverage.",
        });
      }

      // Credit card debt check
      if (!portfolio.hiddenKeys.contains('creditCard') &&
          portfolio.creditCard > 0 &&
          avgMonthlyExpense > 0 &&
          portfolio.creditCard > avgMonthlyExpense * 0.5) {
        insights.add({
          'type': 'warning',
          'message':
              "💳 High CC Debt: ${CurrencyController.to.currencySymbol.value}${portfolio.creditCard.toStringAsFixed(0)} outstanding. Pay this off first — credit card rates (36–48% p.a.) beat any investment return.",
        });
      }

      if (insights.isEmpty) {
        insights.add({
          'type': 'success',
          'message':
              "✅ Your financial health looks stable based on recent activity.",
        });
      }
    } catch (e) {
      log("Error generating insights: $e");
    }

    return insights;
  }

  /// Calculate target values based on User Formulas OR Custom Overrides
  static Future<Map<String, WealthTarget>> calculateAssetTargets(
    WealthPortfolio portfolio,
    List<TransactionModel> transactions,
    UserModel? userProfile, {
    int baselineMonthlyIncome = 25000,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final now = DateTime.now();
      final threeMonthsAgo = now.subtract(const Duration(days: 90));

      // Filter transactions in memory
      double totalExpense = 0;
      for (var tx in transactions) {
        if (tx.senderId == user.uid && tx.date.isAfter(threeMonthsAgo)) {
          totalExpense += tx.amount.abs();
        }
      }

      final monthlyExpense = totalExpense / 3;

      // Use passed user profile
      final userAge =
          userProfile?.calculatedAge; // Use getter if available or logic
      final int age = (userAge is int && userAge > 0) ? userAge : 30;

      // Use monthlyExpenseOverride from the portfolio doc, or fall back to
      // computed monthly expense from transactions. If neither has data, use
      // geo-baseline (passed as baselineMonthlyIncome).
      final double rawMonthlyExpense =
          portfolio.monthlyExpenseOverride ?? monthlyExpense;
      final bool usingEstimate = rawMonthlyExpense <= 0;
      final double effectiveMonthlyExpense =
          usingEstimate ? baselineMonthlyIncome.toDouble() : rawMonthlyExpense;
      final annualExpense = effectiveMonthlyExpense * 12;

      // Age-based emergency fund multiplier (months)
      final int cashMonths = age < 30 ? 3 : age > 50 ? 12 : 6;

      // Every target = milestone(age, table) × annualExpense.
      // Targets grow with age, NOT with net worth.
      double m(Map<int, double> table) =>
          milestone(age, table) * annualExpense;

      final formulaTargets = {
        // ── Liquidity (expense × months, geo-scaled) ──────────────────────
        'bank':       effectiveMonthlyExpense * cashMonths,
        'fd':         effectiveMonthlyExpense * 3,
        'postOffice': effectiveMonthlyExpense * 2,

        // ── Age-milestone investments (× annual expense) ───────────────────
        'sip':           m(sipM),
        'stocks':        m(stocksM),
        'etf':           m(etfM),
        'foreignStocks': m(foreignM),
        'startupEquity': m(startupM),
        'pf':            m(pfM),
        'ppf':           m(ppfM),
        'vpf':           m(vpfM),
        'nps':           m(npsM),
        'bonds':         m(bondsM),
        'gold':          m(goldM),
        'sgb':           m(sgbM),
        'crypto':        m(cryptoM),
        'reit':          m(reitM),
        'p2p':           m(p2pM),
        'insurance':     m(insuranceM),

        // ── Tracked only — no prescriptive target ─────────────────────────
        'realEstate':  0.0,
        'agriLand':    0.0,
        'vehicle':     0.0,
        'jewelry':     0.0,
        'chitFund':    0.0,
        'business':    0.0,

        // ── Liabilities — goal is always zero ─────────────────────────────
        'loans':      0.0,
        'creditCard': 0.0,
        'bnpl':       0.0,
      };

      const alwaysZero = {
        'realEstate', 'agriLand', 'vehicle', 'jewelry',
        'chitFund', 'business', 'loans', 'creditCard', 'bnpl',
      };
      const expenseBased = {'bank', 'fd', 'postOffice'};

      final result = <String, WealthTarget>{};
      formulaTargets.forEach((key, val) {
        final bool est = !alwaysZero.contains(key) && usingEstimate &&
            !expenseBased.contains(key);
        result[key] = WealthTarget(
          effective: val,
          formula: val,
          isOverridden: false,
          isEstimated: est,
        );
      });

      return result;
    } catch (e) {
      log("Error calculating targets: $e");
      return {};
    }
  }
}
