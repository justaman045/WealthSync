# AGENTS.md

Critical rules and conventions for this Flutter + GetX + Firebase project.

## CRITICAL PATTERNS

### GetX Controller Access — Never Field Initializers

```dart
// WRONG — crashes (controllers not yet registered)
final _controller = Get.find<TransactionController>();

// CORRECT — guard + defer
late final TransactionController _controller;
@override
void initState() {
  super.initState();
  if (!Get.isRegistered<TransactionController>()) Get.put(TransactionController());
  _controller = Get.find<TransactionController>();
}
```

Applies to every widget using `Get.find<>()`.

### Dispose TextEditingControllers in Dialogs/Sheets

```dart
// showDialog — try/finally
final ctrl = TextEditingController();
try { await showDialog(...); } finally { ctrl.dispose(); }

// showModalBottomSheet — .whenComplete()
showModalBottomSheet(...).whenComplete(() => ctrl.dispose());
```

Multiple controllers in a sheet → `StatefulWidget` owning controllers in `initState`/`dispose` (see `_AddSheet` in `asset_detail_screen.dart`).

### mounted Check After async

```dart
await someAsyncOp();
if (!mounted) return;
setState(() { ... });
```

### Global Dialogs — Use Get.overlayContext

```dart
showGeneralDialog(context: Get.overlayContext!, ...);
// NOT: Get.context!
```

## Commands

```bash
flutter pub get
flutter analyze --no-fatal-infos   # CI gate (warnings→errors, infos OK)
flutter test                        # unit/widget tests ONLY (test/) — never integration tests
flutter test test/<file>_test.dart  # single file
flutter run
flutter build apk --release
flutter build appbundle --release
flutter build web --release --base-href /WealthSync/   # GitHub Pages deploy
flutter gen-l10n                    # after editing ARB files in lib/l10n/ (l10n.yaml + generate: true)
tool/check_ui_strings.sh            # UI-revamp audit: report only
tool/check_ui_strings.sh --strict   # fail if mechanical debts exceed caps
```

**Integration tests never run under plain `flutter test`** — they only run when explicitly invoked. Manual local run (emulator-5554, live Firebase account):

```bash
# Credentials come from CI secrets; paste as --dart-define for local runs.
# CI instead runs tool/run_integration_tests.sh: loops files one by one
# (15m timeout each), restarts the emulator before every file after the first
# (gotcha #9), recovers/retries on adb wedges, pulls screenshots incrementally
# into build/report/parts + build/report/screenshots. Editing that script?
# It runs under `set -e` — capture run_file exit codes with `cmd || RC=$?`,
# NEVER a bare `cmd` + `RC=$?` line (a failing bare call kills the recovery path).
flutter test integration_test -d emulator-5554 --no-uninstall \
  --dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=... \
  --dart-define=PRO_TEST_EMAIL=... --dart-define=PRO_TEST_PASSWORD=... \
  --file-reporter json:build/report/integration.json
mkdir -p build/report/screenshots
adb shell run-as app.vercel.justaman045.money_control ls -1 cache/screenshots 2>/dev/null | while read f; do
  adb exec-out run-as app.vercel.justaman045.money_control cat "cache/screenshots/$f" > "build/report/screenshots/$f"
done
# --integration accepts a single file or a comma-separated list (one per
# `flutter test` invocation); each file is parsed independently.
dart run tool/generate_test_report.dart --unit=build/report/unit.json \
  --integration=build/report/integration.json \
  --screenshots=build/report/screenshots --out=build/report/report.html
```

