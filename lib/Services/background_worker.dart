import 'package:money_control/Platform/worker_platform.dart';
import 'package:money_control/Platform/notification_platform.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Platform/sms_platform.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:money_control/firebase_options.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:money_control/Services/recurring_service.dart';
import 'package:money_control/Models/recurring_payment_model.dart';
import 'package:money_control/Services/sms_service.dart';
import 'package:money_control/Services/widget_service.dart';
import 'package:money_control/Services/notification_service.dart';
import 'package:money_control/Platform/permission_platform.dart';

/// Background worker to check inactivity and show reminder notifications
class BackgroundWorker {
  static bool _initialized = false;

  /// Task name used by WorkManager
  /// Initialize WorkManager only once
  static Future<void> init() async {
    if (kIsWeb) return;
    if (_initialized) return;
    _initialized = true;

    // Initialize WorkManager with our callback dispatcher
    await Workmanager().initialize(callbackDispatcher);

    // Register periodic task (Android min is 15 minutes)
    await Workmanager().registerPeriodicTask(
      'periodic_checks_unique_v2', // Changed name to ensure fresh policy
      taskName,
      frequency: smsScanInterval,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  /// Manually trigger SMS auto-import (admin use). Scans the last [days] days.
  /// Returns the number of newly imported transactions.
  static Future<int> triggerSmsImport({int days = 7}) async {
    if (kIsWeb) return 0;
    final prefs = await SharedPreferences.getInstance();
    // Defense-in-depth: respect the kill-switch even for manual triggers.
    final flags = await _fetchFeatureFlags(prefs);
    if (_flagHidden(flags, 'sms_auto_import')) return 0;
    final scanFrom = DateTime.now().subtract(Duration(days: days));
    return _processSmsMessages(prefs, scanFrom: scanFrom);
  }

  /// Mirrors the live feature-flag status map (from the foreground
  /// `FeatureFlagService`) into SharedPreferences so the background isolate
  /// has an authoritative, fail-closed source when its own network read is
  /// unavailable or racing an auth restore. Safe to call on every change.
  static Future<void> mirrorFeatureFlags(Map<String, String> statusMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_mirrorFlagsKey, jsonEncode(statusMap));
    } catch (_) {}
  }

  /// Show notification helper
  static Future<void> showNotification(
    String title,
    String body,
    String channelId,
    String channelName, {
    String? userEmail,
  }) async {
    // Kill switch + user prefs: a `hidden` notifications flag (admin) or a
    // disabled master/per-channel toggle (user) suppresses the notification
    // entirely — no display and no Firestore history entry. This choke point
    // covers all six background channels at once.
    final prefs = await SharedPreferences.getInstance();
    final flags = await _fetchFeatureFlags(prefs);
    if (_flagHidden(flags, 'notifications')) return;
    if (!(prefs.getBool(notificationsMasterEnabledKey) ?? true)) return;
    if (!(prefs.getBool(notificationChannelEnabledKey(channelId)) ?? true)) {
      return;
    }

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'WealthSync Notifications',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final id = Random.secure().nextInt(2147483647);

    await plugin.show(id, title, body, details, payload: "home");

    // Persist to Firestore
    if (userEmail != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userEmail)
            .collection('notifications')
            .add({
              'title': title,
              'body': body,
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'type': channelId,
            });
      } catch (e) {
        developer.log("Error saving background notification: $e");
      }
    }
  }
}

/// Task name used by WorkManager
const String taskName = "periodic_task";

/// Preference key for the "Expense Reminder" toggle (Settings → General → Automation).
const String transactionReminderEnabledKey = 'transaction_reminder_enabled';

/// Preference key tracking when a transaction was last recorded (SMS import,
/// manual add, recurring payment). Suppresses the inactivity reminder.
const String lastTransactionAddedKey = 'last_transaction_added_ms';

