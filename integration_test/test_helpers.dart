// Shared helpers for E2E integration tests. These make login/onboarding and
// common flows robust against real-device timing so the suite can pass
// deterministically in CI (fresh emulator, live Firebase account).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Config/app_strings.dart';
import 'package:money_control/firebase_options.dart';
import 'package:money_control/main.dart' as app;
import 'package:money_control/Services/performance_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'test_credentials.dart';

/// The 26 per-asset-type subcollections under `users/{email}/` (matches
/// firestore.rules). Sweep tests add/delete entries across these; a crashed
/// run can leave leftovers that break the '1 item' assertions, so they are
/// wiped before each file.
const List<String> _wealthSubcollections = [
  'fd_accounts',
  'ppf_accounts',
  'post_office_schemes',
  'bonds',
  'chit_funds',
  'stock_holdings',
  'sip_holdings',
  'etf_holdings',
  'foreign_stocks',
  'startup_investments',
  'pf_accounts',
  'vpf_accounts',
  'nps_accounts',
  'gold_holdings',
  'sgb_holdings',
  'jewelry_items',
  'crypto_holdings',
  'reit_holdings',
  'p2p_loans',
  'agri_land',
  'properties',
  'vehicles',
  'insurance_policies',
  'business_assets',
  'bnpl_entries',
  'credit_cards',
];

/// Data collections the integration suite mutates that can accumulate across
/// files/runs and skew assertions (leftover budgets, goals, loans, … from a
/// crashed file). The 150-txn/month free cap makes `transactions` the critical
/// one — an account that ever reaches it can no longer save transactions.
const List<String> _dataSubcollections = [
  'transactions',
  'categories',
  'budgets',
  'goals',
  'loans',
  'recurring_payments',
  'lent_money',
  'challenges',
];

/// Sanitizes a test description into a filesystem-safe name (max 60 chars).
String sanitizeName(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[^\w]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
}

/// Writes [bytes] to `<app cache>/screenshots/<name>.png` so CI can pull them
/// with `adb exec-out run-as <pkg> cat`. Errors are swallowed — the screenshot
/// must never mask the real test failure.
Future<void> _saveScreenshot(
  WidgetTester tester,
  List<int> bytes,
  String name,
) async {
  final base = await getTemporaryDirectory();
  final dir = Directory('${base.path}/screenshots');
  await dir.create(recursive: true);
  await File('${dir.path}/$name.png').writeAsBytes(bytes);
}

/// Captures the current frame via the Flutter engine (rasterizes the root
/// layer offscreen). Unlike `binding.takeScreenshot`, this needs no
/// `convertFlutterSurfaceToImage()` surface swap, so it works on the emulator's
/// fragile gfxstream GL layer and never stresses the ColorBuffer/PixelCopy
/// path that has wedged the CI emulator mid-suite. Returns null on any failure
/// so callers fall back to the PixelCopy path.
Future<List<int>?> _captureEngine() async {
  try {
    final views = RendererBinding.instance.renderViews;
    if (views.isEmpty) return null;
    final view = views.first;
    // `debugLayer` is the same accessor flutter_test's goldens use (the public
    // `layer` member is protected); integration tests run in debug mode so it
    // is non-null after the first frame.
    final layer = view.debugLayer;
    if (layer is! OffsetLayer) return null;
    final image = await layer.toImage(view.paintBounds);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } catch (e) {
    // ignore: avoid_print
    print('Engine screenshot failed: $e');
    return null;
  }
}

/// Captures the current screen to the device cache. Primary path is engine
/// rasterization ([_captureEngine]); falls back to `binding.takeScreenshot`
/// (which needs `convertFlutterSurfaceToImage()`, applied lazily here) when the
/// engine path yields nothing.
/// Prints the outcome so CI logs reveal which path (and whether capture) fails.
Future<void> captureScreenshot(WidgetTester tester, String name) async {
  try {
    await tester.pump();
    var bytes = await _captureEngine();
    if (bytes == null || bytes.isEmpty) {
      try {
        final binding =
            IntegrationTestWidgetsFlutterBinding.ensureInitialized();
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        final shot = await binding.takeScreenshot(name);
        if (shot.isNotEmpty) bytes = shot;
      } catch (e) {
        // ignore: avoid_print
        print('Fallback screenshot failed for $name: $e');
      }
    }
    if (bytes == null || bytes.isEmpty) {
      // ignore: avoid_print
      print('Screenshot capture empty for $name');
      return;
    }
    await _saveScreenshot(tester, bytes, name);
    // ignore: avoid_print
    print('Screenshot captured: $name (${bytes.length} bytes)');
  } catch (e) {
    // ignore: avoid_print
    print('Screenshot capture failed for $name: $e');
  }
}

/// [testWidgets] variant that automatically captures a screenshot of the exact
/// failing state to the device cache. Useful for debugging flaky E2E runs in
/// CI without `flutter drive` (no host callback exists under `flutter test`).
/// No `convertFlutterSurfaceToImage()` is applied up front — capture uses the
/// engine path by default and swaps surfaces lazily only when it falls back.
void testWidgetsWithScreenshots(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
      await captureScreenshot(tester, 'result_${sanitizeName(description)}');
    } catch (e) {
      await captureScreenshot(tester, 'failure_${sanitizeName(description)}');
      rethrow;
    }
  });
}

/// pumpAndSettle that never throws. Home/splash screens may keep running
/// background animations that prevent the default 10-minute timeout logic.
Future<void> pumpAndSettleSafe(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    await tester.pumpAndSettle(timeout);
  } catch (_) {
    // Fall through; callers re-check state with finders.
  }
}

/// Real-time wait + frame pump. `tester.pump(Duration(...))` advances a
/// virtual clock and may not wait wall-clock time in the live binding, so
/// polling loops that need the app's async work (auth restore, Firestore)
/// to actually progress should use this.
Future<void> pumpReal(
  WidgetTester tester, [
  Duration d = const Duration(seconds: 1),
]) async {
  await Future<void>.delayed(d);
  await tester.pump();
}