CI (`.github/workflows/flutter_build.yml`, Flutter 3.44.8): analyze → unit/widget test → build (`test` job). Integration (E2E) tests are **skipped by default in CI** — the `integration_test` job only runs on a manual `workflow_dispatch` fired with the `run_integration_tests` input set to `true` (Android emulator, live Firebase test accounts via `TEST_EMAIL`/`TEST_PASSWORD` (free) + `PRO_TEST_EMAIL`/`PRO_TEST_PASSWORD` (Pro) secrets); on normal master pushes/manual runs it stays skipped and `build`/`build_web` ship on analyze + unit tests alone. When an opt-in E2E run happens it still **gates**: `build`/`build_web` use an explicit status guard (`needs.integration_test.result` success-or-skipped), so a failing E2E opt-in run blocks the release while a skipped one proceeds. Re-enabling the hard master-push E2E gate later = drop the job's `if` condition (tooling + secrets fully intact). Integration tests and release builds never run on PRs (E2E mutates the shared test accounts), so a green PR check means analyze + unit tests only. On merge to `master`, CI auto-bumps `pubspec.yaml` to `2.0.<run_number>`, updates `app_version.json` + README download link, creates a signed GitHub release (`v2.0.<run_number>`), and deploys web to GitHub Pages under base-href `/WealthSync/`. Version-commit/README-commit loops are avoided by skipping the commit when the message starts with `CI:`. Every run uploads a self-contained `report.html` artifact (pass/fail per test, collapsible errors, base64 screenshots) — generated even on red runs.

## Architecture

**MVC-Service-Repository** with GetX. Package name is `money_control` (used in imports).

| Directory | Role |
|-----------|------|
| `lib/Models/` | Data classes with `fromMap`/`toMap` |
| `lib/Repositories/` | Firestore data access only |
| `lib/Services/` | Business logic (not controllers) |
| `lib/Controllers/` | GetX controllers binding services to reactive state |
| `lib/Screens/` | Widgets only; no logic |
| `lib/Components/` | Reusable widgets |
| `lib/Config/` | `AssetScreenConfig` definitions |
| `lib/Utils/` | `IconHelper`, `wealth_math.dart` |
| `lib/Platform/` | Platform abstraction stubs for 9 services (biometric, geocoding, IAP, notification, SMS, etc.) |
| `lib/l10n/` | ARB localization files (`app_en.arb` template) |
| `lib/data/` | Challenge preset seed data |
| `test/` | 16 unit/widget test files (background_flags, bottom_nav_layout, feature_flags, feature_flags_widget, feature_gate, inactivity_reminder, lent_money_model, recurring_payment_model, sms_auto_import, sms_category, toggle_gate, upi_apps, upi_qr, wealth_data, wealth_math, widget) |
| `integration_test/` | 25 integration tests — require a live Firebase backend and run against emulator-5554 with the four account dart-defines (see `test_credentials.dart`). `mainCommon(isTest: true)` only skips Crashlytics/notifications. Tests: add_transaction, ai_insights, analytics_reports, budget_categories (Pro), data_management, edit_profile, free_paywall_gates (free), full_app_e2e_tabs (login→home→tab-tour smoke; subsumes the old app_test), goals_challenges (Pro), lent_money_split_bill (Pro), loan_tracker, login, login_valid, misc_settings, pro_features (Pro), receive_transaction_e2e, search_transaction, settings (free), subscription_flow (Pro), subscription_screen (Pro), transaction_management, wealth_assets, wealth_sweep_1/2/3. Helpers in `test_helpers.dart`: `launchAndSignIn` (with `account: TestAccount.free|pro`), `tapNavTab` (auto-reveals the auto-hiding bottom bar), `handleSplashAndOnboarding`, `loginIfNeeded`, `createTransaction`, `waitForHome`, `waitForGone`, `ensureAccountState`, `sweepAssetEntry`. |

## Integration Test Gotchas