/// Pure decision helper for the inactivity ("haven't added expenses") reminder.
///
/// Returns true only when all of these hold:
///  - the reminder is enabled,
///  - the app has been opened at least once,
///  - the app was last opened more than [inactivityWindow] ago,
///  - no transaction was recorded in the last [inactivityWindow],
///  - no reminder was sent in the last [inactivityWindow] (throttle).
bool shouldSendInactivityReminder({
  required int lastOpened,
  required int lastReminded,
  required int lastTransactionAdded,
  required int now,
  bool reminderEnabled = true,
  Duration inactivityWindow = const Duration(hours: 6),
}) {
  if (!reminderEnabled) return false;
  if (lastOpened == 0) return false;
  final windowMs = inactivityWindow.inMilliseconds;
  if (lastOpened >= now - windowMs) return false;
  if (lastTransactionAdded != 0 && now - lastTransactionAdded < windowMs) {
    return false;
  }
  if (now - lastReminded <= windowMs) return false;
  return true;
}

/// This function is called in the background isolate.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == taskName) {
      // 1. Initialize Firebase (Required for Firestore)
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // Firebase might already be initialized
        developer.log("Firebase init error (ignorable): $e");
      }

      final prefs = await SharedPreferences.getInstance();

      // Await a restored session before the flags read. On a cold start the
      // auth SDK rehydrates asynchronously; reading `app_config` before that
      // can hit a transient permission-denied (the rules require
      // `request.auth != null`), which used to make the kill-switch read fail
      // OPEN. `currentUser` is polled instead of listening to
      // `authStateChanges().first` because the first emission is often null on
      // a cold start.
      if (FirebaseAuth.instance.currentUser == null) {
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (FirebaseAuth.instance.currentUser != null) break;
        }
      }

      // Global kill switches: one small app_config read per tick, mirrored
      // into SharedPreferences so a network blip reuses the last known state.
      // `hidden` halts all background work for that feature — `comingSoon` is
      // a UI-level state and this isolate can't cheaply tell admins from
      // customers. The read is fail-closed: if the server read fails, the
      // foreground mirror (kept fresh by the authenticated realtime listener)
      // is preferred over defaulting back to enabled.
      final flags = await _fetchFeatureFlags(prefs);

      // --- LOGIC 1: SMS AUTO-IMPORT ---
      // Runs before the inactivity reminder so a run that just imported
      // transactions does not also nag the user in the same tick.
      if (!_flagHidden(flags, 'sms_auto_import') &&
          prefs.getBool(SmsService.autoImportEnabledKey) == true) {
        await _processSmsMessages(prefs);
      }

      // --- LOGIC 2: INACTIVITY REMINDER ---
      await _checkInactivity(prefs, flags);

      // --- LOGIC 3: DAILY INSIGHTS (10 PM) ---
      await _checkDailyInsights(prefs);

      // --- LOGIC 4: UPDATE CHECK ---
      await _checkUpdate(prefs, flags);

      // --- LOGIC 5: RECURRING PAYMENTS ---
      await _checkRecurringPayments(prefs, flags);

      // --- LOGIC 6: WEEKLY DIGEST ---
      await _checkWeeklyDigest(prefs);
    }

    return Future.value(true);
  });
}

// ---------------- CHECKERS ----------------

Future<void> _checkInactivity(
  SharedPreferences prefs,
  Map<String, String> featureFlags,
) async {
  if (_flagHidden(featureFlags, 'expense_reminder')) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  final shouldSend = shouldSendInactivityReminder(
    lastOpened: prefs.getInt('lastOpened') ?? 0,
    lastReminded: prefs.getInt('last_inactivity_reminded') ?? 0,
    lastTransactionAdded: prefs.getInt(lastTransactionAddedKey) ?? 0,
    now: now,
    reminderEnabled: prefs.getBool(transactionReminderEnabledKey) ?? true,
  );

  if (!shouldSend) return;

  final userEmail = prefs.getString('user_email');
  await BackgroundWorker.showNotification(
    "Money reminder 💸",
    "You haven’t added your expenses in a while — track them now!",
    'reminder_channel',
    'Reminders',
    userEmail: userEmail,
  );
  await prefs.setInt('last_inactivity_reminded', now);
}

