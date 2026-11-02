import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception("User has no email");
    }
    return _db
        .collection('users')
        .doc(email)
        .collection('wealth')
        .doc('portfolio');
  }

  /// Fetch the current portfolio, or return a default empty one if not found.
  static Future<WealthPortfolio> getPortfolio() async {
    final cached = LocalCacheService.get(_cacheKey);
    if (cached is Map) {
      final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(cached));
      return WealthPortfolio.fromMap(map);
    }
    try {
      final doc = await _portfolioRef.get();
      final data = doc.data() as Map<String, dynamic>?;
      if (doc.exists && data != null) {
        await LocalCacheService.put(_cacheKey, LocalCacheService.hiveSafe(data), ttl: LocalCacheService.wealth60);
        return WealthPortfolio.fromMap(data);
      }
    } catch (e) {
      log("Error fetching portfolio: $e");
    }
    return WealthPortfolio(lastUpdated: DateTime.now());
  }

  /// Update a specific asset value (e.g., 'sip', 'fd', etc.)
  /// True only when [snap] is an empty collection that came from the server
  /// rather than the local cache, and carries no local writes. A cached empty
  /// snapshot (cold cache, offline launch) must never sync a zero total,
  /// because that zero is then served back on every later read — and a snapshot
  /// with uncommitted local writes can look empty before the server has
  /// answered, which would clobber a just-written asset.
  static bool isServerConfirmedEmpty(QuerySnapshot<Object?> snap) =>
      snap.docs.isEmpty &&
      !snap.metadata.isFromCache &&
      !snap.metadata.hasPendingWrites;

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

  /// Persist the authoritative bank balance into the portfolio doc so the
  /// home widget and background workers can read it without scanning the
  /// whole transactions subcollection.
  static Future<void> updateBalance(double balance) async {
    try {
      await _portfolioRef.set({
        'balance': balance,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
      LocalCacheService.invalidate(_cacheKey);
    } catch (e) {
      log("Error updating balance: $e");
    }
  }

  /// Update a specific asset's target value manually.
  /// Firestore's merge only merges top-level maps, so we read the existing
  /// `targets` map first and merge the key into it — otherwise a single
  /// update would wipe every other asset target.
  static Future<void> updateAssetTarget(String key, double targetValue) async {
    try {
      final currentTargets = <String, dynamic>{};
      try {
        final existing = await _portfolioRef.get();
        final data = existing.data() as Map<String, dynamic>?;
        final existingTargets = data?['targets'];
        if (existingTargets is Map) {
          currentTargets.addAll(Map<String, dynamic>.from(existingTargets));
        }
      } catch (e) {
        log("Error reading targets for merge: $e");
      }
      currentTargets[key] = targetValue;
      await _portfolioRef.set({
        'targets': currentTargets,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
      LocalCacheService.invalidate(_cacheKey);
    } catch (e) {
      log("Error updating asset target $key: $e");
    }
  }

  /// Remove a manual asset target override, reverting to the formula target.
  static Future<void> removeAssetTarget(String key) async {
    try {
      await _portfolioRef.set({
        'targets.$key': FieldValue.delete(),
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
      LocalCacheService.invalidate(_cacheKey);
    } catch (e) {
      log("Error removing asset target $key: $e");
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
        .handleError((e) => log('WealthService streamPortfolio error: $e'))
        .map((doc) {
      final data = doc.data();
          if (doc.exists && data != null) {
            unawaited(
              LocalCacheService.put(
                _cacheKey,
                LocalCacheService.hiveSafe(data),
                ttl: LocalCacheService.wealth60,
              ).catchError((_) {}),
            );
            return WealthPortfolio.fromMap(data);
          }
          return WealthPortfolio(lastUpdated: DateTime.now());
        });
  }

  /// Calculate current bank balance from transaction history.
  ///
  /// Every row counts at its **net** value ([TransactionModel.total] =
  /// `amount - tax`): an expense is already stored negative, so adding `total`
  /// subtracts the amount *and* the tax withheld, and an income credit adds
  /// what actually landed after TDS. The old code used `amount.abs()` for
  /// income, which reported the gross salary and ignored the TDS deduction.
  ///
  /// [uid] defaults to the signed-in user and exists so the arithmetic can be
  /// tested without Firebase (`FirebaseAuth.instance` throws with no app).
  static double calculateBankBalance(
    List<TransactionModel> transactions, {
    String? uid,
  }) {
    final owner = uid ?? _auth.currentUser?.uid;
    if (owner == null) return 0;

    double balance = 0;

    try {
      for (final tx in transactions) {
        // A self-transfer matches both ids; `||` keeps it counted once.
        if (tx.senderId == owner || tx.recipientId == owner) {
          balance += tx.total;
        }
      }
    } catch (e) {
      log("Error calculating bank balance: $e");
    }
    return balance;
  }

  /// Average monthly income over the last [months] calendar months.
  ///
  /// Divides by the number of months that actually have income, not by
  /// [months]: a user three weeks into the app has one month of data, and
  /// dividing by three reported a third of their real income. Refunds and
  /// transfers are excluded ([isNonIncomeCategory]) — they reuse the shape of
  /// an income credit without being income.
  static double calculateAverageMonthlyIncome(
    List<TransactionModel> transactions, {
    int months = 3,
    DateTime? now,
    String? uid,
  }) {
    final owner = uid ?? _auth.currentUser?.uid;
    if (owner == null || months <= 0) return 0;

    final ref = now ?? DateTime.now();
    final floor = DateTime(ref.year, ref.month - (months - 1), 1);
    final ceiling = DateTime(ref.year, ref.month + 1, 1);
    try {
      final buckets = <int, double>{};
      for (final tx in transactions) {
        if (tx.recipientId != owner) continue;
        if (tx.amount <= 0) continue;
        if (isNonIncomeCategory(tx.category)) continue;
        if (tx.date.isBefore(floor) || !tx.date.isBefore(ceiling)) continue;
        final key = tx.date.year * 100 + tx.date.month;
        buckets[key] = (buckets[key] ?? 0) + tx.total;
      }
      if (buckets.isEmpty) return 0;
      final total = buckets.values.fold<double>(0, (acc, v) => acc + v);
      return total / buckets.length;
    } catch (e) {
      log("Error calculating monthly income: $e");
      return 0;
    }
  }

  /// The currency symbol, or an empty string when the controller is not
  /// registered yet.
  ///
  /// This used to be a `Get.find<CurrencyController>()` *inside* the insight
  /// generator's `try`: on a path where the controller was missing, the throw
  /// was caught as "Error generating insights" and every insight silently
  /// disappeared.
  static String _currencySymbol() {
    if (!Get.isRegistered<CurrencyController>()) return '';
    try {
      return Get.find<CurrencyController>().currencySymbol.value;
    } catch (_) {
      return '';
    }
  }

  /// Generate smart financial insights based on transaction history and current portfolio
  static List<Map<String, dynamic>> generateSmartInsights(
    WealthPortfolio portfolio,
    List<TransactionModel> transactions,
  ) {
    final user = _auth.currentUser;
    if (user == null) return [];

    // Resolved before the try: a missing controller used to throw inside it,
    // which the catch reported as a failed insight pass and returned no
    // insights at all.
    final symbol = _currencySymbol();
    List<Map<String, dynamic>> insights = [];

    try {
      final now = DateTime.now();
      // Calendar months, not a rolling 90-day window: the window used to start
      // mid-month, so the same salary dropped out of the savings rate halfway
      // through the next month.
      final floor = DateTime(now.year, now.month - 2, 1);
      final ceiling = DateTime(now.year, now.month + 1, 1);

      final recentTx = transactions
          .where(
            (tx) =>
                !tx.date.isBefore(floor) && tx.date.isBefore(ceiling),
          )
          .toList();

      double totalIncome = 0;
      double totalExpense = 0;
      final incomeMonths = <int>{};
      final expenseMonths = <int>{};
      Map<String, double> categoryExpenses = {};

      for (var tx in recentTx) {
        final amount = tx.amount.abs();
        final monthKey = tx.date.year * 100 + tx.date.month;

        if (tx.recipientId == user.uid) {
          // Refunds/transfers arrive shaped like income but are the user's own
          // money coming back; counting them inflates the savings rate.
          if (isNonIncomeCategory(tx.category)) continue;
          totalIncome += tx.total.abs();
          incomeMonths.add(monthKey);
        } else if (tx.senderId == user.uid) {
          totalExpense += amount;
          expenseMonths.add(monthKey);
          final cat = tx.category ?? 'Uncategorized';
          categoryExpenses[cat] = (categoryExpenses[cat] ?? 0) + amount;
        }
      }

      // Divide by the months that have data — a user one month in must not be
      // told their income is a third of what it is.
      final incomeMonthsCount = incomeMonths.isEmpty ? 1 : incomeMonths.length;
      final expenseMonthsCount = expenseMonths.isEmpty ? 1 : expenseMonths.length;
      final avgMonthlyIncome = totalIncome / incomeMonthsCount;
      final avgMonthlyExpense = totalExpense / expenseMonthsCount;
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
              "📈 Idle Cash? You save ~$symbol${avgMonthlySavings.toStringAsFixed(0)}/mo. Consider starting a new SIP of $symbol${(avgMonthlySavings * 0.4).toStringAsFixed(0)}.",
        });
      }

      if (categoryExpenses.isNotEmpty) {
        final sortedCats = categoryExpenses.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topCat = sortedCats.first;
        final topCatShare = avgMonthlyExpense > 0
            ? (topCat.value / expenseMonthsCount) / avgMonthlyExpense
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
              "💳 High CC Debt: $symbol${portfolio.creditCard.toStringAsFixed(0)} outstanding. Pay this off first — credit card rates (36–48% p.a.) beat any investment return.",
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

  /// Calculate target values based on User Formulas OR Custom Overrides.
  ///
  /// [useOverrides] decides whether a user's manual per-asset target applies.
  /// Smart Mode is formula-only by definition, so the caller passes `false`
  /// there: a target entered in Custom Mode used to keep overriding the
  /// formula after switching back, leaving the progress bars on stale numbers
  /// while the UI claimed the recommendation was in charge.
  static Future<Map<String, WealthTarget>> calculateAssetTargets(
    WealthPortfolio portfolio,
    List<TransactionModel> transactions,
    UserModel? userProfile, {
    int baselineMonthlyIncome = 25000,
    double bankBalance = 0,
    bool useOverrides = true,
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

      // Cap gold / SGB at 10% of visible net worth so alternatives never
      // dwarf the emergency fund or retirement base before it is built. With
      // no net worth there is nothing to cap against: a 0 cap used to zero the
      // whole goal, so a brand-new user's gold target read as already complete.
      double visible(String key, double val) =>
          portfolio.hiddenKeys.contains(key) ? 0.0 : val;
      final double visibleNetWorth =
          visible('sip', portfolio.sip) +
          visible('fd', portfolio.fd) +
          visible('stocks', portfolio.stocks) +
          visible('pf', portfolio.pf) +
          visible('crypto', portfolio.crypto) +
          visible('gold', portfolio.gold) +
          visible('realEstate', portfolio.realEstate) +
          visible('nps', portfolio.nps) +
          visible('etf', portfolio.etf) +
          visible('reit', portfolio.reit) +
          visible('p2p', portfolio.p2p) +
          visible('ppf', portfolio.ppf) +
          visible('sgb', portfolio.sgb) +
          visible('bonds', portfolio.bonds) +
          visible('foreignStocks', portfolio.foreignStocks) +
          visible('vpf', portfolio.vpf) +
          visible('postOffice', portfolio.postOffice) +
          visible('chitFund', portfolio.chitFund) +
          visible('startupEquity', portfolio.startupEquity) +
          visible('business', portfolio.business) +
          visible('vehicle', portfolio.vehicle) +
          visible('jewelry', portfolio.jewelry) +
          visible('agriLand', portfolio.agriLand) +
          bankBalance +
          portfolio.custom.entries.fold(
            0,
            (accum, e) =>
                portfolio.hiddenKeys.contains(e.key) ? accum : accum + e.value,
          ) -
          visible('loans', portfolio.loans) -
          visible('creditCard', portfolio.creditCard) -
          visible('bnpl', portfolio.bnpl);
      // `infinity` means "no cap": with no visible net worth the formula target
      // stands instead of collapsing to zero.
      final goldCap = visibleNetWorth > 0
          ? 0.10 * visibleNetWorth
          : double.infinity;

      final result = <String, WealthTarget>{};
      formulaTargets.forEach((key, val) {
        final bool est = !alwaysZero.contains(key) && usingEstimate &&
            !expenseBased.contains(key);
        double effectiveVal = val;
        if (key == 'gold' || key == 'sgb') {
          effectiveVal = val > goldCap ? goldCap : val;
        }
        result[key] = WealthTarget(
          effective: effectiveVal,
          formula: val,
          isOverridden: false,
          isEstimated: est,
        );
      });

      // Apply manual target overrides from portfolio.targets. The bank card
      // drives its input through monthlyExpenseOverride instead, so it stays
      // formula-driven here. Custom keys not in formulaTargets get a target
      // that is pure override (formula 0) so their cards show progress.
      //
      // Only in Custom Mode: Smart Mode is the formula by definition, and an
      // override left over from Custom Mode must not keep overriding it.
      if (useOverrides) {
        portfolio.targets.forEach((key, override) {
          if (key == 'bank') return;
          final double value = override.toDouble();
          if (value <= 0) return;
          result[key] = WealthTarget(
            effective: value,
            formula: result[key]?.formula ?? 0.0,
            isOverridden: true,
          );
        });
      }

      return result;
    } catch (e) {
      log("Error calculating targets: $e");
      return {};
    }
  }
}