/// Taps through the 3-page welcome walkthrough (splash pre-login or onboarding
/// post-login) when present. Safe to call at any point; no-ops when absent.
/// Polls (real time) up to 30s for the first splash page, because a cold app
/// boot on the emulator can take several seconds to render the first frame.
Future<void> handleSplashAndOnboarding(WidgetTester tester) async {
  await pumpAndSettleSafe(tester);
  for (var i = 0; i < 30; i++) {
    if (find.text(AppStrings.totalBalance).evaluate().isNotEmpty) return;
    if (find.text(AppStrings.signIn).evaluate().isNotEmpty) return;
    if (find.text(AppStrings.getStarted).evaluate().isNotEmpty) break;
    await pumpReal(tester);
  }
  if (find.text(AppStrings.getStarted).evaluate().isNotEmpty) {
    await tester.tap(find.text(AppStrings.getStarted));
    await pumpAndSettleSafe(tester);
  }
  if (find.text(AppStrings.continueLabel).evaluate().isNotEmpty) {
    await tester.tap(find.text(AppStrings.continueLabel));
    await pumpAndSettleSafe(tester);
  }
  if (find.text(AppStrings.letsStart).evaluate().isNotEmpty) {
    await tester.tap(find.text(AppStrings.letsStart));
    await pumpAndSettleSafe(tester);
  }
}

