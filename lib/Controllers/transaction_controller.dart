import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:money_control/Models/cateogary.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Repositories/transaction_repository.dart';
import 'package:money_control/Services/budget_service.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Services/local_backup_service.dart';
import 'package:money_control/Services/offline_queue.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Services/background_worker.dart';
import 'package:money_control/Services/widget_service.dart';
import 'package:money_control/Services/wealth_service.dart';
import 'package:money_control/Services/feature_flag_service.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/privacy_controller.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Screens/subscription_screen.dart';
import 'package:money_control/Utils/num_parse.dart';
import 'package:money_control/Utils/home_math.dart';
import 'package:money_control/Services/app_analytics.dart';

class TransactionController extends GetxController {
  final TransactionRepository _repository = TransactionRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final SubscriptionController _subscriptionController;

  // Cache
  String? get _userEmail => _auth.currentUser?.email;
  String get _cacheKey => 'transactions_${_userEmail ?? ''}';

  // State
  var transactions = <TransactionModel>[].obs;
  var categories = <CategoryModel>[].obs;
  var isLoading = false.obs;
  var isSaving = false.obs;
  var streakCount = 0.obs;

  // Sorted categories by usage
  var sortedCategoryNames = <String>[].obs;
  final totalBalanceRx = 0.0.obs;

  // ── Home overview, derived once per transaction change ──────────────────
  // The home widgets read these instead of re-scanning `transactions` inside
  // their build methods. `hasLoadedOnce` distinguishes "stream has not emitted
  // yet" from "the user really has no transactions", so the home screen never
  // claims an empty account on a cold start.
  final monthSpendRx = 0.0.obs;
  final monthIncomeRx = 0.0.obs;
  final RxnDouble momPercentRx = RxnDouble();
  final recentTransactions = <TransactionModel>[].obs;
  final hasLoadedOnce = false.obs;
  final isStreamDead = false.obs;

  /// Pull-to-refresh in progress. Deliberately separate from [isLoading]:
  /// [isLoading] means "nothing to show yet" and blanks the cards, which is
  /// the wrong signal when a refresh already has data on screen.
  final isRefreshing = false.obs;

  late final Worker _categoriesWorker;
  late final Worker _transactionsWorker;
  late final Worker _balanceWorker;
  StreamSubscription? _txSub;
  StreamSubscription? _catSub;

  @override
  void onInit() {
    super.onInit();
    _subscriptionController = Get.find<SubscriptionController>();
    _loadFromCache();
    // `isLoading` means "no data yet", never "refreshing": the pull-to-refresh
    // path must not blank the cards. A warm cache means there is something to
    // show immediately.
    isLoading.value = transactions.isEmpty;
    bindTransactions();
    bindCategories();
    // Categories change rarely: only the quick-send ordering depends on them.
    _categoriesWorker = debounce(
      categories,
      (_) => fetchSortedCategories(),
      time: const Duration(milliseconds: 300),
    );
    // A transaction changes the usage ranking too (it used to be recomputed
    // only when *categories* changed, so an import/SMS/restore/recurring write
    // left the quick-send order stale for the whole session) plus the OS
    // widget. Both are debounced so a bulk import does not thrash them.
    _transactionsWorker = debounce(
      transactions,
      (_) {
        fetchSortedCategories();
        _updateHomeWidget();
      },
      time: const Duration(milliseconds: 500),
    );
    _recomputeDerived();
    _balanceWorker = ever(transactions, (_) => _recomputeDerived());
    // Hydrate the streak the write path stores on the user doc; without this
    // the 🔥 row stayed invisible until the next transaction was saved.
    unawaited(_hydrateStreak());
  }

