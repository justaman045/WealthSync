// lib/Services/full_backup_service.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:money_control/Models/backup_archive.dart';
import 'package:money_control/Services/app_analytics.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Services/user_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

/// Complete account backup: capture every collection, hand the user a file, and
/// rebuild the account from that file.
///
/// Why this exists, in one paragraph: on 2026-10-21 the integration harness
/// deleted 34 subcollections (791 transactions, 23 categories, 13 goals, all
/// budgets and wealth) from a live account. Nothing was recoverable — the only
/// "backup" in the app is `LocalBackupService`, which mirrors transactions to a
/// device-local file that *it overwrites on every launch*, and the GDPR export
/// is a read-only dump with no import path. Firestore PITR was unavailable
/// (paid tier). A user who can download a complete archive they physically hold
/// can always get back to where they were.
///
/// Scope: `UserService.subcollections` (41 collections — the same list the
/// account-deletion flow uses, so backup and delete can never drift), plus the
/// `users/{email}` profile document and the `wealth/portfolio` summary.
class FullBackupService {
  FullBackupService._();

  /// Firestore batches cap at 500 writes.
  static const int _batchSize = 400;

  /// Error codes that mean "the server refused this document", as opposed to
  /// "the request never got through".
  ///
  /// Only the first kind is worth retrying document by document. A batch that
  /// failed because the network dropped would fail the same way 400 times
  /// over, so the retry is reserved for a batch the rules actually rejected.
  static const Set<String> _documentRejectionCodes = {
    'permission-denied',
    'invalid-argument',
    'failed-precondition',
    'out-of-range',
  };

  /// Whether [error] means a document was refused, so the batch can be
  /// retried one document at a time.
  static bool _isDocumentRejection(Object error) {
    if (error is FirebaseException) {
      return _documentRejectionCodes.contains(error.code);
    }
    // Anything else (a test seam, an unexpected SDK error) is treated as a
    // rejection so the per-document path is still exercised rather than
    // silently dropping the chunk.
    return true;
  }

  /// `file_picker` refuses very large buffers on some platforms and the
  /// share/intent path is worse; warn rather than fail so the user still gets
  /// their data.
  static const int largeArchiveWarningBytes = 20 * 1024 * 1024;

  // ============================
  // TEST SEAMS
  // ============================

  /// Replaces the collection read so capture is testable without a backend.
  /// Signature: (email, collectionName) -> documents (each with [BackupArchive.idField]).
  @visibleForTesting
  static Future<List<Map<String, dynamic>>> Function(String, String)?
  fetchCollectionOverride;

  /// Replaces the profile read.
  @visibleForTesting
  static Future<Map<String, dynamic>?> Function(String)? fetchProfileOverride;

  /// Replaces the portfolio read.
  @visibleForTesting
  static Future<Map<String, dynamic>?> Function(String)? fetchPortfolioOverride;

  /// Replaces the write of one document. Signature: (path, data).
  @visibleForTesting
  static Future<void> Function(String, Map<String, dynamic>)? writeOverride;

  /// Replaces the *batch* write used for subcollection restores. Signature:
  /// (email, collection, docs), where each doc is
  /// `{'_docId': String, '_data': Map<String, dynamic>}`.
  ///
  /// The real path commits a Firestore batch, which is atomic. A test uses
  /// this seam to capture the calls, and to make the batch fail so the
  /// per-document fallback can be exercised.
  @visibleForTesting
  static Future<void> Function(
    String email,
    String collection,
    List<Map<String, dynamic>> docs,
  )? batchWriteOverride;

  /// Replaces the single-document write used by the per-document fallback
  /// that runs when a batch is rejected. Signature: (email, collection,
  /// docId, data).
  @visibleForTesting
  static Future<void> Function(
    String email,
    String collection,
    String docId,
    Map<String, dynamic> data,
  )? docWriteOverride;

  /// Replaces the signed-in account lookup, so a restore can be tested
  /// without a Firebase app. Null means "read it from FirebaseAuth".
  @visibleForTesting
  static String? signedInEmailOverride;