/// Completes the post-login setup screen (`OnboardingScreen`) that a brand-new
/// account lands on instead of home.
///
/// This is a *different* screen from the pre-login walkthrough handled by
/// [handleSplashAndOnboarding]: it renders only after the first sign-in of an
/// account whose `users/{email}` doc has no `is_onboarded` flag, and it needs a
/// budget before it will continue. The suite used to depend on the fixture
/// accounts having been onboarded by hand once; a freshly rotated account made
/// every file fail at "home not reached" while auth was perfectly healthy.
///
/// Returns true when it completed setup, false when there was nothing to do
/// (home or the login screen is showing) — safe to call at any point.
Future<bool> completeOnboardingIfNeeded(
  WidgetTester tester, {
  int seconds = 30,
  bool afterSignIn = false,
}) async {
  final startButton = find.text(AppStrings.startTracking);
  final home = find.text(AppStrings.totalBalance);
  final loginScreen = find.text(AppStrings.signIn);
  for (var i = 0; i < seconds; i++) {
    if (home.evaluate().isNotEmpty) return false;
    // Login screen: sign-in (and whatever follows) is the caller's problem.
    // Skipped right after a sign-in tap, where the login screen is still
    // mounted for a moment while the auth call is in flight.
    if (!afterSignIn && loginScreen.evaluate().isNotEmpty) return false;
    if (startButton.evaluate().isNotEmpty) break;
    await pumpReal(tester);
  }
  if (startButton.evaluate().isEmpty) return false;

  // The budget field is the only TextFormField in the first card; currency is a
  // dropdown (its default is fine) and the referral field is optional.
  final budgetField = find.byType(TextFormField);
  if (budgetField.evaluate().isNotEmpty) {
    await tester.enterText(budgetField.first, '50000');
    await pumpReal(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpReal(tester);
  }

  await scrollUntilVisible(tester, startButton);
  await tester.tap(startButton, warnIfMissed: false);
  await pumpAndSettleSafe(tester);
  // Setup writes Firestore and then navigates, so wait for the end state — the
  // caller's assertion is about home, not about the tap landing.
  return waitForCheck(tester, home, seconds: 60);
}

/// Polls (real time) until [finder] is present. Fails if [seconds] pass.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  int seconds = 30,
}) async {
  for (var i = 0; i < seconds; i++) {
    await pumpReal(tester);
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for ${finder.toString()}');
}

/// Polls (real time) until [finder] is present, returning false instead of
/// failing when [seconds] pass. Used to retry flaky taps/navigation.
Future<bool> waitForCheck(
  WidgetTester tester,
  Finder finder, {
  int seconds = 30,
}) async {
  for (var i = 0; i < seconds; i++) {
    await pumpReal(tester);
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Polls (real time) until [finder] disappears (e.g. a modal sheet closes).
/// Fails if it is still present after [seconds] seconds.
Future<void> waitForGone(
  WidgetTester tester,
  Finder finder, {
  int seconds = 30,
}) async {
  for (var i = 0; i < seconds; i++) {
    await pumpReal(tester);
    if (finder.evaluate().isEmpty) return;
  }
  fail('Timed out waiting for ${finder.toString()} to disappear');
}

/// Polls (real time) until [finder] disappears, returning false instead of
/// failing when [seconds] pass. Used to retry flaky sheet closes/saves.
Future<bool> waitForGoneCheck(
  WidgetTester tester,
  Finder finder, {
  int seconds = 30,
}) async {
  for (var i = 0; i < seconds; i++) {
    await pumpReal(tester);
    if (finder.evaluate().isEmpty) return true;
  }
  return false;
}

/// Taps [tapTarget], then verifies [marker] appears. Retries the whole tap a
/// few times because on-device taps can silently miss while overlays (SnackBars,
/// the auto-hiding nav bar) are animating. Fails if [marker] never appears.
Future<void> tapUntilMarker(
  WidgetTester tester,
  Finder tapTarget,
  Finder marker, {
  int attempts = 3,
  int markerSeconds = 12,
  double tapMargin = 24,
}) async {
  for (var i = 0; i < attempts; i++) {
    await tapWhenVisible(tester, tapTarget, margin: tapMargin);
    await pumpAndSettleSafe(tester);
    await pumpReal(tester);
    if (await waitForCheck(tester, marker, seconds: markerSeconds)) {
      await pumpReal(tester);
      return;
    }
  }
  fail(
    'Timed out: ${tapTarget.toString()} did not reveal ${marker.toString()}',
  );
}

/// Bounded scroll: drags the on-screen (active) scrollable until [finder] is
/// actually on-screen. Uses `ensureVisible` (which reveals the target within
/// its ancestor scrollable) and falls back to manual drags FROM THE SCREEN
/// CENTER — not `Scrollable.first`, which can resolve to an inactive tab's
/// `IgnorePointer`-wrapped scrollable in the page stack. Returns true once
/// [finder] is visible on screen.
Future<bool> scrollUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Offset scrollOffset = const Offset(0, -250),
  int maxDrags = 20,
  double margin = 24,
}) async {
  bool onScreen() {
    if (finder.evaluate().isEmpty) return false;
    try {
      final rect = tester.getRect(finder.first);
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      return rect.center.dx >= margin &&
          rect.center.dx <= size.width - margin &&
          rect.center.dy >= margin &&
          rect.center.dy <= size.height - margin;
    } catch (_) {
      return false;
    }
  }

  Offset dragStart() {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    return Offset(size.width / 2, size.height / 2);
  }

  for (var i = 0; i < maxDrags; i++) {
    await pumpReal(tester);
    if (onScreen()) return true;
    try {
      await tester.ensureVisible(finder.first);
    } catch (_) {}
    await pumpReal(tester);
    if (onScreen()) return true;
    await tester.dragFrom(dragStart(), scrollOffset);
    await pumpReal(tester);
  }
  return onScreen();
}

/// Bounded tap: polls (real time) until [finder] is on-screen, scrolling with
/// manual drags even while the target is unbuilt (lazy sliver lists), then taps
/// it. Fails if [seconds] pass.
Future<void> tapWhenVisible(
  WidgetTester tester,
  Finder finder, {
  int seconds = 30,
  double margin = 24,
}) async {
  for (var i = 0; i < seconds; i++) {
    await pumpReal(tester);
    final scrolled = await scrollUntilVisible(
      tester,
      finder,
      maxDrags: 2,
      margin: margin,
    );
    if (!scrolled) continue;
    await pumpReal(tester);
    if (finder.evaluate().isEmpty) continue;
    try {
      final rect = tester.getRect(finder.first);
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final centerOnScreen =
          rect.center.dx >= margin &&
          rect.center.dx <= size.width - margin &&
          rect.center.dy >= margin &&
          rect.center.dy <= size.height - margin;
      if (!centerOnScreen) continue;
    } catch (_) {
      continue;
    }
    await tester.tap(finder.first, warnIfMissed: false);
    return;
  }
  fail('Timed out waiting for ${finder.toString()}');
}

/// Opens the home AppBar's ⋮ menu.
///
/// The five Pro shortcuts (recurring, lent money, forecast, goals, challenges)
/// used to be individual AppBar pills; they now live in this menu, because seven
/// 38 pt pills left the greeting about 28 pt of width on a 390 pt screen.
///
/// Returns false when the button is absent — an admin can hide all five, and the
/// `FeatureSection` wrapping it then removes the button entirely.
Future<bool> openHomeOverflow(WidgetTester tester) async {
  final button = find.byIcon(Icons.more_vert);
  if (!await isVisible(tester, button, seconds: 10)) return false;
  await tester.tap(button.first, warnIfMissed: false);
  await pumpAndSettleSafe(tester);
  await pumpReal(tester);
  return true;
}

/// Taps [icon] inside the home overflow menu, opening the menu first.
///
/// Returns false (and closes the menu) when the entry is absent, so a caller can
/// skip a feature an admin has hidden instead of hanging on an entry point the
/// kill-switch deliberately deleted.
Future<bool> tapHomeOverflowItem(WidgetTester tester, IconData icon) async {
  if (!await openHomeOverflow(tester)) return false;
  final item = find.byIcon(icon);
  if (item.evaluate().isEmpty) {
    // A corner tap lands on the popup route's modal barrier — never on a page
    // widget — so the menu cannot stay open and swallow the next tap.
    await tester.tapAt(const Offset(2, 2));
    await pumpAndSettleSafe(tester);
    await pumpReal(tester);
    return false;
  }
  await tester.tap(item.first, warnIfMissed: false);
  await pumpAndSettleSafe(tester);
  await pumpReal(tester);
  return true;
}

/// True when [finder] is present within [seconds] (real time), without failing.
///
/// Admin feature flags can set a surface to `hidden`, which removes its entry
/// point for everyone (a missing AppBar action, tab, or FAB). A test that
/// hard-requires such an entry point then hangs for its full timeout waiting for
/// UI the kill-switch deliberately deleted — which reads as a product failure
/// when the app is behaving exactly as documented. Use this to skip
/// flag-gated surfaces instead of asserting they must exist.
Future<bool> isVisible(
  WidgetTester tester,
  Finder finder, {
  int seconds = 8,
}) async {
  for (var i = 0; i < seconds; i++) {
    await pumpReal(tester);
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Long-presses [finder] and holds long enough for the LongPressGestureRecognizer
/// to fire, pumping REAL frames during the hold.
///
/// A hand-rolled `startGesture` + `Future.delayed(900ms)` + `up()` never pumps
/// between the down and the up, so the gesture arena may not process the held
/// pointer on a slow emulator and the long-press menu ('Delete Category',
/// 'Delete Goal?') never appears. This splits the hold into a few real-time
/// slices, each followed by a real frame.
Future<void> longPressItem(
  WidgetTester tester,
  Finder finder, {
  int holdMs = 1200,
}) async {
  await pumpReal(tester);
  await scrollUntilVisible(tester, finder, maxDrags: 3);
  await pumpReal(tester);
  final gesture = await tester.startGesture(
    tester.getCenter(finder.first),
  );
  // Hold in ~150ms slices, pumping a frame after each so the recognizer's timer
  // and the gesture arena advance on real elapsed time.
  final slices = (holdMs / 150).ceil();
  for (var i = 0; i < slices; i++) {
    await pumpReal(tester, const Duration(milliseconds: 150));
  }
  await gesture.up();
  await pumpAndSettleSafe(tester);
}

/// Returns true once the home screen ('Total Balance') is visible, polling up
/// to [seconds] seconds of real time.
Future<bool> waitForHome(WidgetTester tester, {int seconds = 120}) async {
  for (var i = 0; i < seconds; i++) {
    await pumpReal(tester);
    if (find.text(AppStrings.totalBalance).evaluate().isNotEmpty) return true;
  }
  return find.text(AppStrings.totalBalance).evaluate().isNotEmpty;
}

/// Which CI test account a file runs against. Free files exercise the paywall/
/// gates + free features; pro files exercise the Pro feature flows against a
/// genuinely-subscribed account (configured out-of-band in the Firebase
/// console). The two suites must never share an account.
enum TestAccount { free, pro }

/// Signs in with the test account when the login screen is showing. Returns
/// true if home was reached. Safe to call when already signed in (no-op).
/// Retries the sign-in a few times because the emulator's network to Firebase
/// can be slow/flaky.
Future<bool> loginIfNeeded(
  WidgetTester tester, {
  TestAccount account = TestAccount.free,
}) async {
  final email = account == TestAccount.pro ? kProTestEmail : kTestEmail;
  final password = account == TestAccount.pro ? kProTestPassword : kTestPassword;
  if (find.text(AppStrings.totalBalance).evaluate().isNotEmpty) return true;

  // The login screen can lag the splash walkthrough on slow boots — poll for
  // it rather than giving up on the first frame.
  for (var i = 0; i < 30; i++) {
    if (find.text(AppStrings.signIn).evaluate().isNotEmpty) break;
    await pumpReal(tester);
  }
  if (find.text(AppStrings.signIn).evaluate().isEmpty) return false;

  final emailField = find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        (w.decoration?.hintText?.toLowerCase().contains('email') ?? false),
  );
  final passwordField = find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        (w.decoration?.hintText?.toLowerCase().contains('password') ?? false),
  );
  if (emailField.evaluate().isEmpty || passwordField.evaluate().isEmpty) {
    return false;
  }

  final loginButton = find.text(AppStrings.signIn);
  for (var attempt = 0; attempt < 3; attempt++) {
    // The form can be torn down and rebuilt between the check above and here
    // (splash → login transition): enterText on a vanished field throws
    // "Bad state: No element" instead of retrying, which the nightly suite
    // reported as a login failure. Re-resolve every attempt.
    if (emailField.evaluate().isEmpty || passwordField.evaluate().isEmpty) {
      await pumpReal(tester);
      continue;
    }
    await tester.enterText(emailField, email);
    await pumpReal(tester);
    await tester.enterText(passwordField, password);
    await pumpReal(tester);

    // Dismiss the keyboard so the Sign In button is not covered on the
    // emulator.
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpReal(tester);

    await scrollUntilVisible(tester, loginButton);
    await pumpReal(tester);
    await tester.tap(loginButton, warnIfMissed: false);
    // A brand-new account lands on the post-login setup screen, not home —
    // finish it before waiting for 'Total Balance'.
    await completeOnboardingIfNeeded(tester, afterSignIn: true);
    final reached = await waitForHome(tester);
    if (reached) return true;
  }
  return false;
}

/// Makes the signed-in account's subscription state deterministic, so tests
/// never depend on out-of-band state drifting between runs.
///
/// - Free account: force-resets the doc to Free (subscriptionStatus:'free',
///   isPro:false, past-dated trialEndDate). All three fields are rule-legal
///   owner writes, and with the opt-in-trial change login never re-grants a
///   trial, so the account stays Free for the whole file. Fails loudly if the
///   account still reports Pro afterward.
/// - Pro account: verifies it is genuinely Pro (configured in the Firebase
///   console with subscriptionStatus:'pro' + far-future expiryDate) and fails
///   loudly with an actionable message if not — so a lapsed/misconfigured Pro
///   account can never silently skip the Pro feature flows.
Future<void> ensureAccountState(
  WidgetTester tester,
  TestAccount account,
) async {
  // Wipe any data this account accumulated in earlier files/runs (see
  // clearAccountData). The app is subscribed via streams, so home updates to a
  // clean slate before the test body starts.
  //
  // Off unless E2E_ALLOW_WIPE=true: the same call runs against the Pro account,
  // which holds real data. See clearAccountData.
  final currentEmail = FirebaseAuth.instance.currentUser?.email;
  if (currentEmail != null && kAllowAccountWipe) {
    await clearAccountData(currentEmail);
    await pumpReal(tester);
  }

  if (account == TestAccount.pro) {
    if (!(await probePro(tester))) {
      fail(
        'PRO_TEST_EMAIL ($kProTestEmail) does not report Pro. Configure it in '
        'the Firebase console: subscriptionStatus="pro" + a far-future '
        'expiryDate (and optionally isPro=true).',
      );
    }
    return;
  }

  final email = FirebaseAuth.instance.currentUser?.email;
  if (email != null) {
    await FirebaseFirestore.instance.collection('users').doc(email).set({
      'subscriptionStatus': 'free',
      'isPro': false,
      'trialEndDate': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    }, SetOptions(merge: true));
  }
  await pumpReal(tester);
  if (await probePro(tester)) {
    fail(
      'Free test account ($email) still reports Pro after the forced reset. '
      'trialEndDate/subscriptionStatus/isPro should all force Free.',
    );
  }
}

/// Ensures the signed-in account can open the Wealth tab.
///
/// The Wealth Builder is age-gated (`main_shell.dart` `_checkAgeGate`): with no
/// `age`/`dob` on the profile the tab tap shows the "Setup Required" dialog and
/// never switches, so every wealth file times out waiting for "Wealth Builder".
/// The CI fixtures predate that gate, and `clearAccountData` deliberately does
/// not touch the profile — so the harness seeds it once per launch instead of
/// depending on out-of-band account state.
Future<void> ensureProfileAge(WidgetTester tester) async {
  final email = FirebaseAuth.instance.currentUser?.email;
  if (email == null) return;
  try {
    final doc = FirebaseFirestore.instance.collection('users').doc(email);
    final data = (await doc.get()).data();
    final age = data?['age'];
    if (age is num && age > 0) return;
    if (data?['dob'] != null) return; // the gate derives an age from it
    // Rule-legal owner write: isOwnerUpdate has no field allow-list and age is
    // not an entitlement field.
    await doc.set({'age': 30}, SetOptions(merge: true));
    debugPrint('ensureProfileAge: seeded age=30 for $email');
    await pumpReal(tester);
  } catch (e) {
    debugPrint('ensureProfileAge error: $e');
  }
}

/// Launches the app and brings it to the home screen, tapping through splash/
/// onboarding and signing in when needed. Fails the test if home is not
/// reached (so failures point at login/onboarding, not later finders).
Future<void> launchAndSignIn(
  WidgetTester tester, {
  TestAccount account = TestAccount.free,
}) async {
  // Data hygiene: wipe whatever the previous file/run left behind so the app
  // never renders the accumulated backlog (the free 150-txn cap + stale wealth
  // entries made the suite flaky and could stall the app before the harness
  // connected). Runs before mainCommon so the app never sees the backlog.
  await resetTestData();
  await app.mainCommon(isTest: true);
  // Account isolation: the app persists the last session across files
  // (--no-uninstall), so if the previous file signed in as a different
  // account, sign out first so this file uses its own account.
  final expected = account == TestAccount.pro ? kProTestEmail : kTestEmail;
  final current = FirebaseAuth.instance.currentUser?.email;
  if (current != null && current != expected) {
    await FirebaseAuth.instance.signOut();
    await pumpAndSettleSafe(tester, timeout: const Duration(seconds: 5));
  }
  await pumpAndSettleSafe(tester, timeout: const Duration(seconds: 5));
  // The CI emulator's software GL stack (swiftshader) segfaults after ~2m of
  // the AI Insights screen's heavy blurred cards. Force lite mode for every
  // integration run so heavy blur shadows/confetti are skipped app-wide
  // (analysis.dart gates its card shadows on liteMode).
  if (Get.isRegistered<PerformanceController>()) {
    await PerformanceController.to.setLiteMode(true);
  }
  await handleSplashAndOnboarding(tester);
  await pumpAndSettleSafe(tester);
  // A session restored from a previous file can already be parked on the
  // post-login setup screen (that file failed before finishing it).
  await completeOnboardingIfNeeded(tester);
  await loginIfNeeded(tester, account: account);
  final reachedHome = await waitForHome(tester);
  if (!reachedHome) {
    final user = FirebaseAuth.instance.currentUser;
    fail(
      'Home screen (Total Balance) was not reached. '
      'auth=${user?.email} verified=${user?.emailVerified} '
      'uid=${user?.uid}',
    );
  }
  await ensureAccountState(tester, account);
  await ensureProfileAge(tester);
}

/// Deletes every doc in `users/{email}/{path}` (owner delete is allowed by
/// firestore.rules). Errors are swallowed so a cleanup failure never masks the
/// real test result.
Future<void> _clearSubcollection(String email, String path) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection(path)
        .get();
    if (snap.docs.isEmpty) return;
    for (var i = 0; i < snap.docs.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs.skip(i).take(400)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  } catch (e) {
    debugPrint('clearAccountData($path) error: $e');
  }
}

