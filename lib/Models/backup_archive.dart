import 'dart:convert';

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
  String toJson({bool pretty = false}) =>
      pretty ? const JsonEncoder.withIndent('  ').convert(toMap()) : jsonEncode(toMap());

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