  /// Replaces the "list collections" source. Defaults to
  /// `UserService.subcollections`.
  @visibleForTesting
  static List<String>? collectionsOverride;

  /// Replaces cache invalidation after a restore. The real path needs an
  /// initialized `LocalCacheService` (SharedPreferences + package info), which
  /// a pure unit test has no reason to stand up.
  @visibleForTesting
  static Future<void> Function(String key)? cacheInvalidateOverride;

  /// Replaces the directory the automatic snapshot is stored in. The real
  /// path needs `path_provider`, which a pure unit test has no reason to
  /// stand up; a test points this at a temp directory instead.
  @visibleForTesting
  static Future<Directory> Function()? snapshotDirOverride;

  @visibleForTesting
  static void resetForTest() {
    fetchCollectionOverride = null;
    fetchProfileOverride = null;
    fetchPortfolioOverride = null;
    writeOverride = null;
    batchWriteOverride = null;
    docWriteOverride = null;
    signedInEmailOverride = null;
    collectionsOverride = null;
    cacheInvalidateOverride = null;
    snapshotDirOverride = null;
  }

  static List<String> get _collections =>
      collectionsOverride ?? UserService.subcollections;

  // ============================
  // CAPTURE
  // ============================

  /// Reads every collection for [email] and returns an in-memory archive.
  ///
  /// One failed collection read is recorded in the returned archive as an empty
  /// list *and* surfaced through [onCollectionError] rather than aborting the
  /// whole backup: a partial backup the user knows about beats no backup. The
  /// caller decides whether to warn.
  static Future<BackupArchive> capture(
    String email, {
    void Function(String collection, Object error)? onCollectionError,
    String appVersion = '',
  }) async {
    final collections = <String, List<Map<String, dynamic>>>{};

    for (final name in _collections) {
      try {
        collections[name] = await _fetchCollection(email, name);
      } catch (e, s) {
        debugPrint('[FullBackupService] collection "$name" failed: $e');
        AppAnalytics.recordError(
          e,
          s,
          reason: 'full_backup_collection_failed',
          context: {'collection': name},
        );
        collections[name] = const [];
        onCollectionError?.call(name, e);
      }
    }

    Map<String, dynamic>? profile;
    try {
      // Redacted here rather than inside the fetch, so the redaction also
      // covers the test seam and any future read path: no purchase
      // credential can reach the downloaded file.
      final fetched = await _fetchProfile(email);
      profile = fetched == null
          ? null
          : BackupArchive.redactProfileForArchive(fetched);
    } catch (e, s) {
      debugPrint('[FullBackupService] profile read failed: $e');
      AppAnalytics.recordError(e, s, reason: 'full_backup_profile_failed');
      onCollectionError?.call('profile', e);
    }

    Map<String, dynamic>? portfolio;
    try {
      portfolio = await _fetchPortfolio(email);
    } catch (e, s) {
      debugPrint('[FullBackupService] wealth portfolio read failed: $e');
      AppAnalytics.recordError(e, s, reason: 'full_backup_portfolio_failed');
      onCollectionError?.call('wealth_portfolio', e);
    }

    return BackupArchive(
      formatVersion: BackupArchive.currentFormatVersion,
      createdAt: DateTime.now().toUtc(),
      email: email,
      profile: profile,
      wealthPortfolio: portfolio,
      collections: collections,
      appVersion: appVersion,
    );
  }

  /// Suggested filename, timestamped so several downloads never collide and the
  /// user can tell them apart in their Downloads folder.
  static String suggestedFileName(DateTime createdAt) {
    final d = createdAt.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'WealthSync_backup_${d.year}${two(d.month)}${two(d.day)}_'
        '${two(d.hour)}${two(d.minute)}${two(d.second)}.json';
  }

