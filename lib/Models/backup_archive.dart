import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// A complete, restorable snapshot of one user's account.
///
/// This is the file a user downloads and keeps. Unlike the GDPR export (a human
/// readable dump with no way back in) and unlike `LocalBackupService` (a silent
/// device-local mirror of `transactions` only), an *archive* is a round-trip
/// format: [FullBackupService] can rebuild the account from it.
///
/// Every collection the user owns is captured — the 41 in
/// `UserService.subcollections`, the profile document, and the
/// `wealth/portfolio` summary — because a wipe does not stop at transactions.
/// The 2026-10-21 incident deleted 34 subcollections (791 transactions) from a
/// live account and there was no downloadable copy to restore from.
class BackupArchive {
  /// Bump when the on-disk shape changes in a way restore must understand.
  /// Restore refuses an archive newer than it can read rather than silently
  /// importing a partial account.
  static const int currentFormatVersion = 1;

  /// Magic marker so a wrong file is rejected with "this is not a backup"
  /// instead of importing zero documents and reporting success.
  static const String fileType = 'wealthsync_backup';

  BackupArchive({
    required this.formatVersion,
    required this.createdAt,
    required this.email,
    required this.profile,
    required this.wealthPortfolio,
    required this.collections,
    this.appVersion = '',
  });

  final int formatVersion;

  /// UTC instant the snapshot was taken. Shown in the UI and in the restore
  /// confirmation, so the user can pick between several downloaded files.
  final DateTime createdAt;
  final String email;

  /// The `users/{email}` document, or null when it did not exist.
  final Map<String, dynamic>? profile;

  /// The `users/{email}/wealth/portfolio` summary, or null.
  final Map<String, dynamic>? wealthPortfolio;

  /// Subcollection name -> its documents. Each document carries its Firestore
  /// id under [idField] so restore recreates the same document.
  final Map<String, List<Map<String, dynamic>>> collections;

  final String appVersion;

  /// The Firestore document id is stored under this key rather than `_id`
  /// (the GDPR export's choice) because some models already read `_id`-free
  /// maps and because a leading underscore reads as metadata.
  static const String idField = 'id';

  /// Total documents across every collection, excluding the profile.
  int get documentCount =>
      collections.values.fold(0, (total, docs) => total + docs.length);

  /// Collections that actually hold at least one document. Used by the restore
  /// summary so the user sees what will be written.
  Map<String, int> get populatedCollections => {
    for (final e in collections.entries)
      if (e.value.isNotEmpty) e.key: e.value.length,
  };

  // ============================
  // PROFILE FIELD HYGIENE
  // ============================

  /// Fields on `users/{email}` that are *credentials* — secrets that must never
  /// be written into a file the user downloads, emails to themselves, or drops
  /// in a cloud drive.
  ///
  /// `purchaseToken` is the Google Play purchase credential the rules require
  /// to claim 'pro'. It authenticates a purchase; a copy of it in a shared
  /// file is a copy of it in someone's inbox.
  static const Set<String> credentialProfileFields = {'purchaseToken'};

  /// Fields on `users/{email}` that are *server-authoritative*: the purchase
  /// entitlement, the trial, the admin flag and the referral bookkeeping.
  ///
  /// A restore must never write these back. There are two reasons, and the
  /// second is the dangerous one:
  ///
  ///  1. `firestore.rules` refuses most of them on an owner write.
  ///     `isAdmin` and `referredBy` are rejected outright, and
  ///     `subscriptionStatus: 'pro'` needs a recorded purchase — so including
  ///     them makes the *entire* profile write fail, and the user loses their
  ///     name, phone and address as well.
  ///  2. Even where the rules do allow it, a restore becomes a privilege
  ///     regression. Restoring a backup taken before a purchase would write
  ///     `subscriptionStatus: 'free'` over a live `'pro'` and silently strip
  ///     the user's paid plan; a forged `trialEndDate` would grant trial days
  ///     that no purchase paid for.
  ///
  /// The live document keeps its own values: the restore is a merge, and a
  /// merge never removes a field the write does not mention — so the
  /// entitlement survives the restore untouched.
  static const Set<String> serverAuthoritativeProfileFields = {
    'subscriptionStatus',
    'isPro',
    'trialEndDate',
    'trialUsed',
    'planType',
    'expiryDate',
    'purchaseToken',
    'isAdmin',
    'referredBy',
    'referralCount',
  };

  /// Removes the credential fields from a captured profile so no secret is
  /// written into the downloaded file.
  ///
  /// The rest of the document is kept verbatim: the archive is meant to be an
  /// honest record of the account, and the entitlement fields are a useful
  /// record of *what the plan was when the backup was taken*. They are simply
  /// never written back — see [serverAuthoritativeProfileFields].
  static Map<String, dynamic> redactProfileForArchive(
    Map<String, dynamic> profile,
  ) {
    final copy = Map<String, dynamic>.from(profile);
    for (final field in credentialProfileFields) {
      copy.remove(field);
    }
    return copy;
  }