  /// Recomputes every value the home screen shows in one pass.
  ///
  /// Single owner of the transaction stream means this is the one place that
  /// scans the list; widgets read the cached Rx values.
  void _recomputeDerived() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      totalBalanceRx.value = 0.0;
      monthSpendRx.value = 0.0;
      monthIncomeRx.value = 0.0;
      momPercentRx.value = null;
      recentTransactions.clear();
      return;
    }

    // Matches WealthService.calculateBankBalance: `total` (amount - tax) and a
    // self-transfer counted once. The previous sender/recipient branches
    // disagreed with the wealth builder on any taxed transaction.
    double balance = 0.0;
    for (final tx in transactions) {
      if (tx.senderId == uid || tx.recipientId == uid) {
        balance += tx.total;
      }
    }
    totalBalanceRx.value = balance;

    final summary = summarizeHomeMonth(transactions, uid: uid);
    monthSpendRx.value = summary.spend;
    monthIncomeRx.value = summary.income;
    momPercentRx.value = summary.momPercent;
    recentTransactions.assignAll(
      selectRecentTransactions(transactions, uid: uid),
    );
  }

  /// Reads the streak the write path persists on `users/{email}`.
  ///
  /// A streak older than yesterday is already broken: `_updateStreak` resets
  /// it on the next save, but the home card must not keep advertising a stale
  /// "12 day streak" in the meantime.
  Future<void> _hydrateStreak() async {
    final email = _userEmail;
    if (email == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();
      final data = doc.data();
      if (data == null) return;
      final count = safeToInt(data['streakCount']);
      final rawTs = data['lastStreakDate'];
      final lastTs = rawTs is Timestamp ? rawTs : null;
      if (lastTs == null) {
        streakCount.value = 0;
        return;
      }
      final today = DateTime.now();
      final lastDay = DateTime(
        lastTs.toDate().year,
        lastTs.toDate().month,
        lastTs.toDate().day,
      );
      final yesterday = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 1));
      streakCount.value = lastDay.isBefore(yesterday) ? 0 : count;
    } catch (e) {
      debugPrint('Streak hydrate error: $e');
    }
  }

  void _loadFromCache() {
    final cached = LocalCacheService.get(_cacheKey);
    if (cached is List) {
      transactions.value = cached.whereType<Map>().map((e) {
        final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(e));
        final id = map.remove('_id') as String? ?? '';
        return TransactionModel.fromMap(id, map);
      }).toList();
      // Cached rows are renderable immediately; the live snapshot replaces
      // them. Marking this here is what keeps a cold/offline launch from
      // flashing "You haven't made any transactions yet".
      if (transactions.isNotEmpty) hasLoadedOnce.value = true;
    }
    LocalCacheService.invalidate(_cacheKey);
  }

  @override
  void onClose() {
    _categoriesWorker.dispose();
    _transactionsWorker.dispose();
    _balanceWorker.dispose();
    _txRetryTimer?.cancel();
    _catRetryTimer?.cancel();
    _txSub?.cancel();
    _catSub?.cancel();
    super.onClose();
  }

  // Derived State
  double get totalBalance => totalBalanceRx.value;

  /// Pull-to-refresh.
  ///
  /// It used to sleep 1.5 s to "show the shimmer" and then re-sort categories,
  /// which is why a pull could not fix a dead stream, an offline queue or a
  /// stale streak. It now re-binds a stream that gave up, re-reads the streak
  /// and recomputes the cached overview — without flipping [isLoading], so the
  /// cards keep showing the data the user already has.
  Future<void> refreshData() async {
    if (isRefreshing.value) return;
    isRefreshing.value = true;
    try {
      refreshStreamsIfDead();
      fetchSortedCategories();
      _recomputeDerived();
      await _hydrateStreak();
    } catch (e) {
      debugPrint('TransactionController.refreshData error: $e');
    } finally {
      isRefreshing.value = false;
    }
  }

  /// Re-opens the transaction/category listeners after the retry budget ran
  /// out (or the subscription was never created). Called from pull-to-refresh,
  /// app resume and reconnect — the three moments where recovery is possible.
  void refreshStreamsIfDead() {
    try {
      if (isStreamDead.value || _txSub == null) {
        _txRetryCount = 0;
        isStreamDead.value = false;
        bindTransactions();
      }
      if (_catSub == null) {
        _catRetryCount = 0;
        bindCategories();
      }
    } catch (e) {
      // Called from reconnect, resume and pull-to-refresh — an escaping error
      // there would take down an app-lifecycle callback.
      debugPrint('TransactionController.refreshStreamsIfDead error: $e');
      isStreamDead.value = true;
    }
  }

  int _txRetryCount = 0;
  static const int _txMaxRetries = 5;
  Timer? _txRetryTimer;

  void bindTransactions() {
    _txSub?.cancel();
    _txRetryTimer?.cancel();
    _txSub = _repository.getTransactionsStream().listen(
      (txList) async {
        transactions.value = txList;
        isStreamDead.value = false;
        hasLoadedOnce.value = true;
        // The first snapshot (even an empty one) is a real answer: the account
        // is loaded and the loading placeholders must come down.
        isLoading.value = false;
        _txRetryCount = 0;
        if (_userEmail != null) {
          final cacheData = txList.map((t) {
            final map = t.toMap();
            map['_id'] = t.id;
            return LocalCacheService.hiveSafe(map);
          }).toList();
          await LocalCacheService.put(
            _cacheKey,
            cacheData,
            ttl: LocalCacheService.txs30,
          );
        }
      },
      onDone: () {
        debugPrint(
          'TransactionController transactions stream closed; retrying',
        );
        _scheduleTxRetry();
      },
      onError: (e) {
        debugPrint('TransactionController stream error: $e');
        _scheduleTxRetry();
      },
    );
  }

  /// Force a fresh fetch of transactions from Firestore, bypassing the
  /// "stream is alive" check in [refreshData]. Used by AI Insights so the
  /// refresh button always re-reads the latest data instead of recomputing
  /// from a potentially stale cache.
  Future<void> forceRefreshTransactions() async {
    bindTransactions();
    // Wait for the new stream to emit at least once so the caller can
    // recompute with fresh data. Cap the wait at 8 seconds.
    final completer = Completer<void>();
    late final StreamSubscription<List<TransactionModel>> sub;
    sub = transactions.stream.listen(
      (_) {
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      },
    );
    await completer.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  void _scheduleTxRetry() {
    _txRetryTimer?.cancel();
    if (_txRetryCount >= _txMaxRetries) {
      // Out of retries: stop hammering and let the UI offer a manual retry.
      // Without this flag the home screen shimmered forever.
      isStreamDead.value = true;
      isLoading.value = false;
      return;
    }
    _txRetryCount++;
    _txRetryTimer = Timer(Duration(seconds: kIsWeb ? 5 : 3), bindTransactions);
  }

  void _updateHomeWidget() {
    try {
      // The portfolio doc is authoritative for background workers, so it is
      // written regardless of any UI feature flag. The OS widget push is the
      // only part a `hidden` home_widget kill-switch removes.
      WealthService.updateBalance(totalBalance);
      if (Get.isRegistered<FeatureFlagService>() &&
          FeatureFlagService.to.isHidden('home_widget')) {
        return;
      }
      final sym = CurrencyController.to.currencySymbol.value;
      final masked = Get.isRegistered<PrivacyController>() &&
          Get.find<PrivacyController>().isPrivacyMode.value;
      WidgetService.updateBalance(totalBalance, sym, masked: masked);
    } catch (e) {
      debugPrint('TransactionController._updateHomeWidget error: $e');
    }
  }

  int _catRetryCount = 0;
  static const int _catMaxRetries = 5;
  Timer? _catRetryTimer;

  void bindCategories() {
    _catSub?.cancel();
    _catRetryTimer?.cancel();
    _catSub = _repository.getCategoriesStream().listen(
      (catList) {
        categories.value = catList;
        _catRetryCount = 0;
      },
      onDone: () {
        debugPrint('TransactionController categories stream closed; retrying');
        _scheduleCatRetry();
      },
      onError: (e) {
        debugPrint('TransactionController categories stream error: $e');
        _scheduleCatRetry();
      },
    );
  }

  void _scheduleCatRetry() {
    _catRetryTimer?.cancel();
    if (_catRetryCount >= _catMaxRetries) return;
    _catRetryCount++;
    _catRetryTimer = Timer(Duration(seconds: kIsWeb ? 5 : 3), bindCategories);
  }

  void fetchSortedCategories() {
    // Optimization: Calculate in-memory from existing streams
    if (categories.isEmpty) {
      sortedCategoryNames.clear();
      return;
    }

    final categoryUsage = <String, int>{};

    // 1. Count usage from cached transactions
    for (var tx in transactions) {
      if (tx.category != null && tx.category!.isNotEmpty) {
        categoryUsage[tx.category!] = (categoryUsage[tx.category!] ?? 0) + 1;
      }
    }

    // 2. Sort available categories by usage
    // Create a list of all known category names
    final allNames = categories.map((c) => c.name).toList();

    // Sort: High usage first, then alphabetical for ties/unused
    allNames.sort((a, b) {
      final usageA = categoryUsage[a] ?? 0;
      final usageB = categoryUsage[b] ?? 0;
      if (usageA != usageB) {
        return usageB.compareTo(usageA); // Descending usage
      }
      return a.compareTo(b); // Alphabetical tie-breaker
    });

    sortedCategoryNames.assignAll(allNames);
  }

  // ——————————————————————————————————————
  //  Actions
  // ——————————————————————————————————————

  bool _addingCategory = false;

  Future<bool> addCategory(String name) async {
    // Guard against double-taps creating duplicate categories.
    if (_addingCategory) return false;
    _addingCategory = true;
    try {
      // 1. Check PRO Limit (Categories)
      if (!_subscriptionController.isPro && categories.length >= 10) {
        Get.to(() => const SubscriptionScreen());
        return false;
      }

      if (name.isEmpty) {
        ErrorHandler.showError("Category name cannot be empty");
        return false;
      }

      if (categories.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
        ErrorHandler.showError("Category already exists");
        return false;
      }

      final doc = await _repository.addCategory(name);
      categories.add(CategoryModel(id: doc.id, name: name));
      sortedCategoryNames.add(name); // Ensure it appears in QuickSend
      return true;
    } catch (e) {
      _handleFirestoreError(e, "Failed to add category");
      return false;
    } finally {
      _addingCategory = false;
    }
  }

  int getCategoryUsageCount(String categoryName) {
    return transactions.where((t) => t.category == categoryName).length;
  }

  Future<void> migrateTransactions(
    String oldCategory,
    String newCategory,
  ) async {
    try {
      final refs = transactions
          .where((tx) => tx.category == oldCategory)
          .map((tx) => _repository.transactionRef(tx.id))
          .toList();
      // Firestore batches are capped at 500 writes — chunk large migrations.
      const chunkSize = 499;
      for (var i = 0; i < refs.length; i += chunkSize) {
        final chunk = refs.skip(i).take(chunkSize);
        final batch = FirebaseFirestore.instance.batch();
        for (final ref in chunk) {
          batch.update(ref, {'category': newCategory});
        }
        await batch.commit();
      }
    } catch (e) {
      _handleFirestoreError(e, "Failed to migrate transactions");
    }
  }

  Future<bool> deleteCategory(CategoryModel category) async {
    if (categories.length <= 1) {
      ErrorHandler.showError("At least one category must exist.");
      return false;
    }

    try {
      await _repository.deleteCategory(category.id);
      categories.removeWhere((c) => c.id == category.id);
      return true;
    } catch (e) {
      _handleFirestoreError(e, "Failed to delete category");
      return false;
    }
  }

  /// Sets the user's own monthly bill amount for [categoryName], or clears it
  /// (back to the auto average) when [amount] is null/zero.
  ///
  /// The override is stored on the category doc that is already in memory, so
  /// editing a bill costs one write and no extra read. A bill can exist for a
  /// category with no doc yet (a recurring payment the user just added), in
  /// which case the doc is created first.
  Future<bool> setCategoryBillAmount(
    String categoryName,
    double? amount,
  ) async {
    final name = categoryName.trim();
    if (name.isEmpty) return false;
    final value = (amount == null || !amount.isFinite || amount <= 0)
        ? null
        : double.parse(amount.toStringAsFixed(2));

    try {
      CategoryModel? existing;
      for (final category in categories) {
        if (category.name.toLowerCase().trim() == name.toLowerCase()) {
          existing = category;
          break;
        }
      }

      if (existing == null) {
        final doc = await _repository.addCategory(name);
        await _repository.updateCategory(doc.id, {'fixedAmount': value});
        categories.add(
          CategoryModel(id: doc.id, name: name, fixedAmount: value),
        );
        sortedCategoryNames.add(name);
      } else {
        await _repository.updateCategory(existing.id, {'fixedAmount': value});
        final index = categories.indexOf(existing);
        categories[index] = CategoryModel(
          id: existing.id,
          name: existing.name,
          icon: existing.icon,
          iconCode: existing.iconCode,
          color: existing.color,
          treatmentOverride: existing.treatmentOverride,
          fixedAmount: value,
        );
      }
      return true;
    } catch (e) {
      _handleFirestoreError(e, "Failed to update the bill amount");
      return false;
    }
  }

  Future<bool> saveTransaction({
    required double amount,
    required String name,
    required String note,
    required String category,
    required DateTime date,
    required String type, // 'send' or 'receive'
    required String currency,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;

    // 2. Check PRO Limit (Transactions) — quick local check first
    if (!_subscriptionController.isPro) {
      final now = DateTime.now();
      final startOfMonth = DateTime(
        now.year,
        now.month,
        1,
      ).subtract(const Duration(microseconds: 1));
      final txCount = transactions
          .where((t) => t.date.isAfter(startOfMonth))
          .length;

      if (txCount >= 150) {
        Get.to(() => const SubscriptionScreen());
        isSaving.value = false;
        return false;
      }
    }

    final user = _auth.currentUser;
    if (user == null) {
      isSaving.value = false;
      return false;
    }

    if (!isValidAmount(amount)) {
      ErrorHandler.showError("Enter a valid amount");
      isSaving.value = false;
      return false;
    }
    if (name.isEmpty) {
      ErrorHandler.showError("Enter a valid name");
      isSaving.value = false;
      return false;
    }

    final isSend = type == 'send';
    final finalAmount = isSend ? -amount : amount;

    final tx = TransactionModel(
      id: "",
      senderId: isSend ? user.uid : "",
      recipientId: isSend ? "" : user.uid,
      recipientName: name,
      amount: finalAmount,
      currency: currency,
      tax: 0.0,
      note: note,
      category: category,
      date: date,
      status: "success",
      createdAt: DateTime.now(),
    );

    try {
      // 1. Attempt Firestore write with timeout
      await _repository.addTransaction(tx).timeout(const Duration(seconds: 5));
      AppAnalytics.log(AnalyticsEvent.transactionAdded, {
        'type': type,
        'has_category': category.isNotEmpty,
        'has_note': note.isNotEmpty,
        'has_attachment': (tx.attachmentUrl ?? '').isNotEmpty,
      });
    } on TimeoutException catch (e) {
      debugPrint("Firebase timeout: $e");
      // A write that timed out is the classic silently-lost transaction; record
      // it as non-fatal so release builds surface the rate.
      AppAnalytics.recordError(e, StackTrace.current, reason: 'addTransaction.timeout');
      // 2. Offline Queue Fallback — wrap separately so isSaving is always reset
      try {
        await OfflineQueueService.savePending(tx.toMap());
        ErrorHandler.showSuccess(
          "Saved locally. Will sync later.",
          title: "Offline",
        );
        isSaving.value = false;
        return true;
      } catch (queueError) {
        debugPrint("Offline queue error: $queueError");
        AppAnalytics.recordError(queueError, StackTrace.current,
            reason: 'addTransaction.offlineQueue');
        ErrorHandler.showError("Failed to save transaction. Please retry.");
        isSaving.value = false;
        return false;
      }
    } catch (e) {
      _handleFirestoreError(e, "Failed to save transaction");
      isSaving.value = false;
      return false;
    }

    // 3. Invalidate cache so next cold load is fresh
    LocalCacheService.invalidate(_cacheKey);

    // Remember this transaction was recorded so the background "haven't
    // added expenses" reminder stays quiet for the next few hours.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        lastTransactionAddedKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {} // ignore pref failures — best-effort only

    final email = user.email;
    if (email == null) {
      isSaving.value = false;
      return false;
    }

    // 4. Local Backup
    LocalBackupService.backupUserTransactions(email, reportErrors: false);

    // 5. Budget Check (Side Effect)
    if (isSend) {
      await BudgetService.checkBudgetExceeded(
        userId: email,
        category: category,
      );
    }

    // 6. Update cached sorted categories
    fetchSortedCategories();

    // 7. Update spending streak
    _updateStreak(email);

    isSaving.value = false;
    return true;
  }

  Future<void> _updateStreak(String email) async {
    try {
      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(email);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Run inside a transaction: the streak is a read-modify-write, and two
      // adds firing close together (_updateStreak is fire-and-forget) both used
      // to read the same `streakCount` and write the same increment, losing a
      // day (and double-firing or skipping the [7,30,100] milestone).
      final result = await db.runTransaction<({int count, bool milestone})>((
        txn,
      ) async {
        final doc = await txn.get(userRef);
        final data = doc.data() ?? {};
        final rawTs = data['lastStreakDate'];
        final lastTs = rawTs is Timestamp ? rawTs : null;
        final lastDate = lastTs != null
            ? DateTime(
                lastTs.toDate().year,
                lastTs.toDate().month,
                lastTs.toDate().day,
              )
            : null;
        // Firestore can hand back a numeric field as a double; a raw
        // `as int?` would throw and be swallowed by the catch below, killing
        // the streak silently.
        final count = safeToInt(data['streakCount']);

        if (lastDate == null ||
            lastDate.isBefore(today.subtract(const Duration(days: 1)))) {
          // Streak broken or new — reset to 1.
          txn.set(userRef, {
            'streakCount': 1,
            'lastStreakDate': Timestamp.fromDate(today),
          }, SetOptions(merge: true));
          return (count: 1, milestone: false);
        } else if (_isSameDay(
          lastDate,
          today.subtract(const Duration(days: 1)),
        )) {
          // Consecutive — increment.
          final newCount = count + 1;
          txn.set(userRef, {
            'streakCount': newCount,
            'lastStreakDate': Timestamp.fromDate(today),
          }, SetOptions(merge: true));
          return (
            count: newCount,
            milestone: const [7, 30, 100].contains(newCount),
          );
        }
        // lastDate == today: already tracked, no write.
        return (count: count, milestone: false);
      });

      streakCount.value = result.count;
      if (result.milestone) {
        ErrorHandler.showSuccess(
          '${result.count} day streak! Keep it up!',
          title: 'Streak Milestone',
        );
      }
    } catch (e) {
      debugPrint('Streak update error: $e');
    }
  }

  Future<bool> deleteTransaction(TransactionModel tx) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _repository
          .deleteTransaction(tx.id)
          .timeout(const Duration(seconds: 5));

      // Invalidate cache
      LocalCacheService.invalidate(_cacheKey);

      // Local Backup
      final email = user.email;
      if (email != null) {
        LocalBackupService.backupUserTransactions(email, reportErrors: false);
      }
      return true;
    } on TimeoutException {
      try {
        final deleteJson = {
          "_operation": "delete",
          "id": tx.id,
          "user": user.email,
        };
        await OfflineQueueService.savePending(deleteJson);
        transactions.removeWhere((t) => t.id == tx.id);
        ErrorHandler.showSuccess("Delete queued (Offline)", title: "Offline");
        return true;
      } catch (queueError) {
        debugPrint("Offline queue error: $queueError");
        ErrorHandler.showError("Failed to queue delete. Please retry.");
        return false;
      }
    } catch (e) {
      _handleFirestoreError(e, "Failed to delete transaction");
      return false;
    }
  }

  void _handleFirestoreError(dynamic e, String defaultMessage) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          ErrorHandler.showError(
            "You don't have permission to perform this action.",
          );
          break;
        case 'unavailable':
          ErrorHandler.showNetworkError();
          break;
        case 'not-found':
          ErrorHandler.showError("The requested item was not found.");
          break;
        default:
          ErrorHandler.showError("$defaultMessage: ${e.message}");
      }
    } else {
      ErrorHandler.showError("$defaultMessage. Please try again.");
      debugPrint("Error: $e");
    }
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