  /// Writes [archive] to a user-chosen file via the platform picker.
  ///
  /// Returns the saved path, or null when the user cancelled. Passing `bytes:`
  /// (not a path) is required: on Android `FilePicker.saveFile()` hands back a
  /// `content://` URI that cannot be opened with `dart:io`.
  static Future<String?> download(
    BackupArchive archive, {
    String? fileName,
  }) async {
    final name = fileName ?? suggestedFileName(archive.createdAt);
    final bytes = Uint8List.fromList(utf8.encode(archive.toJson()));
    return FilePicker.platform.saveFile(
      fileName: name,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
  }

  /// Opens a file picker and parses the chosen file as an archive.
  ///
  /// Throws [BackupFormatException] when the file is not a readable backup, so
  /// the UI can show the reason instead of "restored 0 documents".
  static Future<BackupArchive?> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const BackupFormatException(
        'Could not read the selected file. Try downloading it again.',
      );
    }
    return BackupArchive.fromJson(utf8.decode(bytes));
  }

  // ============================
  // RESTORE
  // ============================

  /// Rebuilds the account from [archive].
  ///
  /// Documents are written with `merge: true` and their original ids, so the
  /// operation is idempotent: restoring the same archive twice does not
  /// duplicate, and restoring an *older* archive does not delete anything the
  /// user created after it. That asymmetry is deliberate — a restore must never
  /// be able to lose data that is currently present.
  ///
  /// Returns a per-collection count of documents written, so the UI can report
  /// exactly what came back.
  static Future<BackupRestoreResult> restore(BackupArchive archive) async {
    // The restore writes into the account that is signed in NOW, not the one
    // the archive was taken from.
    final signedInEmail = _currentUserEmail();
    final signedInUid = _currentUserUid();
    final email = signedInEmail.isNotEmpty ? signedInEmail : archive.email;
    final uid = signedInUid;
    if (email.isEmpty) {
      throw Exception('No signed-in account to restore into.');
    }
    final archivedEmail = archive.email;
    if (archivedEmail.isNotEmpty && archivedEmail != email) {
      debugPrint(
        '[FullBackupService] restoring a backup taken by $archivedEmail '
        'into $email - remapping identity fields',
      );
    }

    final written = <String, int>{};
    final failed = <String, Object>{};

    // Profile first: it carries the personal details that make a rebuilt
    // account usable.
    //
    // The entitlement and identity fields are stripped first. The rules
    // reject most of them on an owner write, which would fail the *whole*
    // write and cost the user their name and phone; and where the rules do
    // allow it, restoring them would let a stale backup strip a paying
    // user's Pro status. The live values survive because the write is a
    // merge.
    if (archive.profile != null && archive.profile!.isNotEmpty) {
      try {
        var data = BackupArchive.stripServerAuthoritativeFields(
          _revive(archive.profile!),
        );
        data = _remapIdentity(data, email, uid, archivedEmail, '');
        if (uid.isNotEmpty) data['uid'] = uid;
        if (email.isNotEmpty) data['email'] = email;
        await _writeDoc('users/$email', data);
        written['profile'] = 1;
      } catch (e, s) {
        debugPrint('[FullBackupService] profile restore failed: $e');
        AppAnalytics.recordError(e, s, reason: 'full_backup_restore_profile');
        failed['profile'] = e;
      }
    }

    if (archive.wealthPortfolio != null && archive.wealthPortfolio!.isNotEmpty) {
      try {
        var data = _revive(archive.wealthPortfolio!);
        data = _remapIdentity(data, email, uid, archivedEmail, '');
        await _writeDoc('users/$email/wealth/portfolio', data);
        written['wealth_portfolio'] = 1;
      } catch (e, s) {
        debugPrint('[FullBackupService] portfolio restore failed: $e');
        AppAnalytics.recordError(e, s, reason: 'full_backup_restore_portfolio');
        failed['wealth_portfolio'] = e;
      }
    }

    for (final entry in archive.collections.entries) {
      final collection = entry.key;
      final docs = entry.value;
      if (docs.isEmpty) continue;

      // Only restore collections this build actually knows about. An archive
      // written by a newer release may name a collection whose rules/ruleset
      // this binary cannot write; skipping keeps the restore from half-failing.
      if (!_collections.contains(collection)) {
        debugPrint(
          '[FullBackupService] skipping unknown collection "$collection" '
          '(${docs.length} docs)',
        );
        continue;
      }

      var committed = 0;
      final rejected = <String>[];
      try {
        final pending = <Map<String, dynamic>>[];
        for (final raw in docs) {
          final data = Map<String, dynamic>.from(raw);
          final id = data.remove(BackupArchive.idField)?.toString();
          final docId = (id == null || id.isEmpty)
              ? FirebaseFirestore.instance.collection('_').doc().id
              : id;
          try {
            var revived = _revive(data);
            revived = _remapIdentity(revived, email, uid, archivedEmail, '');
            pending.add({'_docId': docId, '_data': revived});
          } catch (e, s) {
            // One unreadable document must not cost the whole collection.
            rejected.add(docId);
            AppAnalytics.recordError(
              e,
              s,
              reason: 'full_backup_restore_doc_revive_failed',
              context: {'collection': collection, 'docId': docId},
            );
          }
        }

        for (var i = 0; i < pending.length; i += _batchSize) {
          final chunk = pending.skip(i).take(_batchSize).toList();
          try {
            await _commitChunk(email, collection, chunk);
            committed += chunk.length;
          } catch (e, s) {
            // A Firestore batch is atomic: ONE document the rules reject
            // fails every document in it. A recovery tool cannot afford
            // that — 399 good transactions must not be lost to one bad
            // one — so the chunk is retried one document at a time and
            // only the document the server actually rejects is lost.
            //
            // A transient failure (the network dropped) is NOT retried that
            // way: the same request would fail 400 times over, so the chunk
            // is reported as failed and the restore moves on.
            AppAnalytics.recordError(
              e,
              s,
              reason: 'full_backup_restore_batch_failed',
              context: {'collection': collection, 'chunkSize': chunk.length},
            );
            if (!_isDocumentRejection(e)) {
              failed[collection] = e;
              continue;
            }
            for (final item in chunk) {
              final docId = item['_docId'] as String;
              final data = item['_data'] as Map<String, dynamic>;
              try {
                await _writeCollectionDoc(email, collection, docId, data);
                committed++;
              } catch (docError) {
                rejected.add(docId);
                AppAnalytics.recordError(
                  docError,
                  s,
                  reason: 'full_backup_restore_doc_failed',
                  context: {'collection': collection, 'docId': docId},
                );
              }
            }
          }
        }
        // Only documents the server actually accepted are counted. Reporting
        // a batch that failed as "restored" is exactly the false success this
        // feature exists to prevent.
        written[collection] = committed;
        if (rejected.isNotEmpty) {
          failed[collection] =
              '${rejected.length} of ${docs.length} document(s) were rejected '
              'by the server';
        }
      } catch (e, s) {
        debugPrint('[FullBackupService] restore of "$collection" failed: $e');
        AppAnalytics.recordError(
          e,
          s,
          reason: 'full_backup_restore_collection',
          context: {
            'collection': collection,
            'restoredBeforeFailure': committed,
          },
        );
        failed[collection] = e;
        if (committed > 0) written[collection] = committed;
      }
    }

    // The restore rewrote Firestore; drop the cold-load caches so a reload
    // inside the TTL cannot surface the pre-restore state (mirrors the
    // transactions-only restore and import_screen).
    for (final key in _cacheKeysFor(email)) {
      final override = cacheInvalidateOverride;
      if (override != null) {
        await override(key);
        continue;
      }
      try {
        await LocalCacheService.invalidate(key);
      } catch (e) {
        // A cache that was never initialized (or a platform without prefs)
        // must not fail an otherwise-successful restore.
        debugPrint('[FullBackupService] cache invalidate "$key" skipped: $e');
      }
    }

    return BackupRestoreResult(written: written, failed: failed);
  }

  /// The signed-in account's email, or '' when there is none.
  ///
  /// Reading `FirebaseAuth.instance` needs an initialized Firebase app, so a
  /// pure unit test has no way to answer this. The seam keeps the lookup
  /// testable without the restore depending on a live session.
  static String _currentUserEmail() {
    final override = signedInEmailOverride;
    if (override != null) return override;
    try {
      return FirebaseAuth.instance.currentUser?.email ?? '';
    } catch (_) {
      // No Firebase app in this context. The caller falls back to the
      // archive's own address.
      return '';
    }
  }

  static String _currentUserUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  static Map<String, dynamic> _remapIdentity(Map<String, dynamic> data, String currentEmail, String currentUid, String archivedEmail, String archivedUid) {
    final out = Map<String, dynamic>.from(data);
    if (out.containsKey('uid')) {
      if (archivedUid.isNotEmpty && out['uid'] == archivedUid) {
        out['uid'] = currentUid;
      } else if (currentUid.isNotEmpty) {
        out['uid'] = currentUid;
      }
    }
    if (out.containsKey('email')) {
      if (archivedEmail.isNotEmpty && out['email'] == archivedEmail) {
        out['email'] = currentEmail;
      } else if (currentEmail.isNotEmpty) {
        out['email'] = currentEmail;
      }
    }
    if (out.containsKey('senderId')) {
      if (archivedUid.isNotEmpty && out['senderId'] == archivedUid) {
        out['senderId'] = currentUid.isNotEmpty ? currentUid : currentEmail;
      } else if (currentUid.isNotEmpty) {
        // Only remap if it looks like owner id
      }
    }
    if (out.containsKey('recipientId')) {
      if (archivedUid.isNotEmpty && out['recipientId'] == archivedUid) {
        out['recipientId'] = currentUid.isNotEmpty ? currentUid : currentEmail;
      }
    }
    return out;
  }

  /// Cache keys keyed by user email, matching the controllers' `_cacheKey`
  /// getters (`'<name>_<email>'`).
  static List<String> _cacheKeysFor(String email) => [
    'transactions_$email',
    'categories_$email',
    'budgets_$email',
    'goals_$email',
    'loans_$email',
    'lent_money_$email',
    'recurring_$email',
    'profile_$email',
    'challenges_$email',
  ];

  // ============================
  // LOCAL SNAPSHOT
  //
  // A user-downloaded archive is the real safety net, but it only exists if
  // the user remembers to take one. The local snapshot is the automatic
  // counterpart: a full copy of the whole account, refreshed on a daily
  // cadence and kept on the device. It is what makes "this cannot happen
  // again" true even for a user who never opens the backup screen.
  // ============================

  /// Where the automatic snapshot is kept on the device.
  static Future<File> _snapshotFile(String email) async {
    final dir = await _snapshotDir();
    return File('${dir.path}/full_${_safeName(email)}.json');
  }

  static String _safeName(String email) =>
      email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  static Future<Directory> _snapshotDir() async {
    final override = snapshotDirOverride;
    if (override != null) return override();
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Writes the automatic snapshot for [email], keeping the *larger* of the
  /// new and the stored snapshot.
  ///
  /// A snapshot that holds fewer documents than the one already on disk means
  /// something was deleted. Overwriting then would destroy the only complete
  /// copy — the same trap the local transaction mirror fell into — so the
  /// larger snapshot wins.
  static Future<bool> writeLocalSnapshot(BackupArchive archive) async {
    final email = archive.email;
    if (email.isEmpty) return false;

    final payload = archive.toJson();
    try {
      final file = await _snapshotFile(email);
      final existing = await file.exists() ? await file.readAsString() : null;

      if (existing != null) {
        final existingCount = _documentCountOf(existing);
        if (existingCount > archive.documentCount) {
          // The stored snapshot is more complete — keep it.
          return false;
        }
      }

      // Write-then-rename, so a kill mid-write cannot leave a truncated
      // snapshot that parses as a valid-but-empty backup.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(payload);
      await tmp.rename(file.path);
      return true;
    } catch (e, s) {
      debugPrint('[FullBackupService] local snapshot write failed: $e');
      AppAnalytics.recordError(e, s, reason: 'full_backup_snapshot_write');
      return false;
    }
  }

  /// Reads the automatic snapshot for [email], or null when there is none.
  static Future<BackupArchive?> readLocalSnapshot(String email) async {
    try {
      final file = await _snapshotFile(email);
      if (!await file.exists()) return null;
      return BackupArchive.fromJson(await file.readAsString());
    } catch (e) {
      debugPrint('[FullBackupService] local snapshot read failed: $e');
      return null;
    }
  }

  /// Whether an automatic snapshot exists for [email].
  static Future<bool> hasLocalSnapshot(String email) async {
    final snapshot = await readLocalSnapshot(email);
    return snapshot != null && snapshot.documentCount > 0;
  }

  /// Number of documents in a serialized archive, without a full parse.
  static int _documentCountOf(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return 0;
      final collections = decoded['collections'];
      if (collections is! Map) return 0;
      var total = 0;
      for (final value in collections.values) {
        if (value is List) total += value.length;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  // ============================
  // READ HELPERS
  // ============================

  static Future<List<Map<String, dynamic>>> _fetchCollection(
    String email,
    String collection,
  ) async {
    final override = fetchCollectionOverride;
    if (override != null) return override(email, collection);

    // Un-ordered and server-sourced on purpose: the same reasoning as
    // LocalBackupService._fetchAll. An `orderBy('createdAt')` drops documents
    // missing that field (SMS imports, older rows), and this is the one path
    // that must not lose anything.
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection(collection)
        .get(const GetOptions(source: Source.server));

    return snap.docs.map((d) {
      return {
        BackupArchive.idField: d.id,
        ..._jsonSafe(d.data()),
      };
    }).toList();
  }

  static Future<Map<String, dynamic>?> _fetchProfile(String email) async {
    final override = fetchProfileOverride;
    if (override != null) return override(email);

    final snap = await FirebaseFirestore.instance
        .doc('users/$email')
        .get(const GetOptions(source: Source.server));
    if (!snap.exists) return null;
    return _jsonSafe(snap.data() ?? const {});
  }

  static Future<Map<String, dynamic>?> _fetchPortfolio(String email) async {
    final override = fetchPortfolioOverride;
    if (override != null) return override(email);

    final snap = await FirebaseFirestore.instance
        .doc('users/$email/wealth/portfolio')
        .get(const GetOptions(source: Source.server));
    if (!snap.exists) return null;
    return _jsonSafe(snap.data() ?? const {});
  }

  static Future<void> _writeDoc(String path, Map<String, dynamic> data) async {
    final override = writeOverride;
    if (override != null) return override(path, data);
    await FirebaseFirestore.instance
        .doc(path)
        .set(data, SetOptions(merge: true));
  }

  /// Commits one chunk of documents as a single Firestore batch.
  ///
  /// Atomic by construction: the whole chunk lands or none of it does. That
  /// is why the caller falls back to per-document writes when it fails.
  static Future<void> _commitChunk(
    String email,
    String collection,
    List<Map<String, dynamic>> chunk,
  ) async {
    final override = batchWriteOverride;
    if (override != null) {
      await override(email, collection, chunk);
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    for (final item in chunk) {
      final ref = _collectionRef(
        email,
        collection,
        item['_docId'] as String,
      );
      batch.set(
        ref,
        item['_data'] as Map<String, dynamic>,
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Writes one document on its own — the fallback for a rejected batch.
  static Future<void> _writeCollectionDoc(
    String email,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final override = docWriteOverride;
    if (override != null) {
      await override(email, collection, docId, data);
      return;
    }
    await _collectionRef(email, collection, docId).set(
          data,
          SetOptions(merge: true),
        );
  }

  static DocumentReference<Map<String, dynamic>> _collectionRef(
    String email,
    String collection,
    String docId,
  ) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .collection(collection)
          .doc(docId);

  // ============================
  // SERIALIZATION
  // ============================

  /// Converts Firestore-specific types to JSON-safe values, recursively.
  ///
  /// [GeoPoint] and [DocumentReference] are preserved with a tagged envelope so
  /// they can be revived exactly; without this a location-based asset would
  /// come back as an unusable `"GeoPoint(lat, lng)"` string.
  ///
  /// The implementation lives on [BackupArchive] so the archive and the
  /// capture path cannot drift into two different envelope formats.
  static Map<String, dynamic> _jsonSafe(Map<String, dynamic> data) =>
      BackupArchive.jsonSafeMap(data);

  /// Inverse of [_jsonSafe]. Also normalizes bare ISO strings in *date-named*
  /// fields to Timestamps so an archive produced by an older build (or by the
  /// GDPR export) still restores correctly.
  ///
  /// The date-name gate is inherited from `LocalBackupService` on purpose: a
  /// blanket "any ISO-looking string" rule destroyed free text such as a note
  /// reading "2026-01-15T10:00 was the party".
  static Map<String, dynamic> _revive(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) => out[k] = _reviveValue(v, k));
    return out;
  }

  static Object? _reviveValue(Object? value, String fieldName) {
    if (value is String) {
      if (_isDateField(fieldName) && _looksLikeIsoDate(value)) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return Timestamp.fromDate(parsed.toUtc());
      }
      return value;
    }
    if (value is Map) {
      final m = Map<String, dynamic>.from(value);
      final ts = m['__ts__'];
      if (ts is String) {
        final parsed = DateTime.tryParse(ts);
        if (parsed != null) return Timestamp.fromDate(parsed.toUtc());
      }
      final geo = m['__geo__'];
      if (geo is Map) {
        final lat = (geo['lat'] as num?)?.toDouble();
        final lng = (geo['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) return GeoPoint(lat, lng);
      }
      final ref = m['__ref__'];
      if (ref is String) return FirebaseFirestore.instance.doc(ref);

      final out = <String, dynamic>{};
      m.forEach((k, v) => out[k] = _reviveValue(v, k));
      return out;
    }
    if (value is List) {
      return value.map((v) => _reviveValue(v, fieldName)).toList();
    }
    return value;
  }

  /// The date-name gate. Mirrors `LocalBackupService._isDateField`, plus the
  /// `__ts__` envelope which is unambiguous.
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

  /// Field names that hold free text, so an ISO-looking value must NOT be
  /// converted. A note reading "2026-01-15T10:00 was the party" shipped as a
  /// corrupted Timestamp once already.
  static const Set<String> _freeTextFields = {
    'note',
    'notes',
    'description',
    'title',
    'remark',
    'remarks',
    'comment',
    'comments',
    'name',
    'recipientname',
    'sendername',
    'merchant',
    'address',
    'text',
    'label',
  };

  static bool _isDateField(String key) {
    final k = key.toLowerCase();
    if (_freeTextFields.contains(k)) return false;
    if (_dateFieldNames.contains(k)) return true;
    return k.endsWith('date') || k.endsWith('dates') || k.endsWith('timestamp');
  }

  static bool _looksLikeIsoDate(String s) =>
      RegExp(r'\d{4}-\d{2}-\d{2}T').hasMatch(s);

  @visibleForTesting
  static Map<String, dynamic> debugRevive(Map<String, dynamic> data) =>
      _revive(data);

  @visibleForTesting
  static Map<String, dynamic> debugJsonSafe(Map<String, dynamic> data) =>
      _jsonSafe(data);

  @visibleForTesting
  static bool debugIsDateField(String key) => _isDateField(key);

  @visibleForTesting
  static List<String> debugCacheKeys(String email) => _cacheKeysFor(email);
}

/// Outcome of a restore. [failed] is keyed the same way as [written] so the UI
/// can name exactly what did not come back — a restore that reports "1000
/// transactions restored" while one collection silently failed is the failure
/// mode this class exists to prevent.
class BackupRestoreResult {
  const BackupRestoreResult({required this.written, required this.failed});

  final Map<String, int> written;
  final Map<String, Object> failed;

  int get totalWritten =>
      written.values.fold(0, (total, n) => total + n);

  bool get hasFailures => failed.isNotEmpty;

  /// Collections that were present in the archive with a non-zero document
  /// count, for a human-readable summary.
  List<MapEntry<String, int>> get summary {
    final entries = written.entries.where((e) => e.value > 0).toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}