/// Whether [clearAccountData] is allowed to run at all.
///
/// This is **opt-in and defaults to off** because the wipe is irreversible and
/// the suite also runs against the *Pro* account, which is a real, hand-curated
/// account rather than a disposable fixture. An implicit wipe on every
/// `launchAndSignIn` once destroyed 34 subcollections (791 transactions) on a
/// live account with no way to restore them — Firestore has no client-side
/// backup, and the on-device cache prunes server-deleted documents to
/// path-only stubs.
///
/// Set `--dart-define=E2E_ALLOW_WIPE=true` (CI does, against its disposable
/// accounts) to enable the historical wipe-and-reset behaviour.
const bool kAllowAccountWipe =
    bool.fromEnvironment('E2E_ALLOW_WIPE', defaultValue: false);

/// Wipes all test data for [email]: transactions (the free 150-txn/month cap
/// makes accumulated data a hard blocker) plus the wealth + feature
/// subcollections so a crashed earlier run can never skew later files.
///
/// **Irreversible.** No-ops unless `E2E_ALLOW_WIPE=true` is passed, so a normal
/// test launch can never destroy a real account's data by accident.
Future<void> clearAccountData(String email) async {
  if (!kAllowAccountWipe) {
    debugPrint(
      'clearAccountData($email): SKIPPED (wipe not enabled). Pass '
      '--dart-define=E2E_ALLOW_WIPE=true to enable — it permanently deletes '
      'transactions, categories, budgets, goals, loans, recurring_payments, '
      'lent_money, challenges and all 26 wealth subcollections.',
    );
    return;
  }
  for (final path in _dataSubcollections) {
    await _clearSubcollection(email, path);
  }
  for (final path in _wealthSubcollections) {
    await _clearSubcollection(email, path);
  }
}