Future<void> _checkDailyInsights(SharedPreferences prefs) async {
  final now = DateTime.now();

  // Trigger only after 10 PM (22:00)
  if (now.hour < 22) return;
  final todayStr = DateFormat('yyyy-MM-dd').format(now);
  final userEmail = prefs.getString('user_email');
  if (userEmail == null) return;

  // Per-user key: a shared device must not swallow another user's insight.
  final insightKey = 'last_daily_insight_run_$userEmail';
  final lastRun = prefs.getString(insightKey);
  if (lastRun == todayStr) return;

  try {
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userEmail)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    // Bail — no transactions today: don't nag with a "Spent 0" insight.
    if (snapshot.docs.isEmpty) {
      await prefs.setString(insightKey, todayStr);
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userEmail)
        .get();
    final uid = userDoc.exists ? (userDoc.data()?['uid'] as String?) : null;
    if (uid == null) return;

    double spent = 0;
    double received = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble().abs();
      if (data['senderId'] == uid) spent += amount;
      if (data['recipientId'] == uid) received += amount;
    }

    final symbol = prefs.getString('currency_symbol') ?? '\u20B9';
    final masked = prefs.getBool('privacy_mode_enabled') ?? false;
    final spentStr = masked ? '••••' : '$symbol${spent.toStringAsFixed(0)}';
    final receivedStr =
        masked ? '••••' : '$symbol${received.toStringAsFixed(0)}';

    await BackgroundWorker.showNotification(
      "Daily Insight 📊",
      "Today: Spent $spentStr, Received $receivedStr",
      'insight_channel',
      'Daily Insights',
      userEmail: userEmail,
    );

    // Mark as run for today
    await prefs.setString(insightKey, todayStr);
  } catch (e) {
    developer.log("Error fetching daily insight: $e");
  }
}

Future<void> _checkUpdate(
  SharedPreferences prefs,
  Map<String, String> flags,
) async {
  if (_flagHidden(flags, 'update_checker')) return;
  // Check once per day to avoid spam
  final now = DateTime.now();
  final todayStr = DateFormat('yyyy-MM-dd').format(now);
  final lastCheck = prefs.getString('last_update_check_run');

  if (lastCheck == todayStr) return; // Already checked today

  try {
    // 1. Fetch Remote Version
    final url = Uri.parse(
      "https://raw.githubusercontent.com/justaman045/WealthSync/master/app_version.json",
    );
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is! Map) return;
      final remoteVersion = data["latest_version"] as String? ?? "0.0.0";

      // 2. Fetch Local Version
      final package = await PackageInfo.fromPlatform();
      final localVersion = package.version;

      // 3. Compare
      if (_isNewer(remoteVersion, localVersion)) {
        // Try to get email if possible, though prefs might not be passed purely here
        // We need prefs to get email
        final userEmail = prefs.getString('user_email');

        await BackgroundWorker.showNotification(
          "Update Available 🚀",
          "Version $remoteVersion is out! Tap to update.",
          'update_channel',
          'Updates',
          userEmail: userEmail,
        );
      }

      // Mark checked
      await prefs.setString('last_update_check_run', todayStr);
    }
  } catch (e) {
    developer.log("Update check error: $e");
  }
}

bool _isNewer(String remote, String local) {
  int parseSeg(String s) => int.tryParse(s.split(RegExp(r'[+\-]')).first) ?? 0;
  List<int> r = remote.split('.').map(parseSeg).toList();
  List<int> l = local.split('.').map(parseSeg).toList();
  while (r.length < 3) {
    r.add(0);
  }
  while (l.length < 3) {
    l.add(0);
  }

  for (int i = 0; i < 3; i++) {
    if (r[i] > l[i]) return true;
    if (r[i] < l[i]) return false;
  }
  return false;
}