  /// Removes the server-authoritative fields from an archived profile before it
  /// is written back, so a restore can never regress or fabricate entitlement.
  static Map<String, dynamic> stripServerAuthoritativeFields(
    Map<String, dynamic> profile,
  ) {
    final copy = Map<String, dynamic>.from(profile);
    for (final field in serverAuthoritativeProfileFields) {
      copy.remove(field);
    }
    return copy;
  }

  Map<String, dynamic> toMap() => {
    'fileType': fileType,
    'formatVersion': formatVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'email': email,
    // The profile is stored verbatim; `null` is meaningful (no profile doc).
    'profile': profile,
    'wealthPortfolio': wealthPortfolio,
    'collections': collections,
  };

  /// Encodes to the bytes written to disk / handed to the share sheet.
  ///
  /// `toEncodable` is what keeps this from ever throwing: a Firestore type
  /// that reached the archive without passing through [jsonSafeValue] (a
  /// `Timestamp` in the profile, say) is encoded as its tagged envelope
  /// rather than crashing the download. A backup that fails to write is the
  /// one failure this feature cannot have.
  String toJson({bool pretty = false}) {
    final encoder = pretty
        ? JsonEncoder.withIndent('  ', jsonSafeValue)
        : JsonEncoder(jsonSafeValue);
    return encoder.convert(toMap());
  }

  /// Converts one value into something JSON can hold.
  ///
  /// Firestore's own types do not survive a plain encode — a `Timestamp`
  /// becomes a `DateTime` with a different shape, a `GeoPoint` becomes a
  /// `LatLng`. They are written as tagged envelopes (`__ts__`, `__geo__`,
  /// `__ref__`) that [BackupArchive.fromMap] revives exactly.
  static Object? jsonSafeValue(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return {'__ts__': value.toDate().toUtc().toIso8601String()};
    }
    if (value is DateTime) {
      return {'__ts__': value.toUtc().toIso8601String()};
    }
    if (value is GeoPoint) {
      return {
        '__geo__': {'lat': value.latitude, 'lng': value.longitude},
      };
    }
    if (value is DocumentReference) {
      return {'__ref__': value.path};
    }
    if (value is Map) {
      final m = <String, dynamic>{};
      value.forEach((k, v) => m[k.toString()] = jsonSafeValue(v));
      return m;
    }
    if (value is List) return value.map(jsonSafeValue).toList();
    // int/double/String/bool are already JSON-safe.
    if (value is num || value is String || value is bool) return value;
    return value.toString();
  }

  /// Converts a whole document into something JSON can hold.
  static Map<String, dynamic> jsonSafeMap(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((key, value) {
      out[key] = jsonSafeValue(value);
    });
    return out;
  }

  /// Parses an archive, throwing [BackupFormatException] with an actionable
  /// message when the file is not a WealthSync backup or is too new to read.
  ///
  /// Deliberately strict: a silent null here would surface as "restored 0
  /// documents" after the user picked a wrong file, which reads as data loss.
  factory BackupArchive.fromJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      throw const BackupFormatException(
        'This file is not valid JSON. Pick the .json file you downloaded from '
        'Settings \u2192 Data & Support \u2192 Download Backup.',
      );
    }
    return BackupArchive.fromMap(decoded);
  }

  factory BackupArchive.fromMap(Object? decoded) {
    if (decoded is! Map) {
      throw const BackupFormatException(
        'This file does not contain a WealthSync backup.',
      );
    }
    final map = Map<String, dynamic>.from(decoded);

    if (map['fileType'] != fileType) {
      throw const BackupFormatException(
        'This is not a WealthSync backup file. Pick the .json file you '
        'downloaded from Settings \u2192 Data & Support \u2192 Download Backup.',
      );
    }

    final version = map['formatVersion'];
    if (version is! int) {
      throw const BackupFormatException('Backup is missing its format version.');
    }
    if (version > currentFormatVersion) {
      throw BackupFormatException(
        'This backup was created by a newer version of the app (format $version, '
        'this build reads $currentFormatVersion). Update the app and try again.',
      );
    }

    final rawCollections = map['collections'];
    final collections = <String, List<Map<String, dynamic>>>{};
    if (rawCollections is Map) {
      rawCollections.forEach((key, value) {
        if (value is! List) return;
        collections[key.toString()] = value
            .whereType<Map>()
            .map((d) => Map<String, dynamic>.from(d))
            .toList();
      });
    }

    return BackupArchive(
      formatVersion: version,
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      email: map['email']?.toString() ?? '',
      profile: map['profile'] is Map
          ? Map<String, dynamic>.from(map['profile'] as Map)
          : null,
      wealthPortfolio: map['wealthPortfolio'] is Map
          ? Map<String, dynamic>.from(map['wealthPortfolio'] as Map)
          : null,
      collections: collections,
      appVersion: map['appVersion']?.toString() ?? '',
    );
  }
}

/// Thrown when a chosen file is not a readable WealthSync backup. The message is
/// shown to the user verbatim, so it must say what to do next.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}