/// Fields a profile-editing test mutates on the `users/{email}` document, and
/// the values `clearAccountData` does NOT touch (it clears subcollections only).
const _mutableProfileFields = [
  'firstName',
  'lastName',
  'phone',
  'address',
  'gender',
  'dob',
  'age',
];

/// Snapshots the mutable profile fields of the signed-in user so a test can
/// restore them in a `finally`. The profile doc is shared state: without this a
/// test that renames the user to "UpdatedName" leaks that name into every later
/// file/run (and into the account) because `clearAccountData` never resets it.
Future<Map<String, dynamic>> snapshotUserProfile() async {
  final email = FirebaseAuth.instance.currentUser?.email;
  if (email == null) return {};
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .get();
    final data = doc.data() ?? const {};
    return {
      for (final k in _mutableProfileFields)
        if (data.containsKey(k)) k: data[k],
    };
  } catch (e) {
    debugPrint('snapshotUserProfile error: $e');
    return {};
  }
}

/// Restores fields captured by [snapshotUserProfile] (best-effort, never
/// throws — a cleanup failure must not mask the test's real result).
Future<void> restoreUserProfile(Map<String, dynamic> snapshot) async {
  final email = FirebaseAuth.instance.currentUser?.email;
  if (email == null) return;
  try {
    final doc = FirebaseFirestore.instance.collection('users').doc(email);
    if (snapshot.isEmpty) {
      // Nothing was set before the test ran: remove the fields it created.
      await doc.update({
        for (final k in _mutableProfileFields) k: FieldValue.delete(),
      });
    } else {
      await doc.set(snapshot, SetOptions(merge: true));
    }
  } catch (e) {
    debugPrint('restoreUserProfile error: $e');
  }
}

/// Ensures the current user has at least one category. `clearAccountData()`
/// wipes the `categories` collection, and screens that build their UI off it
/// (e.g. Category Budgets renders one card per category) would show nothing.
/// Idempotent — seed before navigating to any category-driven screen.
Future<void> seedCategory({
  required String name,
  String? icon,
  int? iconCode,
  int? color,
}) async {
  final email = FirebaseAuth.instance.currentUser?.email;
  if (email == null) return;
  await FirebaseFirestore.instance
      .collection('users')
      .doc(email)
      .collection('categories')
      .doc(name)
      .set({
    'name': name,
    'icon': icon,
    'iconCode': iconCode,
    'color': color,
  });
}

