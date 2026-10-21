import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Data & Support: Backup Data + Restore Data (both local-cache/Firestore
  // round trips). CSV/GDPR exports are skipped: FilePicker.saveFile opens the
  // Android system file picker, which integration tests cannot drive.
  testWidgetsWithScreenshots('Data management: backup and restore', (
    WidgetTester tester,
  ) async {
    await launchAndSignIn(tester);
    await tapNavTab(tester, Icons.tune_rounded, 'Settings');
    await tapUntilMarker(tester, find.text('Data & Support'), find.text('Backup Data'));

    // ── 1. Backup ───────────────────────────────────────────────────────────
    await tapWhenVisible(tester, find.text('Backup Data'));
    await waitFor(tester, find.text('Data backed up securely'));
    expect(find.text('Data backed up securely'), findsWidgets);
    await pumpReal(tester, const Duration(seconds: 2)); // let the snackbar go

    // ── 2. Restore ──────────────────────────────────────────────────────────
    await tapWhenVisible(tester, find.text('Restore Data'));
    await waitFor(tester, find.text('Restore Data')); // confirm dialog title
    await tapWhenVisible(tester, find.widgetWithText(TextButton, 'Restore'));
    // The app has three legitimate outcomes here, because the test account is
    // wiped on launch and may legitimately hold zero transactions:
    //   - "Restored N transactions from backup"
    //   - "Backup had no transactions to restore"
    //   - "No local backup found. Tap 'Backup Data' first." (hasUserBackup is
    //     false for an empty backup, so the restore never runs at all)
    // The old assertion waited for the literal 'Data restored from backup',
    // which does not exist anywhere in lib/ — that step could never have passed.
    await waitFor(
      tester,
      find.textContaining(
        RegExp(
          r'(Restored \d+ transactions? from backup'
          r'|Backup had no transactions to restore'
          r'|No local backup found)',
        ),
      ),
      seconds: 20,
    );
    await pumpReal(tester, const Duration(seconds: 2));

    // ── 3. Back to settings and home ────────────────────────────────────────
    await popScreen(tester); // Data & Support → Settings
    await waitFor(tester, find.text('General'));
    await tapNavTab(tester, Icons.grid_view_rounded, AppStrings.totalBalance);
    await waitForHome(tester);
  });
}