Future<void> _checkRecurringPayments(
  SharedPreferences prefs,
  Map<String, String> flags,
) async {
  if (_flagHidden(flags, 'recurring')) return;
  final now = DateTime.now();
  final todayStr = DateFormat('yyyy-MM-dd').format(now);

  final userEmail = prefs.getString('user_email');
  final uid = prefs.getString('user_uid');
  if (userEmail == null || uid == null) return;

  // Per-user guard so one account's run never suppresses another's.
  final lastRunKey = 'last_recurring_run_$userEmail';
  final lastRun = prefs.getString(lastRunKey);
  if (lastRun == todayStr) return; // Already checked today

  try {
    final pending = await RecurringService.processDuePayments(userEmail, uid);
    await _updateWidgetBalance(userEmail);

    // Persist the guard BEFORE the notification so a notification failure
    // does not re-fire the reminder on the next 15-minute WorkManager tick.
    await prefs.setString(lastRunKey, todayStr);

    if (pending.isNotEmpty) {
      await _showPendingReminder(prefs, userEmail, pending);
    }
  } catch (e) {
    developer.log("Error processing recurring payments: $e");
  }
}

Future<void> _showPendingReminder(
  SharedPreferences prefs,
  String userEmail,
  List<RecurringPayment> pending,
) async {
  final symbol = prefs.getString('currency_symbol') ?? '\u20B9';
  final count = pending.length;
  final masked = prefs.getBool('privacy_mode_enabled') ?? false;

  String listPreview;
  if (count == 1) {
    final p = pending.first;
    listPreview = masked ? p.title : '$symbol${p.amount.toStringAsFixed(0)} — ${p.title}';
  } else if (masked) {
    final names = pending.take(2).map((p) => p.title).join(', ');
    listPreview = '$names, +${count - 2} more';
  } else {
    final names = pending
        .take(2)
        .map((p) => '$symbol${p.amount.toStringAsFixed(0)} ${p.title}')
        .join(', ');
    listPreview = '$names, +${count - 2} more';
  }

  await BackgroundWorker.showNotification(
    count == 1 ? 'Bill Pending' : '$count Bills Pending',
    '$listPreview. Open app to mark them paid.',
    'recurring_pending_channel',
    'Recurring Payments',
    userEmail: userEmail,
  );
}

/// The SMS auto-import scan point. A watermark of 0 means "seed": start from
/// now, NOT epoch — auto-import must never backfill SMS received before the
/// feature was (re)enabled. An explicit [scanFrom] override (admin trigger)
/// bypasses both.
DateTime resolveSmsScanStart({required int lastScanMs, DateTime? now}) {
  if (lastScanMs <= 0) return now ?? DateTime.now();
  return DateTime.fromMillisecondsSinceEpoch(lastScanMs);
}

/// Cadence of the periodic SMS auto-import background task (Android minimum).
/// Single source of truth for the scheduler and the General-settings
/// "next auto-import" countdown estimate — they must never drift apart.
const Duration smsScanInterval = Duration(minutes: 15);

/// Estimate of when the next auto-import scan should land, projected from the
/// last scan watermark (which advances to `now` after every successful
/// background/foreground scan). Returns null when the watermark is 0 (never
/// scanned yet). An ESTIMATE: the OS may defer the actual WorkManager fire
/// time (Doze), so the settings UI labels it with "≈".
DateTime? nextSmsAutoImportEstimate({required int lastScanMs}) {
  if (lastScanMs <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    lastScanMs + smsScanInterval.inMilliseconds,
  );
}