/// Cleans the account whose session persisted on the device from the previous
/// file/run, BEFORE the app launches. Each file launches the app afresh
/// (--no-uninstall), so the app would otherwise render the whole accumulated
/// backlog at startup — the free account's ~150 transactions made the first
/// render slow and (on the pro account) could stall the app before the test
/// harness ever connected.
Future<void> resetTestData() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  // The persisted session restores asynchronously after Firebase init — poll
  // currentUser for a short window. If no session restores, nothing to clean.
  User? restored;
  for (var i = 0; i < 15 && restored == null; i++) {
    restored = FirebaseAuth.instance.currentUser;
    if (restored == null) {
      await Future.delayed(const Duration(seconds: 1));
    }
  }
  final email = restored?.email;
  if (email != null) {
    await clearAccountData(email);
  }
}

/// Waits until [GetX] controller is registered, so tests can safely
/// `Get.find<T>()` after login regardless of Phase-2 registration timing.
///
/// Fails (rather than silently continuing) if the controller never registers:
/// a silent return would let the very next `Get.find<T>()` throw deep inside a
/// widget build, with no indication that the real problem was a missing
/// registration.
Future<void> waitForController(
  WidgetTester tester,
  bool Function() isRegistered, {
  int seconds = 30,
  String? reason,
}) async {
  for (var i = 0; i < seconds; i++) {
    await pumpReal(tester);
    if (isRegistered()) return;
  }
  fail(
    'Timed out after ${seconds}s waiting for a GetX controller to register'
    '${reason == null ? '' : ' ($reason)'}.',
  );
}

/// On the Payment screen, ensures a category chip exists, adding it through the
/// "Add" dialog when missing.
Future<void> ensureCategoryExists(
  WidgetTester tester,
  String categoryName,
) async {
  await pumpAndSettleSafe(tester);
  if (find.text(categoryName).evaluate().isNotEmpty) return;

  await tester.tap(find.text(AppStrings.add));
  await pumpAndSettleSafe(tester);

  final newCatField = find.byType(TextField).last;
  await tester.enterText(newCatField, categoryName);
  await pumpAndSettleSafe(tester);

  final dialogAddButton = find.descendant(
    of: find.byType(Dialog),
    matching: find.text(AppStrings.add),
  );
  await tester.tap(dialogAddButton);
  await pumpAndSettleSafe(tester);

  // If the dialog is still open (e.g. async category write), retry once.
  if (find.byType(Dialog).evaluate().isNotEmpty) {
    await tester.tap(dialogAddButton);
    await pumpAndSettleSafe(tester);
  }
}

/// From the home screen, creates an expense ([receive] == false) or income
/// ([receive] == true) transaction through the UI, returning to the home screen.
Future<void> createTransaction(
  WidgetTester tester, {
  required bool receive,
  required String name,
  required String amount,
  String category = 'Food',
}) async {
  final submitFinder = find.text(receive ? AppStrings.receiveCta : AppStrings.sendCta);

  // Tap the Send/Receive quick action on the home balance card.
  final toggle = find.text(receive ? AppStrings.receive : AppStrings.send).last;
  for (var i = 0; i < 30; i++) {
    await pumpReal(tester);
    if (toggle.evaluate().isNotEmpty) break;
  }
  await tester.ensureVisible(toggle);
  await pumpAndSettleSafe(tester);
  await tester.tap(toggle, warnIfMissed: false);
  await pumpAndSettleSafe(tester);

  // Wait for the payment screen to actually open before filling the form.
  for (var i = 0; i < 30; i++) {
    await pumpReal(tester);
    if (submitFinder.evaluate().isNotEmpty) break;
  }
  if (submitFinder.evaluate().isEmpty) {
    fail('Payment screen did not open for ${receive ? AppStrings.receive : AppStrings.send}');
  }

  await ensureCategoryExists(tester, category);

  // Select the category chip.
  final categoryChip = find.text(category).last;
  await tester.ensureVisible(categoryChip);
  await pumpAndSettleSafe(tester);
  await tester.tap(categoryChip);
  await pumpAndSettleSafe(tester);

  // Amount field (hint '0.00') then Sender/Recipient field (hint 'Enter name').
  await tester.enterText(find.widgetWithText(TextField, '0.00'), amount);
  await pumpAndSettleSafe(tester);
  await tester.enterText(find.widgetWithText(TextField, 'Enter name'), name);
  await pumpAndSettleSafe(tester);

  FocusManager.instance.primaryFocus?.unfocus();
  await pumpAndSettleSafe(tester);

  final submit = submitFinder.last;
  await tester.ensureVisible(submit);
  await pumpAndSettleSafe(tester);
  await tester.tap(submit);
  await pumpAndSettleSafe(tester);

  // Wait for the payment screen to actually pop. The save triggers a confetti
  // celebration (~700 ms) before Navigator.pop, so the screen lingers even
  // though 'Total Balance' is already present in the offstage home route below.
  for (var i = 0; i < 90; i++) {
    await pumpReal(tester);
    if (submitFinder.evaluate().isEmpty) break;
  }
  if (submitFinder.evaluate().isNotEmpty) {
    fail('Payment screen did not close after submitting transaction');
  }
  await waitForHome(tester);
}

/// From the home screen, creates a receive transaction through the UI.
Future<void> createReceiveTransaction(
  WidgetTester tester, {
  required String name,
  required String amount,
  String category = 'Salary',
}) async {
  await createTransaction(
    tester,
    receive: true,
    name: name,
    amount: amount,
    category: category,
  );
}

/// Unique-ish name so repeated runs against the shared account don't collide
/// with data left behind by earlier runs.
String uniqueName(String prefix) =>
    '${prefix}_${DateTime.now().millisecondsSinceEpoch % 100000}';

bool _isHomeVisible(WidgetTester tester) =>
    find.text(AppStrings.totalBalance).evaluate().isNotEmpty &&
    find.byIcon(Icons.search).evaluate().isNotEmpty;

