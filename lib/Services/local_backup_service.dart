// lib/Services/local_backup_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

class LocalBackupService {
  LocalBackupService._();

  static const String _prefsPrefix = 'backup_';

  // ============================
  // BACKUP SCHEDULING
  //
  // A backup is a full server-side read of the whole `transactions`
  // collection, and the write paths call it after every add/edit/delete. Left
  // unthrottled that is one full read per write — O(n^2) reads per session and
  // a large download on the UI isolate during app start. So: one in-flight run
  // per account, a minimum gap between successful runs, and a dirty flag so a
  // write that lands inside either window is still flushed by a trailing run.
  // ============================

  /// Minimum gap between two successful automatic backups of one account.
  /// Mutable only so tests can shorten it.
  static Duration minInterval = const Duration(seconds: 30);

  static final Map<String, Future<void>> _inFlight = {};
  static final Map<String, bool> _dirty = {};
  static final Map<String, DateTime> _lastSuccess = {};
  static final Map<String, Timer> _trailing = {};

  /// Replaces the Firestore read so the scheduling policy is testable without
  /// a live backend (same pattern as `FeatureFlagService.adminOverride`).
  @visibleForTesting
  static Future<List<Map<String, dynamic>>> Function(String email)? fetchOverride;

  /// Replaces the on-disk write for the same reason.
  @visibleForTesting
  static Future<void> Function(String key, String data)? writeOverride;

  /// Replaces the on-disk *read*, so a test can assert on what a backup run
  /// preserved. The key is the same one [writeOverride] receives:
  /// `backup_<safe-email>` for the live mirror and `backup prev_<safe-email>`
  /// for the preserved pre-deletion snapshot.
  @visibleForTesting
  static Future<String?> Function(String key)? readOverride;

  @visibleForTesting
  static void resetSchedulingForTest() {
    for (final t in _trailing.values) {
      t.cancel();
    }
    _inFlight.clear();
    _dirty.clear();
    _lastSuccess.clear();
    _trailing.clear();
    fetchOverride = null;
    writeOverride = null;
    readOverride = null;
    minInterval = const Duration(seconds: 30);
  }

  // ============================
  // PUBLIC API
  // ============================

  static Future<int> restoreUserTransactions(String email) async {
    // Restore the *best* snapshot available, not just the current mirror: a
    // mass deletion empties the mirror but leaves the preserved
    // pre-deletion copy behind, and that copy is the one worth writing back.
    final transactions = await bestAvailableBackup(email);
    if (transactions.isEmpty) return 0;
    return _writeTransactions(email, transactions);
  }

  /// Writes [transactions] back into the user's transaction collection.
  ///
  /// Firestore batches are capped at 500 writes — chunk large restores so a
  /// big backup does not fail wholesale.
  static Future<int> _writeTransactions(
    String email,
    List<Map<String, dynamic>> transactions,
  ) async {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('transactions');

    var restored = 0;
    const chunkSize = 499;
    for (var i = 0; i < transactions.length; i += chunkSize) {
      final chunk = transactions.skip(i).take(chunkSize);
      final batch = FirebaseFirestore.instance.batch();
      for (var data in chunk) {
        if (data.containsKey('id')) {
          final docRef = col.doc(data['id']);
          final Map<String, dynamic> writeData = Map.from(data)..remove('id');
          _restoreDates(writeData);
          batch.set(docRef, writeData, SetOptions(merge: true));
          restored++;
        }
      }
      await batch.commit();
    }
    return restored;
  }