Future<int> _processSmsMessages(
  SharedPreferences prefs, {
  DateTime? scanFrom,
}) async {
  final userEmail = prefs.getString('user_email');
  if (userEmail == null) return 0;

  // Defense-in-depth: verify the feature isn't hidden, even if the caller
  // already checked. Prevents auto-import if a new caller forgets to gate.
  final flags = await _fetchFeatureFlags(prefs);
  if (_flagHidden(flags, 'sms_auto_import')) return 0;

  final smsStatus = await Permission.sms.status;
  if (!smsStatus.isGranted) return 0;

  // Per-user watermark so one account's scan point never skips another
  // user's older bank SMS on a shared device. Seeded to `now` whenever the
  // user enables Auto-Import SMS (SmsService.seedAutoImportWatermark), and a
  // MISSING watermark resolves to `now` too — never epoch — so an enable that
  // predates this fix can't silently backfill months of history.
  final lastScanKey = SmsService.autoImportWatermarkKey(userEmail);
  final lastScanMs = prefs.getInt(lastScanKey) ?? 0;
  final lastScanDate = scanFrom ?? resolveSmsScanStart(lastScanMs: lastScanMs);

  try {
    final query = SmsQuery();
    final messages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 200,
    );

    final newBankMessages = messages.where((msg) {
      final date = msg.date;
      if (date == null) return false;
      return date.isAfter(lastScanDate) && SmsService.isBankSms(msg.body ?? '');
    }).toList();

    if (newBankMessages.isEmpty) {
      await prefs.setInt(lastScanKey, DateTime.now().millisecondsSinceEpoch);
      return 0;
    }

    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    // Load rules, correction cache + history cache before parsing
    await SmsService().initRules(force: true);
    await SmsService.loadCorrectionCache();
    await SmsService.buildHistoryCache();

    int imported = 0;
    const uuid = Uuid();
    final batch = db.batch();
    final seenKeys = <String>{};

    for (final msg in newBankMessages) {
      final parsed = SmsService.parseMessage(
        msg.body ?? '',
        msg.sender ?? 'Unknown',
        msg.date ?? DateTime.now(),
        rules: SmsService.currentRules,
      );
      if (parsed == null) continue;

      // Deduplicate: sender + epoch-minute + amount to avoid double-saves on retry
      final dedupeKey =
          '${parsed.sender}_${(parsed.date.millisecondsSinceEpoch ~/ 60000)}_${parsed.amount}';

      // Intra-batch dedup: skip if same key already queued in this batch
      if (!seenKeys.add(dedupeKey)) continue;

      final existing = await db
          .collection('users')
          .doc(userEmail)
          .collection('transactions')
          .where('smsDedupeKey', isEqualTo: dedupeKey)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;

      final txId = uuid.v4();
      final txRef = db
          .collection('users')
          .doc(userEmail)
          .collection('transactions')
          .doc(txId);
      batch.set(txRef, {
        'id': txId,
        'amount': parsed.isDebit ? -parsed.amount : parsed.amount,
        'recipientName': parsed.isDebit
            ? parsed.merchant
            : (parsed.merchant != 'Unknown' && parsed.merchant.isNotEmpty
                  ? parsed.merchant
                  : (parsed.sender.isNotEmpty ? parsed.sender : 'Bank Credit')),
        'recipientId': parsed.isDebit ? 'External' : uid,
        'senderId': parsed.isDebit ? uid : 'External',
        'date': Timestamp.fromDate(parsed.date),
        'createdAt': FieldValue.serverTimestamp(),
        'category': parsed.category,
        'status': 'success',
        'type': parsed.isDebit ? 'debit' : 'credit',
        'note': 'Auto-imported from SMS',
        'smsDedupeKey': dedupeKey,
        'smsSender': parsed.sender,
      });

      imported++;
    }

    if (imported > 0) {
      await batch.commit();
      await _updateWidgetBalance(userEmail);
      // Remember that transactions were recorded — this suppresses the
      // "haven't added expenses" inactivity reminder for the next 6 hours.
      await prefs.setInt(
        lastTransactionAddedKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }

    if (imported > 0) {
      await BackgroundWorker.showNotification(
        'SMS Auto-Import',
        '$imported new transaction${imported > 1 ? 's' : ''} detected and saved.',
        'sms_import_channel',
        'SMS Import',
        userEmail: userEmail,
      );
    }

    await prefs.setInt(lastScanKey, DateTime.now().millisecondsSinceEpoch);
    return imported;
  } catch (e) {
    developer.log('SMS auto-import error: $e');
    // Do NOT update the scan watermark on failure — let the next run retry.
    return 0;
  }
}

