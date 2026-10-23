import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/settings_widgets.dart';
import 'package:money_control/Models/backup_archive.dart';
import 'package:money_control/Services/app_analytics.dart';
import 'package:money_control/Services/full_backup_service.dart';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Download a complete backup of the account, or rebuild it from one.
///
/// The screen leads with *why* this exists rather than with two buttons: the
/// risk it protects against is silent and irreversible, and a user who
/// understands that is far likelier to actually take a backup.
class FullBackupScreen extends StatefulWidget {
  const FullBackupScreen({super.key});

  @override
  State<FullBackupScreen> createState() => _FullBackupScreenState();
}

class _FullBackupScreenState extends State<FullBackupScreen> {
  bool _busy = false;

  /// Collections whose read failed during the last capture. Non-empty means the
  /// archive on disk is incomplete and the user must be told, not reassured.
  List<String> _captureErrors = const [];

  /// Whether the app holds an automatic snapshot of this account on the
  /// device. The restore-from-snapshot tile only appears when one exists —
  /// an always-visible button that always fails is worse than no button.
  bool _hasSnapshot = false;

  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _refreshSnapshotState();
  }

  /// Checks for the device snapshot once the screen opens.
  ///
  /// Fire-and-forget with a mounted guard: the result only flips a tile's
  /// visibility, so a late answer must not touch a disposed State.
  Future<void> _refreshSnapshotState() async {
    final email = _email;
    if (email.isEmpty) return;
    final exists = await FullBackupService.hasLocalSnapshot(email);
    if (!mounted) return;
    setState(() => _hasSnapshot = exists);
  }

  Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _download() async {
    if (_busy) return;
    if (_email.isEmpty) {
      _snack(_l10n.backupNotSignedIn, AppColors.error);
      return;
    }

    setState(() {
      _busy = true;
      _captureErrors = const [];
    });

    final errors = <String>[];
    try {
      final archive = await FullBackupService.capture(
        _email,
        appVersion: await _appVersion(),
        onCollectionError: (collection, _) => errors.add(collection),
      );

      if (!mounted) return;
      final path = await FullBackupService.download(archive);

      AppAnalytics.log(AnalyticsEvent.fullBackupDownloaded, {
        'documents': archive.documentCount,
        'collections': archive.populatedCollections.length,
        'failed_collections': errors.length,
      });

      if (!mounted) return;
      if (path == null) {
        // Cancelled at the picker — not a failure, say nothing.
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _captureErrors = List.unmodifiable(errors);
        _busy = false;
      });
      _snack(
        _l10n.backupSaved(
          archive.documentCount,
          archive.populatedCollections.length,
        ),
        errors.isEmpty ? AppColors.success : AppColors.warning,
      );
    } catch (e, s) {
      AppAnalytics.recordError(e, s, reason: 'full_backup_download_failed');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(_l10n.backupFailed('$e'), AppColors.error);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    if (_email.isEmpty) {
      _snack(_l10n.backupNotSignedIn, AppColors.error);
      return;
    }

    BackupArchive archive;
    try {
      final picked = await FullBackupService.pickAndParse();
      if (picked == null) return; // cancelled
      archive = picked;
    } on BackupFormatException catch (e) {
      _snack(e.message, AppColors.error);
      return;
    } catch (e, s) {
      AppAnalytics.recordError(e, s, reason: 'full_backup_read_failed');
      _snack(_l10n.backupFailed('$e'), AppColors.error);
      return;
    }

    if (!mounted) return;

    await _confirmAndRestore(archive);
  }

  /// Restores the account from the automatic snapshot the app keeps on the
  /// device (taken once a day by the background worker).
  ///
  /// This is the safety net for a user who never opened the backup screen:
  /// the snapshot exists whether or not they knew it did, and it covers every
  /// collection — not just transactions.
  Future<void> _restoreFromDeviceSnapshot() async {
    if (_busy) return;
    if (_email.isEmpty) {
      _snack(_l10n.backupNotSignedIn, AppColors.error);
      return;
    }

    final archive = await FullBackupService.readLocalSnapshot(_email);
    if (!mounted) return;
    if (archive == null || archive.documentCount == 0) {
      _snack(_l10n.backupNoDeviceSnapshot, AppColors.warning);
      return;
    }

    await _confirmAndRestore(archive);
  }

  /// Asks for confirmation, then restores [archive].
  ///
  /// Shared by the file restore and the device-snapshot restore so both paths
  /// show the same per-collection breakdown, the same account-mismatch
  /// warning and the same "nothing is deleted" promise.
  Future<void> _confirmAndRestore(BackupArchive archive) async {
    final accountMismatch =
        archive.email.isNotEmpty && archive.email != _email;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n.backupRestoreConfirmTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _l10n.backupRestoreTaken(_formatDate(archive.createdAt)),
              ),
              SizedBox(height: 8.h),
              Text(_l10n.backupRestoreConfirmItems(archive.documentCount)),
              if (archive.populatedCollections.isNotEmpty) ...[
                SizedBox(height: 12.h),
                ...archive.populatedCollections.entries.map(
                  (e) => Text('• ${_label(e.key)}: ${e.value}'),
                ),
              ],
              if (accountMismatch) ...[
                SizedBox(height: 12.h),
                Text(
                  _l10n.backupRestoreWrongAccount(archive.email, _email),
                  style: TextStyle(color: AppColors.warning),
                ),
              ],
              SizedBox(height: 12.h),
              Text(_l10n.backupRestoreExistingKept),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_l10n.backupRestoreCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_l10n.backupRestoreConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await FullBackupService.restore(archive);

      AppAnalytics.log(AnalyticsEvent.fullBackupRestored, {
        'restored': result.totalWritten,
        'collections': result.written.length,
        'failed_collections': result.failed.length,
      });

      if (!mounted) return;
      setState(() => _busy = false);

      if (result.hasFailures) {
        // The detail matters: a collection can fail because the server
        // rejected a handful of documents, and the user needs to know that
        // most of their data came back and which few did not.
        final details = result.failed.entries
            .map((e) => '${e.key}: ${_failureDetail(e.value)}')
            .join('; ');
        _snack(
          _l10n.backupRestorePartial(
            result.totalWritten,
            result.failed.length,
            result.failed.keys.join(', '),
            details,
          ),
          AppColors.error,
        );
      } else {
        _snack(_l10n.backupRestoreSuccess(result.totalWritten), AppColors.success);
      }
    } catch (e, s) {
      AppAnalytics.recordError(e, s, reason: 'full_backup_restore_failed');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(_l10n.backupRestoreFailed('$e'), AppColors.error);
    }
  }

  /// A one-line description of a restore failure, for the snack bar.
  ///
  /// The service stores a human-readable string when it knows what went
  /// wrong (for example "3 of 210 documents were rejected by the server")
  /// and the raw error otherwise. The raw error can be a paragraph, so it is
  /// trimmed to something a snack bar can show.
  static String _failureDetail(Object failure) {
    final text = failure is String ? failure : failure.toString();
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 120) return collapsed;
    return '${collapsed.substring(0, 117)}...';
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String _label(String collection) {
    if (collection == 'profile') return 'Profile';
    if (collection == 'wealth_portfolio') return 'Wealth summary';
    return collection
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_l10n.backupAndRestore),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: AppType.titleMedium(isDark ? Colors.white : AppColors.lightTextPrimary),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.contentMaxWidth(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceCard
                            : AppColors.lightSurfaceCard,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: AppColors.primary,
                                size: 20.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                _l10n.backupKeepOwnCopy,
                                style: AppType.labelLarge(isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _l10n.backupKeepOwnCopyBody,
                            style: AppType.bodySmall(isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                          ),
                        ],
                      ),
                    ),

                    if (_captureErrors.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          _l10n.backupIncompleteWarning(
                            _captureErrors.join(', '),
                          ),
                          style: AppType.bodySmall(AppColors.error),
                        ),
                      ),
                    ],

                    SizedBox(height: 20.h),
                    SectionHeader(_l10n.backupSectionTitle),
                    SettingsTile(
                      icon: Icons.save_alt_outlined,
                      title: _busy
                          ? _l10n.backupWorking
                          : _l10n.backupDownload,
                      onTap: _busy ? null : _download,
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 4.h),
                      child: Text(
                        _l10n.backupDownloadExplain,
                        style: AppType.labelSmall(isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                      ),
                    ),

                    SizedBox(height: 16.h),
                    SectionHeader(_l10n.restore),
                    SettingsTile(
                      icon: Icons.settings_backup_restore,
                      title: _l10n.backupRestoreFromFile,
                      onTap: _busy ? null : _restore,
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 4.h),
                      child: Text(
                        _l10n.backupRestoreExplain,
                        style: AppType.labelSmall(isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                      ),
                    ),

                    // The automatic snapshot: taken once a day by the
                    // background worker, kept on the device. Shown only when
                    // one actually exists.
                    if (_hasSnapshot) ...[
                      SizedBox(height: 16.h),
                      SettingsTile(
                        icon: Icons.history_rounded,
                        title: _l10n.backupRestoreFromDeviceSnapshot,
                        onTap: _busy ? null : _restoreFromDeviceSnapshot,
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          left: 16.w,
                          right: 16.w,
                          top: 4.h,
                        ),
                        child: Text(
                          _l10n.backupRestoreFromDeviceSnapshotExplain,
                          style: AppType.labelSmall(isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