  /// Mirrors every call into [email]'s on-device backup.
  ///
  /// [reportErrors] is `true` only for the explicit Settings action, where a
  /// failure is the user's problem and worth a SnackBar. Automatic callers pass
  /// `false`: the write they follow already succeeded, so a red "Backup failed"
  /// banner (which also clears the confirmation SnackBar via
  /// `ErrorHandler._show`) reads as "my transaction did not save".
  ///
  /// [force] skips the throttle window. The explicit Settings action must not
  /// report success for a read that never happened, and it can cancel a pending
  /// trailing run because this read supersedes it.
  static Future<void> backupUserTransactions(
    String userEmail, {
    bool reportErrors = true,
    bool force = false,
  }) {
    if (userEmail.isEmpty) return Future<void>.value();
    final key = _sanitizeEmail(userEmail);

    // Every caller means "there may be something new to save".
    _dirty[key] = true;

    final active = _inFlight[key];
    if (active != null) return active;

    if (force) {
      _trailing.remove(key)?.cancel();
    } else {
      final elapsed = _sinceLastSuccess(key);
      if (elapsed != null && elapsed < minInterval) {
        // Inside the throttle window: don't read now, flush once it closes.
        _scheduleTrailing(key, userEmail, reportErrors, minInterval - elapsed);
        return Future<void>.value();
      }
    }

    final run = _drain(userEmail, reportErrors: reportErrors, force: force);
    _inFlight[key] = run;
    unawaited(run.whenComplete(() => _inFlight.remove(key)));
    return run;
  }

  /// Runs backups until nothing is dirty. Re-checks [_dirty] after every read
  /// so a write that landed mid-read is never silently dropped.
  static Future<void> _drain(
    String userEmail, {
    required bool reportErrors,
    bool force = false,
  }) async {
    final key = _sanitizeEmail(userEmail);
    // A forced call reads straight away, but only its first read bypasses the
    // window — the trailing passes stay throttled so it cannot spin.
    var bypassThrottle = force;
    while (_dirty[key] == true) {
      if (!bypassThrottle) {
        final elapsed = _sinceLastSuccess(key);
        if (elapsed != null && elapsed < minInterval) {
          _scheduleTrailing(
            key,
            userEmail,
            reportErrors,
            minInterval - elapsed,
          );
          return;
        }
      }
      bypassThrottle = false;
      _dirty[key] = false;
      final ok = await _attemptBackup(userEmail, reportErrors: reportErrors);
      if (ok) _lastSuccess[key] = DateTime.now();
      // A failed read already burned its retries; stop rather than spin.
      if (!ok) return;
    }
  }

  static void _scheduleTrailing(
    String key,
    String userEmail,
    bool reportErrors,
    Duration delay,
  ) {
    if (_trailing.containsKey(key)) return;
    if (delay <= Duration.zero) delay = const Duration(milliseconds: 1);
    _trailing[key] = Timer(delay, () {
      _trailing.remove(key);
      unawaited(backupUserTransactions(userEmail, reportErrors: reportErrors));
    });
  }

  static Duration? _sinceLastSuccess(String key) {
    final last = _lastSuccess[key];
    if (last == null) return null;
    return DateTime.now().difference(last);
  }

  /// One read + encode + atomic write, with the historical 3-attempt backoff.
  /// Returns whether the backup is now on disk.
  static Future<bool> _attemptBackup(
    String userEmail, {
    required bool reportErrors,
  }) async {
    const maxRetries = 3;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final list = await _fetchAll(userEmail);
        await _preserveIfShrunk(userEmail, list.length);
        await _writeData(_prefsKey(userEmail), jsonEncode(list));
        debugPrint(
          '[LocalBackupService] Backup success: ${list.length} items for $userEmail',
        );
        return true;
      } catch (e) {
        debugPrint('[LocalBackupService] Backup attempt ${attempt + 1} failed: $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
    }
    debugPrint('[LocalBackupService] All backup attempts failed for $userEmail');
    if (reportErrors) {
      ErrorHandler.showError('Backup failed. Data is safe in the cloud.', title: 'Backup');
    }
    return false;
  }

  // ============================
  // PRE-DELETION PRESERVATION
  //
  // The automatic backup runs after every write and *overwrites* the only copy
  // it keeps. That is harmless while the data only grows — but it is exactly
  // wrong after a mass deletion: the very next write replaces the pre-deletion
  // history with the emptied one, and the recovery path is gone. On
  // 2026-10-21 that is the sequence that destroyed 791 transactions: the
  // account was wiped, the next write fired the automatic backup, and the
  // only local copy was overwritten with the empty collection.
  //
  // So a shrinking backup preserves the previous snapshot in a second slot
  // instead of destroying it. The preserved copy is only replaced by a
  // *larger* one, so the most complete history always survives.
  // ============================