/// Reads the authoritative balance from the portfolio doc (written by the
/// foreground on every recompute) and pushes it to the home widget. Avoids a
/// full transactions scan. Falls back to a scan only for users who haven't
/// launched the app since the `balance` field was introduced.
Future<void> _updateWidgetBalance(String email) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    // Kill-switch: a `hidden` home_widget flag halts balance pushes here too
    // (the isolate has no GetX, so it uses the cached flag map like every
    // other background task).
    final flags = await _fetchFeatureFlags(prefs);
    if (_flagHidden(flags, 'home_widget')) return;
    final db = FirebaseFirestore.instance;
    double total;
    final portfolioSnap = await db
        .collection('users')
        .doc(email)
        .collection('wealth')
        .doc('portfolio')
        .get();
    final balance = portfolioSnap.data()?['balance'] as num?;
    if (balance != null) {
      total = balance.toDouble();
    } else {
      final snap = await db
          .collection('users')
          .doc(email)
          .collection('transactions')
          .get();
      total = 0;
      for (final doc in snap.docs) {
        total += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    final symbol = prefs.getString('currency_symbol') ?? '\u20B9';
    final masked = prefs.getBool('privacy_mode_enabled') ?? false;
    await WidgetService.updateBalance(total, symbol, masked: masked);
  } catch (e) {
    developer.log('Widget balance update error: $e');
  }
}

Future<void> _checkWeeklyDigest(SharedPreferences prefs) async {
  final now = DateTime.now();
  // Only fire on Sunday (weekday 7) between 9-10 AM
  if (now.weekday != DateTime.sunday || now.hour < 9 || now.hour >= 10) return;

  final thisWeekStr = 'week_${now.year}_${_isoWeekNumber(now)}';
  final userEmail = prefs.getString('user_email');
  if (userEmail == null) return;

  // Per-user key: a shared device must not swallow another user's digest.
  final digestKey = 'last_weekly_digest_$userEmail';
  final lastSent = prefs.getString(digestKey);
  if (lastSent == thisWeekStr) return; // Already sent this week

  try {
    final db = FirebaseFirestore.instance;
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final lastWeekStart = weekStartDay.subtract(const Duration(days: 7));

    final snap = await db
        .collection('users')
        .doc(userEmail)
        .collection('transactions')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(lastWeekStart),
        )
        .get();

    double thisWeekSpend = 0;
    double lastWeekSpend = 0;

    final uid =
        prefs.getString('user_uid') ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';

    for (final doc in snap.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp?)?.toDate();
      if (date == null) continue;
      if (date.isAfter(now)) continue; // Exclude future-dated transactions.
      final isSend = data['senderId'] == uid;
      if (!isSend) continue;
      final amount = (data['amount'] as num?)?.abs().toDouble() ?? 0;
      if (!date.isBefore(weekStartDay)) {
        thisWeekSpend += amount;
      } else {
        lastWeekSpend += amount;
      }
    }

    final symbol = prefs.getString('currency_symbol') ?? '\u20B9';
    final masked = prefs.getBool('privacy_mode_enabled') ?? false;
    String body;
    if (masked) {
      body = 'You have activity this week. Open the app for details.';
    } else if (lastWeekSpend > 0) {
      final pct = ((thisWeekSpend - lastWeekSpend) / lastWeekSpend * 100).abs();
      final dir = thisWeekSpend <= lastWeekSpend ? 'less' : 'more';
      body =
          'You spent $symbol${thisWeekSpend.toStringAsFixed(0)} this week — '
          '${pct.toStringAsFixed(0)}% $dir than last week.';
    } else {
      body = 'You spent $symbol${thisWeekSpend.toStringAsFixed(0)} this week.';
    }

    await BackgroundWorker.showNotification(
      'Weekly Money Digest',
      body,
      'weekly_digest_channel',
      'Weekly Digest',
      userEmail: userEmail,
    );

    await prefs.setString(digestKey, thisWeekStr);
  } catch (e) {
    developer.log('Weekly digest error: $e');
  }
}

