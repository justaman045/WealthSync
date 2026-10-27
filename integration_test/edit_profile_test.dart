import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Config/app_strings.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsWithScreenshots('E2E: Edit Profile Flow', (WidgetTester tester) async {
    // 1-3. App Launch + Splash/Onboarding + Login
    await launchAndSignIn(tester);

    // The profile doc is shared state that clearAccountData() does not reset.
    // Snapshot it now and restore it in the finally so this file's rename does
    // not leak into later files/runs (or into the account permanently).
    final profileSnapshot = await snapshotUserProfile();

    try {
      // 4. Verify Home Screen
      expect(find.textContaining('Welcome'), findsWidgets);
      expect(find.text(AppStrings.totalBalance), findsOneWidget);

      // 5. Navigate to Edit Profile (tap the profile picture Hero in the AppBar)
      final profilePic = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'profile_pic',
      );
      await tester.tap(profilePic.first);
      await pumpAndSettleSafe(tester);

      // 6. Verify Edit Profile Screen
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);

      // 7. Interact with Fields (order: First, Last, Email, Phone, Address)
      final textFields = find.byType(TextFormField);

      // Wait for the async prefill to land before typing. The form deliberately
      // never overwrites a field the user already typed into, so typing into a
      // not-yet-prefilled form would leave the other fields empty and the save
      // would clear them.
      for (var i = 0; i < 40; i++) {
        final field = tester.widget<TextFormField>(textFields.at(0));
        if ((field.controller?.text ?? '').isNotEmpty) break;
        await pumpReal(tester);
      }

      await tester.enterText(textFields.at(0), 'UpdatedName');
      await pumpAndSettleSafe(tester);

      await tester.enterText(textFields.at(1), 'UpdatedLast');
      await pumpAndSettleSafe(tester);

      await tester.enterText(textFields.at(3), '1234567890'); // Phone
      await pumpAndSettleSafe(tester);

      // 8. Select Date of Birth
      final calendarIcon = find.byIcon(Icons.calendar_today_rounded);
      await tester.ensureVisible(calendarIcon);
      await pumpAndSettleSafe(tester);
      await tester.tap(calendarIcon);
      await pumpAndSettleSafe(tester);

      await tester.tap(find.text('OK'));
      await pumpAndSettleSafe(tester);

      // 9. Save Changes
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpAndSettleSafe(tester);
      final saveButton = find.text(AppStrings.saveChanges);
      await tester.ensureVisible(saveButton);
      await pumpAndSettleSafe(tester);
      await tester.tap(saveButton);
      await pumpAndSettleSafe(tester);

      // 10. Wait for the async save + profile refresh
      await pumpReal(tester, const Duration(seconds: 2));

      // 11. Verify Changes Persisted. Assert the stored profile — the real
      // contract — instead of the on-screen field text, which depends on where
      // the form happens to be scrolled. Step 12 still proves the edit screen
      // is showing (it taps that screen's back arrow).
      final email = FirebaseAuth.instance.currentUser!.email!;
      Map<String, dynamic>? saved;
      for (var i = 0; i < 30; i++) {
        saved = (await FirebaseFirestore.instance
                .collection('users')
                .doc(email)
                .get())
            .data();
        if (saved?['firstName'] == 'UpdatedName') break;
        await pumpReal(tester);
      }
      expect(saved?['firstName'], 'UpdatedName');
      expect(saved?['lastName'], 'UpdatedLast');
      expect(saved?['phone'], '1234567890');

      // 12. Navigate Back
      final backButton = find.byIcon(Icons.arrow_back_ios);
      await tester.tap(backButton);
      await pumpAndSettleSafe(tester);

      // Verify Home
      expect(find.textContaining('Welcome'), findsWidgets);

      // Verify Name updated on Home (ProfileController refreshes after save).
      // The appbar greeting is a shimmer until the Firestore profile fetch
      // completes, so poll generously on the slow emulator.
      var nameShown = false;
      for (int i = 0; i < 60; i++) {
        await pumpReal(tester);
        if (find.text('UpdatedName').evaluate().isNotEmpty) {
          nameShown = true;
          break;
        }
      }
      if (!nameShown) {
        final texts = find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Text),
            )
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .toList();
        debugPrint('Home AppBar texts: $texts');
      }
      expect(nameShown, isTrue, reason: 'Home should show the updated first name');
    } finally {
      await restoreUserProfile(profileSnapshot);
    }
  });
}