1. **Tests need the dart-defines** — `flutter test integration_test -d emulator-5554 --dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=... --dart-define=PRO_TEST_EMAIL=... --dart-define=PRO_TEST_PASSWORD=...` or auth fails with `[firebase_auth/channel-error]` ("Given String is empty or null"). `test_credentials.dart` uses `String.fromEnvironment` with empty defaults on purpose.
2. **Two accounts, never shared** — `TEST_EMAIL`/`TEST_PASSWORD` is the FREE account; `PRO_TEST_EMAIL`/`PRO_TEST_PASSWORD` is the PRO account. `ensureAccountState()` force-resets the free account to Free on every launch (subscriptionStatus:'free', isPro:false, past-dated trialEndDate — all rule-legal owner writes, and with the opt-in-trial change login never re-grants a trial), and fails loudly if the Pro account doesn't report Pro (configure it in the Firebase console: subscriptionStatus:'pro' + a far-future expiryDate — the app cannot self-grant Pro). Free-path assertions (`'Budgeting'`, `'Upgrade to Pro'`, `'Monthly'`) only work against the free account. A subscribed-Pro account shows the subscription management view (`'You are a Pro Member!'`, `'Renews on:'`) — NOT the paywall/trial banner, so `subscription_screen_test` asserts accordingly and never taps "Cancel Plan".
3. **`createTransaction` waits for the payment screen to open AND pop** — after submit the screen lingers ~700 ms for the confetti celebration before `Navigator.pop`, and 'Total Balance' is already present in the offstage home route below, so `waitForHome` alone races into the next tap.
4. **Decorative blobs must not block taps** — the balance-card gradient circles are wrapped in `IgnorePointer`; they overlap the Send/Receive buttons once the streak banner grows the card (`balance_card.dart`).
5. **`_InviteFriendsCard` listener needs an `onError`** — the `users/{email}` snapshots stream errors with permission-denied after sign-out; without the handler the settings sign-out test fails on an unhandled exception (`settings.dart`).
6. **Data-dependent analytics markers** — 'Monthly Trend' only renders with ≥2 months of data ('Current Period' otherwise), and 'Expense Breakdown' needs non-zero expenses. `analytics_reports_test.dart` seeds an expense + income first and accepts either trend title.
7. **`flutter test` uninstalls the app after integration runs** — the `--uninstall` flag defaults to true (Flutter tool), wiping the device cache that holds the screenshots. Always pass `--no-uninstall` (CI does) so the `adb exec-out run-as ... cat` pull after the run finds them. Per-file reinstalls use `adb install -r`, so screenshots accumulate across test files while the app stays installed.
8. **`testWidgetsWithScreenshots` auto-captures screenshots** — every integration test uses the wrapper in `test_helpers.dart`; on success it writes `result_<name>.png` to `<app cache>/screenshots/`, on failure `failure_<name>.png` (error is rethrown so the test still fails). Capture is engine-first (`layer.toImage()` — no `convertFlutterSurfaceToImage()` surface swap, which is what stresses the emulator's fragile gfxstream ColorBuffer path); it falls back to `binding.takeScreenshot()` only if the engine path yields nothing. `tool/generate_test_report.dart` embeds them base64 into the single-file `report.html`; new integration tests must keep using the wrapper so their screenshots land in the report. FAIL rows with no error text are labeled **HOST LOST** — the emulator/adb connection dropped mid-test (an infra failure, never a test assertion).
9. **Emulator dies from host-GL accumulation across app launches — restart between files** — `analytics_insights_test` deterministically killed the emulator process (qemu gone; `adb -s emulator-5554 emu kill` at job end failed with `Connection refused` on TCP 5554) after ~7 min in three consecutive runs. The death is tied to the SECOND app launch: `add_transaction_test` (first file) always survives ~11 min, the second file dies ~7 min in. `-gpu guest` does NOT help (API 34 google_apis image doesn't support guest rendering — it silently falls back to host `lavapipe`). Fix: `restart_emulator()` in `tool/run_integration_tests.sh` kills qemu and boots a fresh emulator before every file after the first, so each file runs as a first app instance on clean host GL state. `recover_device()` only helps an adb wedge — after recovery fails the script tries a full restart, and only gives up (setting `EMULATOR_DEAD`, skipping remaining files fast) when the restart itself fails.

ThemeController is inline in `main.dart` (registered before any screen). Note: `PerformanceController` and `ConnectivityController` are GetX controllers but live in `lib/Services/` (not `lib/Controllers/`).

## UI Copy / Revamp Audit

- When restyling a screen, move the copy that integration tests assert on into `lib/Config/app_strings.dart` in the same change. Integration tests must assert `find.text(AppStrings.x)` — never re-type the literal — so copy changes stay compile-time safe on both sides. Data-dependent literals (amounts, counts, plan prices) stay inline.
- `tool/check_ui_strings.sh --strict` (wired into CI in the `test` job, after `flutter analyze`) tracks mechanical design-debt caps (raw `Color(0x…)`, `GlassContainer`, gradients, `BackdropFilter`) recorded in `tool/revamp_baseline.env`. Lower the caps after each revamp wave; never raise — a regression above a cap is new debt.
- Design tokens live in `lib/Components/colors.dart`: `AppColors` (indigo `primary` `0xFF4F46E5`, zinc neutrals, `success`/`error`/`warning`), `AppRadius`, `AppShadows`, `chartSeries`. Pre-revamp brand hexes (cyan `0xFF00E5FF`, purple `0xFF6C63FF`, navy `0xFF1A1A2E`, mint `0xFF69F0AE`, pink `0xFFFF2975`) are fully rebranded to tokens — never reintroduce them. Category data colors (Material palette, seeded `0xFFFF7043`) stay inline.

## Controller Registration (2-Phase)

**Phase 1 — `mainCommon()`** (in this order, `main.dart`): ThemeController → PrivacyController → CurrencyController → AuthController → SubscriptionController → PaymentConfigService → FeatureFlagService → PerformanceController → ConnectivityController → IapService → BiometricService.

**Phase 2 — `_handleAuthChange()` after login**: TransactionController → ProfileController → AnalyticsController → BudgetController → GoalsController → LoanController → ChallengesController → LentMoneyController → RecurringPaymentController.

`BudgetController` and `AnalyticsController` call `Get.find<TransactionController>()` during init — registering them in phase 1 crashes. Screens self-register via `Get.isRegistered()` + `Get.put()` in `initState` (onboarding shows screens before phase 2).

## Transaction Sign Convention

- **Expense**: `amount = -abs(value)`, `senderId = user.uid`, `recipientId = ""`
- **Income**: `amount = +abs(value)`, `senderId = ""`, `recipientId = user.uid`
- Budget aggregation: filter `amount < 0` before `.abs()` — otherwise income triggers false over-budget alerts
- CSV import (`import_service.dart`): must NOT call `.abs()` on amounts

## Wealth / Asset System

One Firestore subcollection per asset type under `users/{userEmail}/`, plus `wealth/portfolio` summary doc.

**26 subcollections** (listed in `firestore.rules` wildcard): `fd_accounts, ppf_accounts, post_office_schemes, bonds, chit_funds, stock_holdings, sip_holdings, etf_holdings, foreign_stocks, startup_investments, pf_accounts, vpf_accounts, nps_accounts, gold_holdings, sgb_holdings, jewelry_items, crypto_holdings, reit_holdings, p2p_loans, agri_land, properties, vehicles, insurance_policies, business_assets, bnpl_entries, credit_cards`

**WealthPortfolio** (`lib/Models/wealth_data.dart`): 24 asset fields + `custom` map, `targets`, `hiddenKeys`. `totalAssets` sums all 24 + custom entries. `totalLiabilities = loans + creditCard + bnpl`.

**Dashboard** must use `streamPortfolio()` (not `getPortfolio()`) — one-shot fetch leaves amounts stale after navigating back. Confirmed in `wealth_builder.dart:63` (primary subscription in `initState`). Note: `_loadData()` also calls `getPortfolio()` (~line 106) for geo-enrichment, but the primary real-time data comes from the stream.

**Generic screen**: `AssetDetailScreen(config:)` — 22 configs in `lib/Config/asset_screen_configs.dart` (all types except the four below). Custom screens: `RealEstateDetailScreen` (properties), `VehicleDetailScreen`, `InsurancePolicyScreen`, `CreditCardDetailScreen`.

## Admin Feature Flags (global kill-switches)

Admins toggle live feature availability from Settings → Admin Utils → Feature Flags. State lives in the **global doc `app_config/feature_flags`** (a `Map<String,String>` of strings: `enabled`/`comingSoon`/`hidden`) — `firestore.rules` already allows auth-read + admin-write, no rule changes. Missing doc/key/value ⇒ `enabled` (safe default).

**3-state semantics**: `enabled` = normal (Pro gates unchanged); `comingSoon` = non-admins get a ComingSoon placeholder at every entry point while admins keep using the feature; `hidden` = removed for everyone including admins ("as if never there", re-enabled only from the admin screen).

**Registry**: `lib/Config/feature_flags.dart` is the single source of truth for the 55 keys (`transactions` (only `critical`), `transaction_search`, `upi_pay`, `qr_scan`, `budget`, `category`, `lent_money`, `recurring`, `goals`, `challenges`, `forecast`, `analytics`, `analytics_advanced`, `data_filters`, `financial_summary`, `quick_overview`, `current_period`, `expense_breakdown`, `spending_heatmap`, `top_merchants`, `salary_detected`, `spending_personality`, `export_csv`, `export_pdf`, `share_report`, `ai_insights`, `ai_monthly_forecast`, `ai_daily_limit`, `monthly_heatmap`, `category_insights`, `wealth`, `custom_mode`, `total_net_worth`, `wealth_assets`, `allocation`, `ideal_income`, `smart_suggestions`, `loan_tracker`, `sms_tracking`, `sms_import`, `sms_auto_import`, `expense_reminder`, `lite_mode`, `biometric_app_lock`, `privacy_mode`, `restore_data`, `import_data`, `export_all_data`, `transaction_audit`, `sms_rules`, `invite`, `profile`, `notifications`, `home_widget`, `update_checker`) + copy/icons. Gate with these keys as string literals. `FeatureFlag.groups` (title/icon/ordered keys) organizes the admin Feature Flags screen by screen/section — every `all` key must appear in exactly one group and in the known-keys list in `test/feature_flags_test.dart` (both test-enforced); add new flags to `all`, a group, and the known-keys list together.

**Settings switches**: entry tiles in the settings sections use `FeatureVisible` to remove the row when `hidden` and an inner `Obx` + `Switch(onChanged: visible ? handler : null)` so `comingSoon` disables the toggle for non-admins but keeps the row (admins keep using it). A privacy switch/balance-tap must call `PrivacyController.toggle()` (guarded — no-ops on hidden) so masking can never be re-enabled; a `ever(statusMap)` worker in `main.dart` force-flips `isPrivacyMode` off the moment `privacy_mode` is hidden. Biometric gates read `BiometricService.lockActive` (pref AND not-hidden) at `main.dart` (home lock screen, pause/resume) and `checkBiometricOnLaunch`. UI-facing flags: `lite_mode` is UI-only — `hidden` disables the manual toggle but the startup auto-detect (≤4 cores) stays. Background flags: `sms_auto_import` / `expense_reminder` (and `notifications`, `recurring`, `update_checker`, `home_widget`) are enforced in `background_worker.dart` via a per-tick `app_config/feature_flags` `.get()`. That read is **fail-closed**: the foreground `ever(statusMap)` worker in `main.dart` mirrors the authoritative status map into SharedPreferences (`bg_feature_flags`); when the isolate's own server read fails/races an auth restore, `resolveBackgroundFlags()` returns the mirror (then the legacy `bg_cached_feature_flags`) — never a blanket `enabled` — so a value the admin hid stays dead across outages and cold starts. `callbackDispatcher` also polls briefly for a restored `FirebaseAuth` session before the read. Only `hidden` halts background work — `comingSoon` is a UI-level state.

**Transport** (`lib/Services/feature_flag_service.dart`, mirrors PaymentConfigService): native `.snapshots(includeMetadataChanges: true)` in `onInit`; **web 60s `.get()` poll** via `startPolling()` kicked off in `main.dart` after login (JS b815/ca9 constraint — see the web gotcha). Firestore wiring lives in protected `startRealtime()` so test fakes can `super.onInit()` + no-op it. `statusOf` must read `_status[key]` (not `_status.value[key]` — GetX 4.7.2 marks `.value` `@protected`; `operator []` registers the Obx dependency identically).

**Admin identity**: `users/{email}.isAdmin` → `SubscriptionController.isAdmin`; `FeatureFlagService.userIsAdmin` uses a `Get.isRegistered` guard + `adminOverride` test hook.

**Gating tiers**:
- Entry points: `if (!ensureFeatureVisible(context, 'key')) return;` before `gotoPage`/`Get.to` (pushes the ComingSoon placeholder, returns false).
- `ensureFeatureUsable(context, key)` is the same guard minus the placeholder — `hidden` is a hard no-op. Use it for surfaces that must STAY on screen when the flag is hidden but whose taps are still gated (home AppBar avatar + "Welcome back" greeting under `profile`: always visible, taps dead when hidden).
- Entry-point inventory (several surfaces share a key — know what a toggle really hides):
  - Send/Receive on the home balance card + the core add/send flow → `transactions` (`FeatureVisible` + tap guards in `balance_card.dart`); the same-card "+ Add Lent" / "- Subs" chips → `lent_money` / `recurring` (a worker force-flips the toggles off when hidden).
  - Home "Quick Send" UPI row (`QuickSendRow`, guards in `quick_send.dart`) **and** the Add-Send form's "Scan & Pay with UPI" button (`_upiPayButton` in `add_transaction.dart`, only when `type == send && !kIsWeb`) **both reuse `upi_pay`** — hiding it removes the UPI pay surface everywhere at once; keep it that way (deliberate reuse decision).
  - Home "Scan QR to Pay" FAB → `qr_scan` (Pro-check runs before the flag guard).
  - SMS import is THREE screens under THREE keys: Settings "Automation → Import SMS" tile → `sms_tracking`; Transaction History AppBar SMS button → `sms_import`; background auto-import → `sms_auto_import` (enforced per-tick in `background_worker.dart`). All three open `SmsImportScreen` — the key is distinct per entry surface, don't conflate them.
  - Decision rule that produced the above: a surface gets its own key when it lives on a different screen/place and wants independent control (`sms_import`); it reuses an existing key when it's the same feature reached from another spot (`upi_pay` on the Add-Send form).
- Bodies: `FeatureGate(flagKey:, child:)` — reactive (GetBuilder on the service), returns `child` unchanged when visible so layout never shifts. Used on the three tab bodies (Analytics, AI Insights, Wealth).
- Settings sections: `FeatureSection(flagKeys: [...], child:)` hides a header + tile group (including its trailing `SectionDivider`) when **every** listed flag is `hidden`, so no heading dangles over an empty section (Automation, Access Control). Empty-only-when-all-hidden, not a single-key gate.
- AI Insights sub-components (`analysis.dart` `_buildContent`): each card is wrapped in its own `FeatureVisible` (`ai_monthly_forecast`, `ai_daily_limit`, `monthly_heatmap`, `category_insights`); the Forecast + Daily-Limit combo is additionally wrapped in `FeatureSection(['ai_monthly_forecast', 'ai_daily_limit'])` so both cards + their gap disappear together. Per-component gating MUST use these self-registering GetBuilder widgets — the outer `FeatureGate` re-renders only its own subtree, so top-of-build booleans would go stale on a mid-session admin flip.
- Wealth sub-components (`wealth_builder.dart`): sections inside the `CustomScrollView` are gated with `SliverFeatureVisible` (sliver-safe — a plain box `FeatureVisible` crashes a sliver slot). `custom_mode` hides the banner Smart/Custom switch + the Manage-Visibility tune button only ("hide toggle only" — persisted Smart/Custom mode untouched); `total_net_worth`, `wealth_assets` (header + every `_buildAssetSlivers` element), `allocation`, `ideal_income`, `smart_suggestions` hide their whole section. The `loan_tracker` card wrap inside `_buildAssetSlivers` stays as-is.
- Analytics screen sub-components (`analytics.dart` `_buildBody`, a `SingleChildScrollView` → `Column`): 9 sections are individually gated with box `FeatureVisible` (`data_filters`, `financial_summary`, `quick_overview`, `current_period`, `expense_breakdown`, `spending_heatmap`, `top_merchants`, `salary_detected`, `spending_personality`), each wrapping a leading `SizedBox(32.h)` inside the gate so hiding leaves uniform spacing — note `current_period` gates both the multi-month "Monthly Trend" chart and the single-month "Current Period" fallback, and analytics' `spending_heatmap` is a distinct key from AI Insights' `monthly_heatmap`. The "View Advanced Category Trends" button stays under `analytics_advanced`; the outer tab gate stays `analytics`.
- Bottom-nav tabs: **name-keyed, not indexed**. `lib/Config/tab_destinations.dart` centralizes the 5 tabs (`home/null`, `analytics`, `insights`/`ai_insights`, `wealth`, `settings/null`); `visibleTabs()` filters `hidden` ones out everywhere (bottom pill + wide rail + MainShell). All tab logic in `main_shell.dart`/`adaptive_scaffold.dart`/`bottom_nav_bar.dart`/`methods.dart` (`gotoScreen(name)`) switches on tab **name**, so hiding a tab never renumbers the others. `_select` shape: feature-gate → Wealth age-gate → setState.
- Business logic: `ExportService` `_requireFeature('export_csv'|'export_pdf')` throws on direct calls. **BudgetController is intentionally NOT gated** — budget aggregation runs internally for alerts/analytics; only the budget UI (CategoryBudgetScreen/category management) is gated, so aggregation never breaks.

**Performance**: this is why GlassContainer reads `PerformanceController.to.liteMode.value` first and every nav surface is `GetBuilder<FeatureFlagService>` (reactive to a mid-session admin flip without a restart). Keep the liteMode-first read ordering — moving it breaks GetX's "improper use" guard under `flutter test`.

## Code Style

- `flutter_screenutil` suffixes (`.w`, `.h`, `.sp`) — no hardcoded pixels; design ref 390×844
- `CurrencyController.to.currencySymbol.value` — never `₹`
- `Exception("message")` — never `throw "message"`
- `QueryDocumentSnapshot.data()` is non-nullable (no `!` or `as Map`)
- `DocumentSnapshot.data()` is nullable (needs `?` or null check)

## SMS Classification

**Auto-import watermark**: the background auto-import scans forward from a per-user watermark (`last_sms_scan_ms_<email>`, `SmsService.autoImportWatermarkKey`). `SmsService.setAutoImportEnabled(true)` (the general-settings "Auto-Import SMS" toggle) seeds the watermark to `now` on every enable, so SMS received BEFORE enabling are never backfilled and re-enabling restarts from the new enable time. A missing watermark resolves to `now` in the background worker (`resolveSmsScanStart`), never epoch — no silent history import for users who enabled before this shipped. Disabling only flips the flag; the manual Import SMS screens and the admin `triggerSmsImport(days: N)` are unaffected by the toggle. The periodic cadence is the `smsScanInterval` const (15 min, `background_worker.dart`) — single source for both the scheduler and the General-settings "Next auto-import ≈" countdown (`_NextSmsAutoImportCountdown` in `general_settings.dart`, which estimates next = watermark + `smsScanInterval` and labels it `≈` because Doze can defer the actual WorkManager fire time).

Primary regex must include `debited by`/`credited by` for Indian UPI messages ("debited by 86.00" has no `Rs`/`INR` prefix):

```
(?:Rs\.?|INR|MRP|Amt|Amount|debited by|credited by|by Rs\.?)\W*(\d+(?:,\d+)*(?:\.\d{1,2})?)
```

Priority: refund/cashback→credit, debited/deducted/withdrawn/spent/sent→debit, credited/deposit→credit, "received by"→debit, "received in/to/into/from"→credit, default→debit.

## Common Gotchas

1. **Stream `.limit()` on balance** — never apply. Balance sums ALL transactions.
2. **Cache invalidation after read** — always `LocalCacheService.invalidate(key)` after restoring from cache. Prevents stale `.limit()` data.
3. **Salary detection false positives** — filter EMI/loans from candidates BEFORE median/max. Check `recipientName` for exclusion keywords only (not `note`/`category`).
4. **`fromMap` Timestamp cast** — use `(map['lastUpdated'] as dynamic)?.toDate()` (works with real Timestamp and test mocks).
5. **Test values drift** — when adding asset fields, update `totalAssets` expected values in both `wealth_data_test.dart` tests and the comment sum.
6. **`compact()` formats** — `wealth_math.dart`: ≥10M (1Cr) → `"x.xCr"`, ≥100K (1L) → `"x.xL"`, ≥1K → integer `K`. So `compact(1500)` → `"2K"` and `compact(1_000_000)` → `"10.0L"` (1M is below the 1Cr threshold, not `"1.0M"`).
7. **Don't mix GetX + Flutter navigator** — `Get.dialog()` + `Navigator.pop()` + `Get.snackbar()` crashes. Use `showDialog()` + `Navigator.of(context, rootNavigator: true).pop()` + `ScaffoldMessenger.showSnackBar()`.
8. **FilePicker.saveFile() returns content:// on Android** — cannot `File(uri).writeAsString()`. Pass `bytes: Uint8List.fromList(utf8.encode(csv))`.
9. **`orderBy() as Query` is unnecessary cast** — triggers `unnecessary_cast` warning.
10. **Static cache leaks on logout** — `SmsService.resetCache()` (clears `_correctionCache`, `_historyCache`, `_rulesLoaded`) and `RecurringService.resetCache()` are both called on logout (`main.dart` + `auth_controller.dart`).
11. **Trial state race** — subscription trial flags must be set *after* Firestore confirms the write.
12. **BackdropFilter sigma** — keep sigma ≤ 4 and wrap in `RepaintBoundary`. Sigma 10 + two instances = severe scroll jank (`glass_container.dart`).
13. **Avoid ShaderMask on animated text** — renders child offscreen each frame. Use direct `TextStyle(color:)` instead (`balance_card.dart`).
14. **setState in TweenAnimationBuilder.onEnd** — triggers full subtree rebuild on every animation completion. Use `ValueNotifier` + `.value = ` instead.
15. **Cache O(n) getters** — `totalBalance` iterates all transactions. Use `Rx` + `ever` worker so the loop only runs when data actually changes (`transaction_controller.dart`).
16. **Cache Theme.of** — 13 calls per build in `analytics.dart` → cache `_cachedTheme` and `_cachedIsDark` in `build()`, restore `get isDark => _cachedIsDark`.
17. **Unchecked `jsonDecode` casts** — always check `is Map` / `is List` before `as`. Prevents crashes on corrupted cache (`category_service.dart`, `offline_queue.dart`, `sms_import_screen.dart`).
18. **Firestore JS SDK b815 corruption (web)** — after the AsyncQueue assertion the SDK is unrecoverable without a page reload; `main.dart` detects the error string and auto-reloads once via `reloadPage()` (`web_reload_web.dart`). The whole web auth flow in `main.dart` is shaped around avoiding this bug — do NOT "simplify" it: `enableNetwork()` is deferred until after login, Phase 2 controllers are registered with 500 ms delays on web, `ThemeController.resubscribe()` is re-invoked after `TransactionController` is up (with the `.get()` kept after `.snapshots()` listeners), `PaymentConfigService.startPolling()` only starts after all `.snapshots()` listeners exist, `_checkOnboardingStatus` skips the Firestore `.get()` on web, and `checkSubscriptionStatus()` is skipped on app resume. Any reordering can re-trigger the crash.

## Platform-Specific

- **Google Sign-In**: Pinned to `^6.2.2` (`pubspec.yaml`). Do not upgrade to v7+ — `signIn()` replaced with stream-based API that has a race condition.
- **UPI Payments**: Kotlin MethodChannel (`money_control/upi`), not `url_launcher`. Hard-coded package names: GPay, PhonePe, Paytm, BHIM, CRED, null (system chooser). `canLaunchUrl()` unreliable on Android 11+ — show all apps and handle `APP_NOT_FOUND` via try/catch.
- **Built-in Kotlin**: As of Flutter 3.35, plugins that apply KGP directly (`file_picker`, `firebase_storage`, `home_widget`, `share_plus`, `shared_preferences_android`, `workmanager_android`, `package_info_plus`) trigger a migration warning. Track upstream updates; no action needed until Flutter drops KGP support.
- **google-services.json**: Gitignored. CI injects from `secrets.GOOGLE_SERVICES_JSON`. For local builds, download from Firebase Console to `android/app/google-services.json`.