/// Determines Pro status from the home AppBar badge (cyan verified badge =
/// Pro/trial, diamond = free). Polls until the badge renders.
Future<bool> probePro(WidgetTester tester, {int seconds = 40}) async {
  for (var i = 0; i < seconds; i++) {
    await pumpReal(tester);
    if (find.byIcon(Icons.verified_user_rounded).evaluate().isNotEmpty) {
      return true;
    }
    if (find.byIcon(Icons.diamond_outlined).evaluate().isNotEmpty) {
      return false;
    }
  }
  fail('Could not determine Pro status from the home AppBar badge');
}

/// Asserts the SubscriptionScreen upgrade gate is showing (plan cards visible)
/// and closes it back to the home screen.
Future<void> assertUpgradeScreen(WidgetTester tester) async {
  await waitFor(tester, find.text(AppStrings.monthly));
  expect(find.text(AppStrings.monthly), findsWidgets);
  expect(find.text(AppStrings.yearly), findsWidgets);
  await tapWhenVisible(tester, find.byIcon(Icons.close));
  await pumpAndSettleSafe(tester);
  await waitForHome(tester);
}

/// The nav bar's icon, scoped so a page-level icon with the same [icon] (e.g.
/// the Wealth and Settings pages both contain a tune icon) can never shadow the
/// real tab. Falls back to the unscoped finder on tablet (nav rail) layouts.
Finder _navBarIcon(WidgetTester tester, IconData icon) {
  if (find.byType(BottomNavBar).evaluate().isNotEmpty) {
    return find.descendant(
      of: find.byType(BottomNavBar),
      matching: find.byIcon(icon),
    );
  }
  return find.byIcon(icon);
}

/// True when [finder] matches a widget rendered on the actual page (above the
/// bottom nav pill). Rejects matches that only exist as the always-visible
/// bottom-nav labels (e.g. 'Settings'), which are present even when the target
/// tab was never activated.
bool _markerOnPage(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return false;
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final e in finder.evaluate()) {
    try {
      final box = e.renderObject;
      if (box is! RenderBox || !box.attached) continue;
      final topLeft = box.localToGlobal(Offset.zero);
      final centerY = topLeft.dy + box.size.height / 2;
      if (centerY < size.height - 100) return true;
    } catch (_) {}
  }
  return false;
}

/// Dismisses modal overlays that would otherwise swallow taps. The main one is
/// the Wealth "Smart Wealth Builder" age prompt: selecting the Settings tab
/// eagerly builds every intermediate page — including the Wealth page, whose
/// load completes and pushes this non-dismissible dialog. Tapping "Show All
/// Cards" keeps every card visible and marks the prompt as shown (device
/// SharedPreferences), so it never reappears for the rest of the session.
/// Other Dialog/AlertDialog/BottomSheet/SnackBar overlays are dismissed via a
/// top-left barrier tap.
Future<void> dismissDialogs(WidgetTester tester, {int seconds = 8}) async {
  for (var i = 0; i < seconds * 4; i++) {
    if (find.text(AppStrings.showAllCards).evaluate().isNotEmpty) {
      await tester.tap(find.text(AppStrings.showAllCards), warnIfMissed: false);
      await pumpAndSettleSafe(tester);
      await pumpReal(tester);
      continue;
    }
    if (find.byType(Dialog).evaluate().isNotEmpty ||
        find.byType(AlertDialog).evaluate().isNotEmpty ||
        find.byType(BottomSheet).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(10, 10));
      await pumpAndSettleSafe(tester);
      await pumpReal(tester);
      continue;
    }
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(10, 10));
      await pumpAndSettleSafe(tester);
      await pumpReal(tester);
      continue;
    }
    await pumpReal(tester, const Duration(milliseconds: 250));
  }
}

/// Re-shows the auto-hiding bottom nav bar. Analytics/Insights/Wealth/Settings
/// slide it off-screen (AnimatedSlide) after a scroll-down; this drags the
/// content back up until [navIcon] is on-screen again.
Future<void> revealBottomNav(WidgetTester tester, IconData navIcon) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  const margin = 40.0;
  final scoped = _navBarIcon(tester, navIcon);
  for (var i = 0; i < 5; i++) {
    await pumpReal(tester);
    if (scoped.evaluate().isNotEmpty) {
      try {
        final rect = tester.getRect(scoped.first);
        if (rect.center.dy <= size.height - margin) return;
      } catch (_) {}
    }
    await tester.dragFrom(
      Offset(size.width / 2, size.height / 2),
      const Offset(0, 300),
    );
    await pumpAndSettleSafe(tester);
  }
}

/// Taps a bottom-navigation tab (by its unique nav icon) and waits for a
/// marker that only exists on the target tab. Retries the reveal + tap because
/// the auto-hiding nav bar's AnimatedSlide can leave the icon mid-animation
/// where a tap silently misses (warnIfMissed: false). Dismisses any modal that
/// a just-built page pushed (the Wealth prompt fires whenever the Wealth page
/// is first built, which also happens when jumping straight to Settings).
/// The marker is only accepted when it renders on the page itself — never the
/// always-visible bottom-nav label.
Future<void> tapNavTab(
  WidgetTester tester,
  IconData icon,
  String marker,
) async {
  final navIcon = _navBarIcon(tester, icon);
  final markerFinder = find.text(marker);
  for (var attempt = 0; attempt < 3; attempt++) {
    await dismissDialogs(tester);
    await revealBottomNav(tester, icon);
    await tapWhenVisible(tester, navIcon);
    await pumpAndSettleSafe(tester);
    await pumpReal(tester);
    if (await waitForCheck(tester, markerFinder, seconds: 12) &&
        _markerOnPage(tester, markerFinder)) {
      await dismissDialogs(tester);
      await pumpReal(tester);
      return;
    }
  }
  fail('Timed out waiting for "$marker" after tapping nav tab $icon');
}

