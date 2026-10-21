import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/l10n/app_localizations_en.dart';

/// The integration test asserts the backup screen's copy through
/// [AppStrings] (so the test file never re-types a literal), while the
/// screen itself renders the ARB copy. If the two drift, the integration test
/// fails for a reason that has nothing to do with the feature it is testing —
/// and the failure reads as "the button is missing" rather than "someone
/// renamed a string".
///
/// This pins the pairing.
void main() {
  final l10n = AppLocalizationsEn();

  test('the backup screen copy matches the ARB strings', () {
    expect(l10n.dataSupport, AppStrings.dataSupport);
    expect(l10n.backupAndRestoreAllData, AppStrings.backupAndRestoreAllData);
    expect(l10n.backupKeepOwnCopy, AppStrings.backupKeepOwnCopy);
    expect(l10n.backupDownload, AppStrings.backupDownload);
    expect(l10n.backupRestoreFromFile, AppStrings.backupRestoreFromFile);
  });

  test('the restore snackbars keep the wording the E2E regex expects', () {
    // integration_test/data_management_test.dart matches
    // /Restored \d+ transactions? from backup/ — the plural-aware ARB string
    // must still satisfy it, or that test breaks on a copy change.
    expect(l10n.restoredFromBackup(1), 'Restored 1 transaction from backup');
    expect(l10n.restoredFromBackup(5), 'Restored 5 transactions from backup');
    expect(
      l10n.restoredFromPreservedBackup(5),
      contains('Restored 5 transactions from backup'),
    );
    expect(l10n.backupHadNoTransactions, 'Backup had no transactions to restore');
  });
}