int _isoWeekNumber(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final dayOfYear = int.parse(DateFormat('D').format(d));
  final dow = d.weekday;
  final woy = ((dayOfYear - dow + 10) / 7).floor();
  if (woy < 1) {
    // Week belongs to previous year
    final dec31 = DateTime.utc(date.year - 1, 12, 31);
    return _isoWeekNumber(dec31);
  }
  if (woy > 52 && dow <= 3) {
    return 1; // Week 1 of next year
  }
  return woy;
}

/// SharedPreferences key for the foreground-mirrored feature-flag map. The
/// foreground app (which has an authenticated realtime listener + a web poll)
/// writes the authoritative status map here on every change. The background
/// isolate prefers this mirror when its own server read fails, so a value the
/// admin explicitly hid can never silently default back to enabled.
const String _mirrorFlagsKey = 'bg_feature_flags';

/// SharedPreferences key for the cached feature-flag map (legacy). Persisted
/// after every successful Firestore read so a network blip never re-enables a
/// feature the admin explicitly hid.
const String _cachedFlagsKey = 'bg_cached_feature_flags';

/// Pure kill-switch resolution shared by [_fetchFeatureFlags] and unit tests.
///
/// The background isolate must never run a hidden feature just because its
/// network read failed. Precedence:
///   1. a live server read (authoritative),
///   2. the foreground mirror (known, survives restarts, fail-closed),
///   3. the legacy cached map,
///   4. `null`/empty everywhere -> `{}` (documented safe default: enabled).
Map<String, String> resolveBackgroundFlags({
  required Map<String, String>? server,
  required Map<String, String>? mirror,
  required Map<String, String>? legacyCache,
}) {
  if (server != null) return server;
  if (mirror != null && mirror.isNotEmpty) return mirror;
  if (legacyCache != null && legacyCache.isNotEmpty) return legacyCache;
  return const {};
}

/// Reads the `app_config/feature_flags` kill switches for the background
/// isolate. On success the result is cached in SharedPreferences; on failure
/// the foreground mirror (then the legacy cache) is returned instead of an
/// empty map so hidden features stay dead across network outages and auth
/// races.
Future<Map<String, String>> _fetchFeatureFlags(SharedPreferences prefs) async {
  final mirror = _loadMapFromPrefs(prefs, _mirrorFlagsKey);
  final legacyCache = _loadMapFromPrefs(prefs, _cachedFlagsKey);
  try {
    final snap = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('feature_flags')
        .get()
        .timeout(const Duration(seconds: 5));
    final data = snap.exists ? snap.data() : null;
    if (data == null) {
      developer.log("Feature flag doc missing; using background mirror");
      await _cacheFlags(prefs, mirror);
      return resolveBackgroundFlags(
        server: null,
        mirror: mirror,
        legacyCache: legacyCache,
      );
    }
    final out = <String, String>{};
    data.forEach((key, value) {
      final status = value?.toString() ?? '';
      if (status == 'enabled' || status == 'comingSoon' || status == 'hidden') {
        out[key] = status;
      }
    });
    await _cacheFlags(prefs, out);
    await BackgroundWorker.mirrorFeatureFlags(out);
    return out;
  } catch (e) {
    developer.log("Feature flag fetch failed (using mirror/cache): $e");
    return resolveBackgroundFlags(
      server: null,
      mirror: mirror,
      legacyCache: legacyCache,
    );
  }
}

Future<void> _cacheFlags(
  SharedPreferences prefs,
  Map<String, String> flags,
) async {
  try {
    await prefs.setString(_cachedFlagsKey, jsonEncode(flags));
    await prefs.setString(_mirrorFlagsKey, jsonEncode(flags));
  } catch (_) {}
}

Map<String, String> _loadMapFromPrefs(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key);
  if (raw == null) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    }
  } catch (_) {}
  return const {};
}

bool _flagHidden(Map<String, String> flags, String key) =>
    flags[key] == 'hidden';