/// Pops pushed routes until the home screen is visible. Handles the standard
/// back arrows, BackButton, and the SubscriptionScreen close button.
Future<void> backToHome(WidgetTester tester, {int maxBacks = 8}) async {
  for (var i = 0; i < maxBacks; i++) {
    await pumpReal(tester);
    if (_isHomeVisible(tester)) return;
    Finder back = find.byType(BackButton);
    if (back.evaluate().isEmpty) {
      back = find.byIcon(Icons.arrow_back_ios_new_rounded);
    }
    if (back.evaluate().isEmpty) {
      back = find.byIcon(Icons.arrow_back_ios_new);
    }
    if (back.evaluate().isEmpty) {
      back = find.byIcon(Icons.arrow_back);
    }
    if (back.evaluate().isEmpty) {
      back = find.byIcon(Icons.close);
    }
    if (back.evaluate().isEmpty) {
      await pumpReal(tester, const Duration(seconds: 2));
      continue;
    }
    await tester.tap(back.first, warnIfMissed: false);
    await pumpAndSettleSafe(tester);
  }
  fail('Could not return to the home screen');
}

/// Pops a single pushed route (any common back button). No-op if none found.
Future<void> popScreen(WidgetTester tester) async {
  await pumpReal(tester);
  Finder back = find.byType(BackButton);
  if (back.evaluate().isEmpty) {
    back = find.byIcon(Icons.arrow_back_ios_new_rounded);
  }
  if (back.evaluate().isEmpty) {
    back = find.byIcon(Icons.arrow_back_ios_new);
  }
  if (back.evaluate().isEmpty) {
    back = find.byIcon(Icons.arrow_back_ios);
  }
  if (back.evaluate().isEmpty) {
    back = find.byIcon(Icons.arrow_back);
  }
  if (back.evaluate().isEmpty) {
    back = find.byIcon(Icons.close);
  }
  if (back.evaluate().isEmpty) {
    await pumpReal(tester, const Duration(seconds: 2));
    return;
  }
  await tester.tap(back.first, warnIfMissed: false);
  await pumpAndSettleSafe(tester);
}

/// Pulls to refresh the current screen's RefreshIndicator.
Future<void> dragToRefresh(WidgetTester tester) async {
  final ri = find.byType(RefreshIndicator);
  if (ri.evaluate().isNotEmpty) {
    await tester.drag(ri.first, const Offset(0, 300), warnIfMissed: false);
    await pumpReal(tester, const Duration(seconds: 3));
  }
}

/// Swipes a slidable list item left (or right) to reveal its action buttons
/// and taps the action with [actionLabel].
Future<void> swipeAndTap(
  WidgetTester tester,
  String itemText,
  String actionLabel, {
  bool swipeLeft = true,
}) async {
  final item = find.text(itemText).first;
  await scrollUntilVisible(tester, item);
  await pumpReal(tester);
  await tester.drag(
    item,
    Offset(swipeLeft ? -300 : 300, 0),
    warnIfMissed: false,
  );
  await pumpAndSettleSafe(tester);
  await tapWhenVisible(tester, find.text(actionLabel));
  await pumpAndSettleSafe(tester);
}

/// Swipes a list item to reveal its Delete action and confirms the resulting
/// "Delete" confirmation dialog.
Future<void> swipeAndConfirmDelete(WidgetTester tester, String itemText) async {
  await swipeAndTap(tester, itemText, 'Delete');
  await pumpAndSettleSafe(tester);
  final dlg = find.byType(AlertDialog);
  if (dlg.evaluate().isNotEmpty) {
    final del = find.descendant(
      of: dlg,
      matching: find.widgetWithText(TextButton, 'Delete'),
    );
    if (del.evaluate().isNotEmpty) {
      await tapWhenVisible(tester, del);
      await pumpAndSettleSafe(tester);
    }
  }
  await pumpReal(tester, const Duration(seconds: 3));
}

/// Taps the delete-outline icon (entry cards / transaction details) and
/// confirms any delete AlertDialog that appears.
Future<void> deleteCurrentEntry(WidgetTester tester) async {
  await tapWhenVisible(tester, find.byIcon(Icons.delete_outline));
  await pumpAndSettleSafe(tester);
  final dlg = find.byType(AlertDialog);
  if (dlg.evaluate().isNotEmpty) {
    final del = find.descendant(
      of: dlg,
      matching: find.widgetWithText(TextButton, 'Delete'),
    );
    if (del.evaluate().isNotEmpty) {
      await tapWhenVisible(tester, del);
      await pumpAndSettleSafe(tester);
    }
  }
  await pumpReal(tester, const Duration(seconds: 3));
}

/// Fills a labeled text field inside the currently-open add/edit bottom sheet.
Future<void> fillAssetField(
  WidgetTester tester,
  String label,
  String value,
) async {
  await scrollUntilVisible(tester, find.widgetWithText(TextField, label));
  await pumpReal(tester);
  await tester.enterText(find.widgetWithText(TextField, label), value);
  await pumpReal(tester);
}

/// Fills an asset sheet's required fields, saves it, and waits for the sheet
/// to close. [fieldValues] maps each sheet field label to its input.
Future<void> createAssetEntry(
  WidgetTester tester, {
  required String sheetTitle,
  required Map<String, String> fieldValues,
}) async {
  await waitFor(tester, find.text(sheetTitle));
  for (final e in fieldValues.entries) {
    await fillAssetField(tester, e.key, e.value);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpReal(tester);
  await tapWhenVisible(tester, find.text(AppStrings.save));
  await pumpAndSettleSafe(tester);
  await pumpReal(tester, const Duration(seconds: 3));
}

/// Full add-verify-delete round trip for a generic AssetDetailScreen entry:
/// scrolls to the asset card, opens its detail screen, adds an entry through
/// the sheet, waits for the "1 item" count (the reliable creation marker),
/// deletes it via the delete icon + confirm dialog, waits for the empty state,
/// and pops back to the wealth grid.
Future<void> sweepAssetEntry(
  WidgetTester tester, {
  required String cardTitle,
  required String addLabel,
  required Map<String, String> fieldValues,
  required String emptyMessage,
}) async {
  await scrollUntilVisible(tester, find.text(cardTitle));
  await pumpReal(tester);
  await tapUntilMarker(tester, find.text(cardTitle), find.text(addLabel));
  await tapWhenVisible(tester, find.text(addLabel));
  await createAssetEntry(
    tester,
    sheetTitle: addLabel,
    fieldValues: fieldValues,
  );
  await waitFor(tester, find.text('1 item'));
  expect(find.text('1 item'), findsWidgets);
  await deleteCurrentEntry(tester);
  await waitFor(tester, find.text(emptyMessage));
  await popScreen(tester);
}