  /// Keeps the previous snapshot when a new backup would hold fewer documents.
  ///
  /// Best-effort: a failure here must never fail the backup itself, so every
  /// error is swallowed after being logged.
  static Future<void> _preserveIfShrunk(String email, int newCount) async {
    try {
      final currentRaw = await _readData(_prefsKey(email));
      if (currentRaw == null) return;

      final currentCount = _countDocuments(currentRaw);
      // Not a shrink — the new snapshot is at least as complete, so there is
      // nothing to preserve.
      if (currentCount <= newCount) return;

      final preservedRaw = await _readPreservedData(email);
      final preservedCount =
          preservedRaw == null ? 0 : _countDocuments(preservedRaw);
      // A better-preserved snapshot already exists; keep it.
      if (preservedCount >= currentCount) return;

      await _writePreservedData(email, currentRaw);
      debugPrint(
        '[LocalBackupService] Preserved pre-deletion backup '
        '($currentCount items, now $newCount) for $email',
      );
    } catch (e) {
      debugPrint('[LocalBackupService] preserve-on-shrink failed: $e');
    }
  }

  /// Number of documents in a stored snapshot payload; 0 when unreadable.
  static int _countDocuments(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.length : 0;
    } catch (_) {
      return 0;
    }
  }

  /// The authoritative read: raw documents straight from the server.
  ///
  /// Deliberately not derived from `TransactionController.transactions` and not
  /// given the listener's `orderBy('createdAt')` — docs missing that field
  /// (SMS imports, older rows) would drop out of an ordered query, and this is
  /// the recovery path. Cost is bounded by [minInterval] instead.
  static Future<List<Map<String, dynamic>>> _fetchAll(String userEmail) async {
    final override = fetchOverride;
    if (override != null) return override(userEmail);

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(userEmail)
        .collection('transactions');
    final snap = await col.get(const GetOptions(source: Source.server));
    return snap.docs
        .map((d) => {'id': d.id, ..._convertFirestoreTypes(d.data())})
        .toList();
  }

  static Future<List<Map<String, dynamic>>> readUserTransactionsBackup(
    String email,
  ) async {
    try {
      final raw = await _readData(_prefsKey(email));
      if (raw == null) return [];
      final data = jsonDecode(raw);
      if (data is! List) return [];
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("[LocalBackupService] read error: $e");
      ErrorHandler.showError('Could not read local backup. Please try again.', title: 'Restore');
      return [];
    }
  }

  /// Whether a non-empty backup exists for this email on this device. Lets the
  /// UI tell "no backup yet" apart from a successful-but-empty restore.
  ///
  /// Checks the preserved pre-deletion snapshot too: after a mass deletion the
  /// current mirror is empty but the preserved copy still holds the history,
  /// and reporting "no backup found" there would send the user away from the
  /// one thing that can bring their data back.
  static Future<bool> hasUserBackup(String email) async {
    final transactions = await bestAvailableBackup(email);
    return transactions.isNotEmpty;
  }

  /// The preserved (pre-deletion) snapshot for this email, if any.
  static Future<List<Map<String, dynamic>>> readPreservedBackup(
    String email,
  ) async {
    try {
      final raw = await _readPreservedData(email);
      if (raw == null) return [];
      final data = jsonDecode(raw);
      if (data is! List) return [];
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("[LocalBackupService] preserved read error: $e");
      return [];
    }
  }

  /// Whether a preserved pre-deletion snapshot is available.
  static Future<bool> hasPreservedBackup(String email) async {
    final list = await readPreservedBackup(email);
    return list.isNotEmpty;
  }

  /// The most complete on-device snapshot: the current mirror, unless the
  /// preserved pre-deletion copy holds more documents.
  ///
  /// This is what the restore path uses. After a mass deletion the mirror is
  /// empty and the preserved copy holds the pre-deletion history, so a plain
  /// "restore the mirror" would report "0 transactions restored" while the
  /// data was sitting right there.
  static Future<List<Map<String, dynamic>>> bestAvailableBackup(
    String email,
  ) async {
    final current = await readUserTransactionsBackup(email);
    final preserved = await readPreservedBackup(email);
    return preserved.length > current.length ? preserved : current;
  }

  /// Restores the preserved pre-deletion snapshot (not the current mirror).
  static Future<int> restorePreservedTransactions(String email) async {
    final transactions = await readPreservedBackup(email);
    if (transactions.isEmpty) return 0;
    return _writeTransactions(email, transactions);
  }

  static Future<void> clearUserBackup(String userEmail) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey(userEmail));
      await prefs.remove(_preservedPrefsKey(userEmail));
      return;
    }
    final file = await _transactionsFile(userEmail);
    if (await file.exists()) await file.delete();
    final preserved = await _preservedFile(userEmail);
    if (await preserved.exists()) await preserved.delete();
  }

  // ============================
  // HELPERS
  // ============================

  static String _prefsKey(String email) => '$_prefsPrefix${_sanitizeEmail(email)}';

  /// Key of the preserved pre-deletion snapshot. Deliberately a *different*
  /// key from [_prefsKey] so it maps to a different preference on web and a
  /// different file on disk.
  ///
  /// The space in the marker is load-bearing: a sanitized email contains only
  /// `[A-Za-z0-9_]`, so a key holding a space can never collide with the key
  /// of a real account whose name happens to start with "preserved". Without
  /// it, an account called `preserved_a@b.com` would share a key with the
  /// preserved snapshot of `a@b.com` and the two would overwrite each other.
  static String _preservedPrefsKey(String email) =>
      '$_prefsPrefix preserved ${_sanitizeEmail(email)}';

  /// The preserved snapshot's file. Kept separate from [_transactionsFile] so
  /// the two snapshots can never overwrite each other.
  static Future<File> _preservedFile(String email) async {
    final dir = await _backupDir();
    return File('${dir.path}/txprev_${_sanitizeEmail(email)}.json');
  }

  /// The storage key of the live mirror. Exposed so a test can assert on the
  /// two slots without hardcoding the key format.
  @visibleForTesting
  static String debugCurrentKey(String email) => _prefsKey(email);

  /// The storage key of the preserved pre-deletion snapshot.
  @visibleForTesting
  static String debugPreservedKey(String email) => _preservedPrefsKey(email);

  /// Reads the preserved snapshot.
  ///
  /// It does not go through [_readData]: that helper reconstructs the email
  /// from the key, and the "prev" marker would end up baked into the file
  /// name — so the preserved file would be written as `txprev_prev_…` while
  /// [clearUserBackup] deleted `txprev_…`, and the copy would survive
  /// deletion.
  static Future<String?> _readPreservedData(String email) async {
    final override = readOverride;
    if (override != null) return override(_preservedPrefsKey(email));
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_preservedPrefsKey(email));
    }
    final file = await _preservedFile(email);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  /// Writes the preserved snapshot. Routed through the same test seam as
  /// [_writeData] so a test can observe both slots.
  static Future<void> _writePreservedData(
    String email,
    String data,
  ) async {
    final override = writeOverride;
    if (override != null) return override(_preservedPrefsKey(email), data);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preservedPrefsKey(email), data);
      return;
    }
    final file = await _preservedFile(email);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(data);
    await tmp.rename(file.path);
  }

  static Future<String?> _readData(String key) async {
    final override = readOverride;
    if (override != null) return override(key);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    final file = await _transactionsFile(_extractEmail(key));
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  static Future<void> _writeData(String key, String data) async {
    final override = writeOverride;
    if (override != null) return override(key, data);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, data);
      return;
    }
    final file = await _transactionsFile(_extractEmail(key));
    // Write-then-rename: a kill (or a concurrent run) mid-write can no longer
    // leave a half-written backup behind for the restore path to read.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(data);
    await tmp.rename(file.path);
  }

  static String _extractEmail(String key) => key.replaceFirst(_prefsPrefix, '').replaceAll('_', '.');

  /// Converts all Firestore-specific types into JSON-safe values
  static Map<String, dynamic> _convertFirestoreTypes(
    Map<String, dynamic> data,
  ) {
    final result = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is Map) {
        result[key] = _convertFirestoreTypes(
          Map<String, dynamic>.from(value),
        );
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Map) return _convertFirestoreTypes(Map<String, dynamic>.from(item));
          if (item is Timestamp) return item.toDate().toIso8601String();
          if (item is DateTime) return item.toIso8601String();
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    });

    return result;
  }

  /// Field names that hold a real date, so an ISO string in them must come back
  /// as a Timestamp. Grounded in the `lib/Models` field names: a blanket
  /// "any ISO-looking string" rule silently rewrote free text, so a note like
  /// "2026-01-15T10:00 was the party" was replaced by a Timestamp on restore.
  static const Set<String> _dateFieldNames = {
    'date',
    'datelent',
    'duedate',
    'enddate',
    'startdate',
    'nextduedate',
    'laststreakdate',
    'lastpaymentdate',
    'maturitydate',
    'targetdate',
    'expirydate',
    'expiresat',
    'expiredat',
    'cancelledat',
    'trialenddate',
    'createdat',
    'updatedat',
    'lastupdated',
    'timestamp',
  };

  /// Free-text fields win over the suffix rules, so a field ever named
  /// `...Date` that actually stores prose still restores as prose.
  static const Set<String> _freeTextFields = {
    'note',
    'notes',
    'title',
    'description',
    'name',
    'merchant',
    'reason',
    'comment',
    'message',
    'body',
    'text',
    'label',
  };

  static bool _isDateField(String key) {
    final k = key.toLowerCase();
    if (_freeTextFields.contains(k)) return false;
    if (_dateFieldNames.contains(k)) return true;
    return k.endsWith('date') || k.endsWith('dates') || k.endsWith('timestamp');
  }

  /// Assigns a restored Timestamp, tolerating a container whose element type
  /// is pinned to [String]. Dart infers a string-literal map as
  /// `Map<String, String>`, which still passes an `is Map<String, dynamic>`
  /// test but throws on write.
  static void _assignRestored(Object target, Object key, Object value) {
    try {
      if (target is Map) {
        target[key] = value;
      } else if (target is List) {
        target[key as int] = value;
      }
    } catch (e) {
      debugPrint('Skipped date restore for "$key": $e');
    }
  }

  /// Converts ISO8601 strings back to Timestamp values, recursing into nested
  /// maps and lists.
  ///
  /// Every conversion is gated on the *owning* field name matching
  /// [_isDateField] — a blanket "any ISO-looking string" rule used to destroy
  /// free text such as a note reading "2026-01-15T10:00 was the party". List
  /// items have no key of their own, so they inherit the name of the field
  /// holding the list: a bare ISO string in a list is far more likely to be a
  /// note than a date, and a missed conversion only leaves a readable string.
  static void _restoreDates(Map<dynamic, dynamic> data) {
    data.forEach((key, value) {
      final name = key is String ? key : '$key';
      if (value is String) {
        if (_isDateField(name) && _looksLikeIsoDate(value)) {
          _assignRestored(data, key, Timestamp.fromDate(DateTime.parse(value)));
        }
      } else if (value is Map) {
        _restoreDates(value);
      } else if (value is List) {
        final dateList = _isDateField(name);
        // Converted on a copy and reassigned: a string-literal list is inferred
        // as List<String>, which cannot hold a Timestamp in place.
        final copy = List<dynamic>.of(value);
        for (var i = 0; i < copy.length; i++) {
          final item = copy[i];
          if (item is String) {
            if (dateList && _looksLikeIsoDate(item)) {
              copy[i] = Timestamp.fromDate(DateTime.parse(item));
            }
          } else if (item is Map) {
            _restoreDates(item);
          }
        }
        _assignRestored(data, key, copy);
      }
    });
  }

  /// Test seam for [_restoreDates].
  @visibleForTesting
  static void debugRestoreDates(Map<dynamic, dynamic> data) => _restoreDates(data);

  static bool _looksLikeIsoDate(String s) {
    return RegExp(r'\d{4}-\d{2}-\d{2}T').hasMatch(s);
  }

  /// Mobile-only — kept for exportBackupFile which returns a File
  static Future<Directory> _backupDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${baseDir.path}/money_control_backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> exportBackupFile(String email) async {
    if (kIsWeb) {
      // Return in-memory file via universal_io (works on web)
      return File('/tmp/backup_${_sanitizeEmail(email)}.json');
    }
    final file = await _transactionsFile(email);
    if (!await file.exists()) {
      await file.writeAsString("[]");
    }
    return file;
  }

  static String _sanitizeEmail(String email) {
    return email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }

  static Future<File> _transactionsFile(String email) async {
    final dir = await _backupDir();
    final safe = _sanitizeEmail(email);
    return File('${dir.path}/tx_$safe.json');
  }
}
