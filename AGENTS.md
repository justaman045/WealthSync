# AGENTS.md

Critical rules for this Flutter + GetX + Firebase app. Package name is
`money_control` (used in imports). Read the section matching your task; the
gotchas below each encode a bug that already shipped once.

## Commands

```bash
flutter pub get
flutter analyze --no-fatal-infos   # CI gate: warnings are fatal, infos are not
tool/check_ui_strings.sh           # UI design-debt audit: report only
tool/check_ui_strings.sh --strict  # fail if debts exceed tool/revamp_baseline.env caps
flutter test                       # unit/widget tests ONLY (test/); integration tests never run here
flutter test test/<file>_test.dart # single file
tool/run_integration_tests.sh      # canonical E2E runner: one file at a time, fresh emulator per file (needs env creds + booted emulator-5554)
flutter gen-l10n                   # after editing lib/l10n/*.arb (l10n.yaml + generate: true)
flutter run
flutter build apk --release
flutter build appbundle --release
flutter build web --release --base-href /WealthSync/   # GitHub Pages deploy
```

**Pre-commit gate (CI's `test` job, in order):** `flutter analyze --no-fatal-infos` →
`tool/check_ui_strings.sh --strict` → `flutter test`. All three must pass.

**Generated l10n Dart is committed**: `lib/l10n/app_localizations.dart` +
`app_localizations_en.dart` are tracked, so an ARB edit ships with its
regenerated pair in the same commit.

## Critical Flutter / GetX Patterns

- **Never `Get.find<>()` in a field initializer** — controllers aren't registered
  yet. Guard + defer in `initState`:
  ```dart
  late final TransactionController _controller;
  @override void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) Get.put(TransactionController());
    _controller = Get.find<TransactionController>();
  }
  ```
- **Dispose `TextEditingController`s created for dialogs/sheets.** A modal's
  `.whenComplete` / `try/finally` fires when `Navigator.pop` is called —
  `route.popped` completes on **pop**, not after the exit animation. If the modal
  rebuilds during that window (e.g. `await ctrl.updateProgress()` flips an
  `Obx`-watched `isSaving` *after* pop) the still-animating `TextField`
  re-attaches to the disposed controller and throws `A TextEditingController was
  used after being disposed`, cascading into a bogus `RenderFlex overflow` +
  `Duplicate GlobalKeys`. This shipped in the Goals Add-Progress sheet. **Fix: own
  the controller in a `StatefulWidget` and dispose in `State.dispose()`** (see
  `_AddProgressSheet` in `goals_screen.dart`, `_AddSheet` in
  `asset_detail_screen.dart`). `try/finally` is fine only for a `showDialog` whose
  content never rebuilds reactively.
- **Check `mounted` after every `await`** before `setState`/`context`.
- **Global dialogs use `Get.overlayContext!`**, not `Get.context!`:
  `showGeneralDialog(context: Get.overlayContext!, …)`.

## Architecture

MVC-Service-Repository with GetX.

| Directory | Role |
|-----------|------|
| `lib/Models/` | Data classes with `fromMap`/`toMap` |
| `lib/Repositories/` | Firestore access only |
| `lib/Services/` | Business logic (not controllers) |
| `lib/Controllers/` | GetX controllers binding services to reactive state |
| `lib/Screens/` | Widgets only; no logic |
| `lib/Components/` | Reusable widgets (+ `colors.dart` design tokens) |
| `lib/Config/` | `AssetScreenConfig` defs, `feature_flags.dart`, `app_strings.dart`, `tab_destinations.dart` |
| `lib/Utils/` | `IconHelper`, `wealth_math.dart`, `num_parse.dart`, `platform_support.dart` |
| `lib/Platform/` | Platform-abstraction `*_platform.dart` + `*_platform_stub.dart` pairs (9 services) |
| `lib/l10n/`, `lib/data/` | ARB files; challenge preset seed data |
| `test/` | unit/widget tests. Contract tests guarding silent failures: `feature_flags_test`, `feature_gate_test`, `toggle_gate_test`, `background_flags_test`, `firestore_indexes_test`, `platform_contract_test`, `referral_reward_math_test`, `balance_overlay_math_test`, `early_return_guard_test` |
| `integration_test/` | 25 E2E tests + `test_credentials.dart` + `test_helpers.dart` (read it before writing a test). Need live Firebase + emulator-5554. `mainCommon(isTest: true)` skips only Crashlytics/notifications |

`ThemeController` is inline in `main.dart` (registered before any screen).
`PerformanceController`/`ConnectivityController` are GetX controllers but live
in `lib/Services/`, not `lib/Controllers/`.

### Controller registration (2-phase)

**Phase 1 — `mainCommon()`** (this order, `main.dart`): ThemeController →
PrivacyController → CurrencyController → AuthController → SubscriptionController →
PaymentConfigService → FeatureFlagService → PerformanceController →
ConnectivityController → IapService → BiometricService.

**Phase 2 — `_handleAuthChange()` after login**: TransactionController →
ProfileController → AnalyticsController → BudgetController → GoalsController →
LoanController → ChallengesController → LentMoneyController → RecurringPaymentController.

`BudgetController` and `AnalyticsController` call `Get.find<TransactionController>()`
in init — registering them in phase 1 crashes. Screens self-register via
`Get.isRegistered()` + `Get.put()` in `initState` (onboarding runs before phase 2).

## Code Style

- `flutter_screenutil` suffixes (`.w`, `.h`, `.sp`); design ref 390×844.
- `CurrencyController.to.currencySymbol.value` — never a literal `₹`.
- `Exception("message")` — never `throw "message"`.
- `QueryDocumentSnapshot.data()` is non-nullable (no `!`/`as Map`);
  `DocumentSnapshot.data()` is nullable (needs `?`/null check).

## Transaction Sign Convention

- **Expense**: `amount = -abs(value)`, `senderId = user.uid`, `recipientId = ""`.
- **Income**: `amount = +abs(value)`, `senderId = ""`, `recipientId = user.uid`.
- Budget aggregation: filter `amount < 0` before `.abs()`, else income triggers
  false over-budget alerts. `import_service.dart` must NOT call `.abs()` on amounts.

## Auth / Session Teardown

- **One teardown list.** `AuthController.disposeUserScopedState()` owns the nine
  user-scoped controllers + `AuditController`, clears SMS/recurring caches, and
  **awaits** `LocalCacheService.clearAll()`. Both sign-out paths (`logout()` and
  `main.dart`'s `_handleAuthChange`) call it. A second hand-maintained list had
  already drifted (missing `AuditController` → leaked audit state); an *unawaited*
  clear can land after a fast re-login and wipe the new account's fresh cache.
- **Account deletion pre-flights auth freshness.** `UserService.deleteAccount`
  checks `user.metadata.lastSignInTime` (5-min window) and refuses *before*
  touching Firestore; otherwise it deleted all data then hit
  `requires-recent-login`. After deletion `DeactivateAccountScreen` must
  `signOut()` — deleting the auth user alone does not clear `FirebaseAuth.currentUser`.
- **Sign-up is serialized with the auth stream.** `createUserWithEmailAndPassword`
  signs in immediately → `_handleAuthChange` signs unverified accounts back out
  mid-write. `signup.dart` sets `AuthController.signupInProgress`, checked at the
  very top of `_handleAuthChange` **before** the `_handledUid` dedupe (so the
  emission isn't recorded as handled), and does its own `await signOut()` at the end.
- **Never fall through a null session.** Onboarding shows an error and stays put
  when `currentUser`/email is null instead of discarding input and navigating home.
- `SubscriptionController.resetForSignOut()` clears `trialEndDate`/`trialUsed`/`planType`
  — `isPro` is `status == pro || isTrial` and `isTrial` only checks whether
  `trialEndDate` is future, so a stale date hands Pro to the next user on a shared device.
- `is_onboarded` is device-wide, so it is stamped with `is_onboarded_email` and only
  trusted for that email (no stamp = legacy pref, keep old behavior). `currency_code`/
  `currency_symbol` stay device-level on purpose.
- A failed `signOut()` must **abort** teardown (session still live); a Firestore
  failure *after* a successful sign-in must sign back out, not leave a stuck error
  screen. A throw inside `_handleAuthChange` resets `_handledUid` so the next
  emission retries.
- `_deferredStartup` guards each step individually (`step(label, action)`); these
  run before `runApp`, so one throw used to skip `enableNetwork()` and leave the app
  permanently offline.

## Referral Codes — every write is a transaction

`lib/Services/referral_service.dart`:

1. **Read the code doc INSIDE the transaction.** `runTransaction` only conflicts on
   documents it read, so a `codeRef.get()` outside it double-succeeds and the second
   write clobbers the first's `claims` entry (a reward silently vanishes).
   `applyReferralCode` does `txn.get(codeRef)` *and* `txn.get(userRef)` before writing.
2. **Return the real result.** Use `runTransaction<bool>` and `return false` for
   "invalid / already referred" — a bare early `return` leaves `applied == true` and
   the UI reports a referral that never applied.

`_drainClaims` writes the referrer's `trialEndDate`/`referralCount` and the `credited`
marker in **one** transaction; as two writes a mid-failure paid the same referral twice.

Payout arithmetic is `debugComputeTrialEnd` (30 days/claim, hard 45-day cap, stacks
onto a future expiry, restarts from now if elapsed), unit-tested in
`test/referral_reward_math_test.dart` — the only place Pro is granted without a
purchase, so pin the numbers. `SubscriptionController` client status is cosmetic; the
authoritative check is the valid-pro-claim rule on the user document.

## Wealth / Asset System

One Firestore subcollection per asset type under `users/{userEmail}/`, plus a
`wealth/portfolio` summary doc.

**26 subcollections** (`firestore.rules` wildcard): `fd_accounts, ppf_accounts,
post_office_schemes, bonds, chit_funds, stock_holdings, sip_holdings, etf_holdings,
foreign_stocks, startup_investments, pf_accounts, vpf_accounts, nps_accounts,
gold_holdings, sgb_holdings, jewelry_items, crypto_holdings, reit_holdings, p2p_loans,
agri_land, properties, vehicles, insurance_policies, business_assets, bnpl_entries,
credit_cards`. The same rules wildcard also lists `backups`/`insights`/`preferences`/`logs`
(cleared by the GDPR delete flow) — those are not asset types. Adding an asset type means
adding its collection to this wildcard or its writes are denied.

**WealthPortfolio** (`lib/Models/wealth_data.dart`): 24 asset fields + `custom` map,
`targets`, `hiddenKeys`. `totalAssets` sums 23 of them — every asset field **except
`insurance`** — plus `custom`; `totalLiabilities = loans + creditCard + bnpl`.

**Dashboard must use `streamPortfolio()`, not `getPortfolio()`** — a one-shot fetch
leaves amounts stale after navigating back. The primary subscription is in
`wealth_builder.dart`'s `initState`; `_loadData()` also calls `getPortfolio()` for
geo-enrichment, but the stream is the real-time source.

**Insurance `sumAssured` is NOT an asset.** It is excluded from `totalAssets`,
`WealthService` visible/net totals, allocation, and the net-worth accumulator; it is
still persisted, listed (with `coverageStyle`), and feeds the coverage insight.
Changing that is a product decision, not a bug fix.

**Balance-card overlays are temporary view toggles, not totals.**
`balance_card.dart` headlines `computeDisplayTotal(balance, netLent, includeLent,
pendingDues, includeDues)` (pure, `lib/Utils/wealth_math.dart`, pinned by
`test/balance_overlay_math_test.dart` — the *signs* are the point). Two chips beside
"Total Balance":
- **"+ Add Lent"** → adds `LentMoneyController.netBalance` (`lent_money`).
- **"Dues Deducted"** → subtracts `RecurringPaymentController.pendingSubscriptions`
  (`recurring`), the month total of not-yet-debited commitments.

Both are off by default and never persisted (plain `RxBool` on the `State`). Three
easy-to-get-wrong rules: **unclamped** (an overlay may legitimately go negative);
**a mode, not a one-time subtraction** (dues-on at ₹0 lowers the balance when a
subscription is added later — intended); **hiding the chip must also clear the math**
(`FeatureVisible` drops the control when `hidden`, so `_resetFlaggedToggles()` must
force the `RxBool` off or the balance keeps counting an invisible feature). Both chips
early-return in privacy mode. `pendingSubscriptions` is the one recurring figure that
*does* reduce the balance — but only in the overlay-on state.

**Transaction-derived Wealth values must be reactive.** Bank balance, monthly income,
smart insights, and asset targets read transactions (not the portfolio doc);
`_initTransactionWorker` in `wealth_builder.dart` recomputes them via an `ever` worker
(targets debounced), else they go stale until rebuild.

**Expected income / AI daily limit** (`computeExpectedIncome` + `computeDailyLimit`, pure
in `wealth_math.dart`, pinned by `test/wealth_math_test.dart`). Mode precedence: `manual`
wins only when `manualMonthly > 0`; manual-with-no-value *falls back to blend*. Blend =
`max(thisMonthIncome, 3-month average)`. Salary window = income in the union of
current-month days 1–7 and the previous month's last working day (Mon–Fri); an empty
window returns `expectedIncome: 0` + `salaryWindowEmpty: true` (rendered as a note, not an
error). Persisted by `IncomeSettings` (`income_mode`/`income_manual_monthly`);
`analysis.dart` recomputes it live, so don't cache it.

**Never cap an asset list at 25 docs** — the visible list is a view but the total
written back comes from a full read, so a cap desyncs them. The 5 asset screens hold
one cached stream (`_entries`) instead of rebuilding the query in `build()`.

**Generic screen**: `AssetDetailScreen(config:)` — 22 configs in
`lib/Config/asset_screen_configs.dart` (all types except the four custom screens:
`RealEstateDetailScreen`, `VehicleDetailScreen`, `InsurancePolicyScreen`,
`CreditCardDetailScreen`).

## Goals

One `users/{email}/goals` collection; `GoalModel` + `GoalsRepository` +
`GoalsController` + `goals_screen.dart` / `add_goal_screen.dart`.

- **Editing reuses `add_goal_screen.dart`.** `AddGoalScreen({GoalModel? goal})`
  prefills and calls `GoalsController.updateGoal`; create calls `addGoal`. The
  card's `⋮` menu is the entry point; tap still = Add Progress, long-press =
  Delete (the integration test depends on long-press).
- **`GoalModel.edited()` preserves `id`/`currentAmount`/`createdAt`** and
  recomputes `isCompleted = currentAmount >= targetAmount`; nullable args are
  applied directly so a null description/deadline **clears** the field (unlike
  `copyWith`, which uses `??` and cannot null a field).
- **Totals are ACTIVE-only.** `summarizeGoals()` (pure, in `goal_model.dart`,
  pinned by `test/goal_model_test.dart`) sums targets/saved over non-completed
  goals and clamps progress to 1.0; the "Total Progress" card renders it. A goal
  whose target is edited below its saved amount becomes completed and drops out
  of the totals. Per-goal `%` is `GoalModel.progress` (clamped).

## Admin Feature Flags (global kill-switches)

Admins toggle live availability from Settings → Admin Utils → Feature Flags. State is
the global doc `app_config/feature_flags` (`Map<String,String>`:
`enabled`/`comingSoon`/`hidden`); `firestore.rules` already allows auth-read +
admin-write. Missing doc/key/value ⇒ `enabled` (safe default).

- **`enabled`** = normal (Pro gates unchanged); **`comingSoon`** = non-admins get a
  ComingSoon placeholder at every entry point, admins keep using it; **`hidden`** =
  removed for everyone, re-enabled only from the admin screen.
- **Registry**: `lib/Config/feature_flags.dart` is the source of truth for the 55 keys
  + copy/icons. `FeatureFlag.groups` organizes the admin screen by place.
  `test/feature_flags_test.dart` enforces that `all` is unique, that `groups` covers `all`
  exactly once, and that **every registry key is referenced by a real gate/check in `lib/`**
  — it scans `lib/` for `ensureFeatureVisible/Usable`, `flagKey:`, `statusOf`/`isEnabled`/
  `isHidden`, `visibleToMe`, `FeatureFlag.find`, `_flagHidden`, `_requireFeature`,
  `ComingSoonScreen.forFlag` and `FeatureSection([...])` call-sites, and fails if a key is
  never gated (and if a gate key is unregistered). So registering a key is not enough — wire
  its gate in the same change, add it to a group, and keep the test's known-keys list in
  sync. Gate with these keys as string literals.
- **Transport** (`lib/Services/feature_flag_service.dart`): native
  `.snapshots(includeMetadataChanges: true)` in `onInit`; **web 60s `.get()` poll** via
  `startPolling()` from `main.dart` after login (JS b815/ca9 constraint). Firestore
  wiring lives in protected `startRealtime()` so test fakes can `super.onInit()` +
  no-op it. `statusOf` must read `_status[key]`, not `_status.value[key]` (GetX 4.7.2
  marks `.value` `@protected`; `operator []` registers the Obx dependency the same).
- **Admin identity**: `users/{email}.isAdmin` → `SubscriptionController.isAdmin`;
  `FeatureFlagService.userIsAdmin` uses a `Get.isRegistered` guard + `adminOverride`
  test hook.
- **Gating tiers**:
  - Entry points: `if (!ensureFeatureVisible(context, 'key')) return;` before
    `gotoPage`/`Get.to` (pushes the ComingSoon placeholder, returns false).
  - `ensureFeatureUsable(context, key)` = same guard minus placeholder; `hidden` is a
    hard no-op. Use it for surfaces that must STAY on screen while only taps die (home
    AppBar avatar + "Welcome back" greeting under `profile`).
  - Bodies: `FeatureGate(flagKey:, child:)` — reactive (GetBuilder on the service),
    returns `child` unchanged when visible so layout never shifts. Used on the three tab
    bodies (Analytics, AI Insights, Wealth).
  - Settings sections: `FeatureSection(flagKeys: [...], child:)` hides a header + tile
    group (incl. its `SectionDivider`) only when **every** listed flag is `hidden`.
  - Sub-components: use the self-registering `FeatureVisible`/`SliverFeatureVisible`
    GetBuilder widgets (a plain box one crashes a sliver slot). The outer `FeatureGate`
    re-renders only its own subtree, so top-of-build booleans go stale on a mid-session
    flip.
  - **Entry-point inventory** (know what a toggle really hides):
    - Send/Receive on the balance card + the core add/send flow → `transactions`
      (`FeatureVisible` + tap guards in `balance_card.dart`); its two overlay chips →
      `lent_money` / `recurring` (see Wealth).
    - Home AppBar action row (`homescreen.dart`) is one gated button per feature:
      `transaction_search` (search), `recurring`, `lent_money`, `forecast`, `goals` —
      each `FeatureVisible` + `ensureFeatureVisible` tap guard, Pro-check first.
    - Home "Quick Send" UPI row (`lib/Components/quick_send.dart`) **and** the Add-Send
      form's "Scan & Pay with UPI" (`_upiPayButton` in `add_transaction.dart`, only
      `type == send && isAndroidPlatform`) **share `upi_pay`** — hiding removes the UPI
      surface everywhere at once (deliberate).
    - Home "Scan QR to Pay" FAB **and** the Add-Send AppBar receipt scanner → `qr_scan`
      (Pro-check runs before the flag guard on the FAB). Both `FeatureVisible` + an
      `ensureFeatureUsable` tap guard, so `hidden` removes the button, not a dead affordance.
    - `profile` has three gated entry points: Settings → Profile
      (`ensureFeatureVisible`), the profile sheet's edit button in `main_shell.dart`,
      and "Go to Profile" in `wealth_builder.dart` (both `ensureFeatureUsable`).
    - SMS import is THREE screens under THREE keys: Settings "Automation → Import SMS" →
      `sms_tracking`; Transaction History AppBar SMS button → `sms_import`; background
      auto-import → `sms_auto_import`. All open `SmsImportScreen`; don't conflate the keys.
    - Decision rule: a surface gets its own key when it's a different screen wanting
      independent control (`sms_import`); it reuses a key when it's the same feature
      reached from elsewhere (`upi_pay` on the Add-Send form).
    - Analytics sub-components (`analytics.dart` `_buildBody`): 9 box `FeatureVisible`
      sections (`data_filters`, `financial_summary`, `quick_overview`, `current_period`,
      `expense_breakdown`, `spending_heatmap`, `top_merchants`, `salary_detected`,
      `spending_personality`), each wrapping a leading `SizedBox(32.h)` so spacing stays
      uniform. `current_period` gates both the multi-month "Monthly Trend" and the
      single-month fallback; analytics' `spending_heatmap` ≠ AI Insights' `monthly_heatmap`.
      "View Advanced Category Trends" stays under `analytics_advanced`; outer tab gate `analytics`.
    - Wealth sections use `SliverFeatureVisible`: `custom_mode` hides only the banner
      Smart/Custom switch + tune button (persisted mode untouched); `total_net_worth`,
      `wealth_assets` (header + every `_buildAssetSlivers` element), `allocation`,
      `ideal_income`, `smart_suggestions` hide their whole section. The `loan_tracker`
      card wrap stays.
    - AI Insights cards (`analysis.dart`) each get their own `FeatureVisible`
      (`ai_monthly_forecast`, `ai_daily_limit`, `monthly_heatmap`, `category_insights`);
      Forecast + Daily-Limit also share `FeatureSection([...])` so both + their gap vanish.
    - Bottom-nav tabs are **name-keyed, not indexed**: `lib/Config/tab_destinations.dart`
      centralizes the 5 tabs (`home/null`, `analytics`, `insights`/`ai_insights`,
      `wealth`, `settings/null`); `visibleTabs()` filters `hidden` everywhere (pill, wide
      rail, MainShell). Tab logic switches on tab **name**; `_select` = feature-gate →
      Wealth age-gate → setState.
    - `ExportService._requireFeature('export_csv'|'export_pdf')` throws on direct calls.
      **BudgetController is intentionally NOT gated** — aggregation runs internally for
      alerts/analytics; only the budget UI is gated.
- **Settings switches**: entry tiles use `FeatureVisible` to remove the row when `hidden`
  and an inner `Obx` + `Switch(onChanged: visible ? handler : null)` so `comingSoon`
  disables the toggle for non-admins but keeps the row. A privacy switch/balance-tap must
  call `PrivacyController.toggle()` (guarded); an `ever(statusMap)` worker in `main.dart`
  force-flips `isPrivacyMode` off the moment `privacy_mode` is hidden. Biometric gates
  read `BiometricService.lockActive` (pref AND not-hidden). `lite_mode` is UI-only —
  `hidden` disables the manual toggle but the startup auto-detect (≤4 cores) stays.
- **Background flags** (`sms_auto_import`, `expense_reminder`, `notifications`,
  `recurring`, `update_checker`, `home_widget`) are enforced per-tick in
  `background_worker.dart` via an `app_config/feature_flags` `.get()`. That read is
  **fail-closed**: a foreground `ever(statusMap)` worker mirrors the authoritative map
  into SharedPreferences (`bg_feature_flags`), and `resolveBackgroundFlags()` falls back
  to the mirror (then legacy `bg_cached_feature_flags`) — never a blanket `enabled` — so
  a hidden value stays dead across outages/cold starts. `callbackDispatcher` polls briefly
  for a restored `FirebaseAuth` first. Only `hidden` halts background work; `comingSoon`
  is UI-only.
- **Performance**: GlassContainer reads `PerformanceController.to.liteMode.value` first,
  and every nav surface is `GetBuilder<FeatureFlagService>` (reactive to mid-session
  flips without restart). Keep the liteMode-first read ordering — moving it breaks GetX's
  "improper use" guard under `flutter test`.

## SMS Classification

**Auto-import watermark**: background import scans forward from a per-user watermark
(`last_sms_scan_ms_<email>`, `SmsService.autoImportWatermarkKey`).
`SmsService.setAutoImportEnabled(true)` seeds it to `now` on every enable, so earlier
SMS are never backfilled and re-enabling restarts from the new time. A missing watermark
resolves to `now` (`resolveSmsScanStart`), never epoch. Disabling only flips the flag;
manual Import SMS screens and admin `triggerSmsImport(days: N)` are unaffected. Cadence
is the `smsScanInterval` const (15 min, `background_worker.dart`) — single source for the
scheduler and the General-settings "Next auto-import ≈" countdown (`_NextSmsAutoImportCountdown`,
labelled `≈` because Doze can defer the WorkManager fire time).

**A balance alert is not a transaction.** `isBankSms` accepts anything containing
"alert", so "Balance alert: Avl Bal Rs. 12,345" reaches the parser, matches the amount,
and defaults to *debit* — importing the whole balance as an expense. `parseMessage`
therefore requires a real movement signal and returns null for balance-only wording
("avl bal", "available balance", "closing balance", …).

**The bare-amount fallback is signal-gated.** Without a prefix like `Rs`, only trust a
bare number when a movement word is present, or "123456 is your OTP" becomes a
transaction. (4-digit and 8+ digit bare runs are still skipped as card/OTP candidates —
deliberate.)

Primary regex must include `debited by`/`credited by` for Indian UPI ("debited by 86.00"
has no `Rs`/`INR` prefix):
```
(?:Rs\.?|INR|MRP|Amt|Amount|debited by|credited by|by Rs\.?)\W*(\d+(?:,\d+)*(?:\.\d{1,2})?)
```
Priority: refund/cashback→credit, debited/deducted/withdrawn/spent/sent→debit,
credited/deposit→credit, "received by"→debit, "received in/to/into/from"→credit,
default→debit.

## Write Paths & Backups

`LocalBackupService.backupUserTransactions(email, reportErrors: false)` must run after
**every** transaction write, not just add/edit: `transaction_controller` (add/delete),
`edit_transaction`, `audit_controller` (sign fix), `import_service` (CSV bulk),
`sms_import_screen`, and `recurring_service` (`markAsPaid` + `processDuePayments`). The
coalescing throttle makes the extra calls free; a missing one leaves the mirror stale.
Same for `BudgetService.checkBudgetExceeded` on bulk imports (the add/edit screens raise
the alert, so a CSV/SMS import that blows a budget would otherwise stay silent). Only
check categories from **expense** rows.

It is a **FULL collection read** (`col.get(Source.server)` over every `transactions`
doc, ~260 KB for 709 items), so it coalesces: one in-flight run per account,
`minInterval` (30 s) between successful runs, a `_dirty` flag, and a trailing `Timer`
flushing writes inside the window. Callers get "scheduled", not "read". Two rules:
`reportErrors: false` on automatic callers (a red "Backup failed" snackbar after a
*successful* write reads as data loss, and `ErrorHandler._show` clears the confirmation
snackbar); `force: true` from the explicit Settings action (`data_support_settings.dart`)
so it really reads. The read stays un-ordered/server-sourced — do NOT add the listener's
`orderBy('createdAt')` for a cache hit (docs missing that field drop out, and this is the
recovery path). Test seams: `fetchOverride`/`writeOverride` + `resetSchedulingForTest()`
(`test/local_backup_coalesce_test.dart`).

## Common Gotchas

1. **Never `.limit()` the balance stream** — balance sums ALL transactions.
2. **Cache invalidation after read** — always `LocalCacheService.invalidate(key)` after
   restoring from cache, else stale `.limit()` data persists.
3. **Salary detection false positives** — filter EMI/loans from candidates BEFORE
   median/max; check `recipientName` for exclusion keywords only (not `note`/`category`).
4. **`fromMap` Timestamp cast** — `(map['lastUpdated'] as dynamic)?.toDate()` (works with
   real Timestamps and test mocks).
5. **Test values drift** — adding an asset field means updating `totalAssets` expected
   values in both `wealth_data_test.dart` tests and the comment sum.
6. **`compact()` floors, never rounds up** — `wealth_math.dart`: ≥1Cr → `"x.xCr"`,
   ≥1L → `"x.xL"`, ≥1K → integer `K`. Rounding up overstates a balance, so `compact(1500)`
   → `"1K"`, `compact(99999)` → `"99K"`, `compact(1_000_000)` → `"10.0L"` (not `"1.0M"`).
7. **Don't mix GetX + Flutter navigator** — `Get.dialog()` + `Navigator.pop()` +
   `Get.snackbar()` crashes. Use `showDialog()` + `Navigator.of(context,
   rootNavigator: true).pop()` + `ScaffoldMessenger.showSnackBar()`.
8. **`FilePicker.saveFile()` returns `content://` on Android** — can't
   `File(uri).writeAsString()`. Pass `bytes: Uint8List.fromList(utf8.encode(csv))`.
9. **`orderBy() as Query` is an unnecessary cast** — triggers `unnecessary_cast`.
10. **Static cache leaks on logout** — `SmsService.resetCache()` (clears
    `_correctionCache`, `_historyCache`, `_rulesLoaded`) and `RecurringService.resetCache()`
    both run on logout (`main.dart` + `auth_controller.dart`).
11. **Trial state race** — set subscription trial flags *after* Firestore confirms the write.
12. **BackdropFilter sigma** — keep ≤ 4 and wrap in `RepaintBoundary`; sigma 10 + two
    instances = severe scroll jank (`glass_container.dart`).
13. **Avoid ShaderMask on animated text** — renders the child offscreen each frame. Use
    `TextStyle(color:)` (`balance_card.dart`).
14. **No `setState` in `TweenAnimationBuilder.onEnd`** — rebuilds the whole subtree each
    completion. Use `ValueNotifier` + `.value = `.
15. **Cache O(n) getters** — `totalBalance` iterates all transactions; use `Rx` + an
    `ever` worker so the loop runs only on data change (`transaction_controller.dart`).
16. **Cache `Theme.of`** — 13 calls/build in `analytics.dart`; cache `_cachedTheme`/
    `_cachedIsDark` in `build()` and restore `get isDark => _cachedIsDark`.
17. **Unchecked `jsonDecode` casts** — always check `is Map`/`is List` before `as`
    (`category_service.dart`, `offline_queue.dart`, `sms_import_screen.dart`).
18. **Firestore JS SDK b815 corruption (web)** — after the AsyncQueue assertion the SDK is
    unrecoverable without a page reload; `main.dart` detects the error string and reloads
    once via `reloadPage()` (`web_reload_web.dart`). The whole web auth flow is shaped
    around avoiding it — do NOT "simplify": `enableNetwork()` is deferred until after
    login, phase-2 controllers register with 500 ms web delays, `ThemeController.resubscribe()`
    is re-invoked after `TransactionController` is up (`.get()` after `.snapshots()`),
    `PaymentConfigService.startPolling()` starts only after all `.snapshots()` listeners
    exist, `_checkOnboardingStatus` skips the Firestore `.get()` on web, and
    `checkSubscriptionStatus()` is skipped on resume. Any reordering can re-trigger it.
19. **Never trust a cache/pref/map blindly** — `jsonDecode` throws on corruption, and Dart
    infers a string-literal map as `Map<String, String>`, which passes an
    `is Map<String, dynamic>` test but throws when you store a Timestamp into it. Guard
    `jsonDecode` and use `_assignRestored`-style try/catch writes; for numeric casts use
    `(x as dynamic)?.toString()`.
20. **Backup restore must not rewrite free text** — `_restoreDates` converts ISO strings
    back to Timestamps, gated on a field-name allow-list (`_dateFieldNames` + `*date`/
    `*dates`/`*timestamp` suffixes) with a free-text denylist; a blanket "any ISO-looking
    string" rule destroyed notes like "2026-01-15T10:00 was the party". List items convert
    only under a date-named parent.
21. **Never build a stream inside `build()`** — `StreamBuilder(stream: _col…)` re-issues
    the query and re-registers a listener every rebuild. Hold it in a nullable field and
    use `??=` (`_entries` in the asset screens, `_usersStream` in admin screens). A stream
    depending on a changing filter (`cateogary_history`) stays inline.
22. **Amount parsing: match the year token to the input's width** — intl's `yyyy` reads a
    2-digit year, so "28-01-26" parsed as year 28 unless `dd-MM-yy` is tried first. ISO
    leads with the year, day/month-first trails with it, so check both ends of the split.
23. **A guard that loses its `return;` is invisible to every gate.** `if (!guard) return;`
    rewritten as `if (!guard) { }` compiles clean, passes analyze, and no behavioural test
    notices. It shipped to master with 269 green tests and killed three admin kill-switches
    (`category`/`notifications`/`home_widget` in `general_settings.dart`) plus two
    `Get.find<SubscriptionController>()` calls. `test/early_return_guard_test.dart` scans
    `lib/` for empty `if` bodies. Corollaries: inside `Obx(() { … return <Widget>; })` the
    fix is `return const SizedBox.shrink();`, not a bare `return;`; and any bulk edit script
    that rewrites a statement's contents must have its output read back — a verify pass that
    only re-runs the analyzer proves nothing.
24. **Analyze-green is necessary, not sufficient — for control flow, assert the control
    flow.** Prefer a pure extracted helper (`computeDisplayTotal`, `debugComputeTrialEnd`,
    `computeExpectedIncome`) over asserting a wrong sign or lost branch through a widget
    tree full of streams.

## Platform-Specific

- **Google Sign-In**: pinned to `^6.2.2`. Do NOT upgrade to v7+ — `signIn()` was replaced
  with a stream-based API that has a race condition.
- **UPI Payments**: Kotlin MethodChannel `money_control/upi`, not `url_launcher`. Hard-coded
  package names: GPay, PhonePe, Paytm, BHIM, CRED, null (system chooser). `canLaunchUrl()`
  is unreliable on Android 11+ — show all apps and handle `APP_NOT_FOUND` via try/catch.
- **Android-only capabilities go through `isAndroidPlatform`** (`lib/Utils/platform_support.dart`),
  never `dart:io`'s `Platform` (breaks the web build) and never `defaultTargetPlatform`
  alone (matches a mobile browser). UPI (Kotlin channel) and SMS import must be gated with
  it; `_initiateUpiPayment` also catches `MissingPluginException` so the spinner can't stick.
- **iOS background work**: `WorkmanagerPlugin.setPluginRegistrantCallback` in
  `ios/Runner/AppDelegate.swift` (module is `workmanager_apple` since 0.8.0, *not*
  `workmanager_ios`); the `registerPeriodicTask` **`uniqueName`**
  (`periodic_checks_unique_v2`) must be in `BGTaskSchedulerPermittedIdentifiers` in
  `Info.plist` — on iOS the uniqueName *is* the BGTaskScheduler identifier, and a mismatch
  fails every schedule with Code 3. `test/platform_contract_test.dart` enforces this;
  `UIBackgroundModes` declares `fetch`+`processing`.
- **Fail-closed stubs**: `iap_platform_stub.dart`'s `PurchaseDetails.status` defaults to
  `error`, never `purchased` (an omitted status + empty verification is a latent
  instant-Pro). `openfile_platform_stub.dart` returns `bool?` while native returns `Result`
  — keep the result discarded at call sites.
- **Built-in Kotlin**: Flutter ≥3.35 plugins that apply KGP directly (`file_picker`,
  `firebase_storage`, `home_widget`, `share_plus`, `shared_preferences_android`,
  `workmanager_android`, `package_info_plus`) log a migration warning. Track upstream; no
  action until Flutter drops KGP support.
- **Android toolchain (Flutter 3.47.7)**: Gradle **9.3.1** / AGP **9.1.0** / KGP **2.4.0**
  (`android/`), JDK 17+ (CI pins temurin 17; the local Android Studio JBR is JDK 25, which
  Gradle 8.14 could not run on). Keep `android.builtInKotlin=false` + `android.newDsl=false`
  — Flutter's escape hatch for KGP-applying plugins. AGP 9 raised the default Java
  compatibility to 11 while those plugins still pin Kotlin `jvmTarget=1.8`, so
  `kotlin.jvm.target.validation.mode=warning` downgrades KGP's new hard error. Firebase
  Gradle plugins must be ≥ `google-services` 4.4.4 / `crashlytics` 3.0.x; `geocoding` must be
  ≥ 4.0.0 (Android compileSdk 35) and 5.x wraps everything in the `Geocoding()` class
  (web stub in `geocoding_platform_stub.dart`). Don't lower these.
- **`google-services.json` is gitignored.** CI injects it from
  `secrets.GOOGLE_SERVICES_JSON`; for local builds download it from the Firebase Console to
  `android/app/google-services.json`.
- **The NDK version is env-overridable** — `android/app/build.gradle.kts` sets
  `ndkVersion = System.getenv("ANDROID_NDK_VERSION") ?: flutter.ndkVersion`. This app ships
  no native code; the NDK is resolved at configure time only because `ndkVersion` is set
  (AGP strips symbols from dependency `.so`s). Flutter 3.47.7 asks for `28.2.13676358`,
  which is NOT on the `ubuntu-24.04` runner, so AGP auto-downloads ~1 GB and has corrupted
  mid-build ("Error on ZipFile: unknown archive"). CI pins the runner-preinstalled
  `27.3.13750724` (job-level `ANDROID_NDK_VERSION` in `flutter_build.yml`, plus an
  "Ensure Android NDK" install-with-retries step in both the `build` and `integration_test`
  jobs); locally the var is unset so Flutter's default applies. Any job that compiles
  Android needs the pin, not just `build`.
- **Release assets are multi-APK.** `build` runs `flutter build apk --release` (universal
  `app-release.apk` — the in-app updater's ABI-agnostic download, see `update_checker.dart`)
  AND `--split-per-abi` (small `app-<abi>-release.apk`, ~40–50 MB vs ~126 MB universal). The
  README links the stable `releases/latest/download/app-arm64-v8a-release.apk`; the release
  glob uploads every `flutter-apk/*.apk`. The two Gradle invocations write into the same
  output dir and coexist — do not assume a split build wipes the universal. Release signing
  enables v1+v2+v3 (`enableV1Signing`/`V2`/`V3` on the signing config), not AGP's default
  v2-only, so sideload installs verify on every Android version.
- **R8 minify is ON for release — a release-only crash is invisible to every test.**
  `isMinifyEnabled`/`isShrinkResources` are set in `android/app/build.gradle.kts`, but unit
  and integration tests run **debug** builds, so R8 damage (a shrunk reflective constructor)
  only appears when a release APK actually launches. Room ships
  `-keep class * extends androidx.room.RoomDatabase`, which preserves the generated class
  **name** but — under R8 full mode — not its no-arg constructor. WorkManager builds its
  `WorkDatabase_Impl` reflectively (`Class.forName(...).getDeclaredConstructor()`), so every
  release APK died at launch inside `androidx.startup.InitializationProvider` with
  `NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init>` until
  `android/app/proguard-rules.pro` added an explicit
  `-keep class * extends androidx.room.RoomDatabase { <init>(...); }`. After touching
  minify/proguard/AGP/dependencies, **build and launch a release APK**, don't just run tests.

## Firestore Deployment

`firestore.rules` and `firestore.indexes.json` are **not** deployed by CI (no credentials
in the repo). Deploy by hand when either changes:

```bash
firebase login
firebase use moneycontroljustaman045           # .firebaserc is tracked
firebase deploy --only firestore:rules,firestore:indexes --dry-run   # always first
firebase deploy --only firestore:rules,firestore:indexes
```

The dry run is the only local rules linter (it COMPILES the rules — `is Map` fails; the
compiler wants lowercase `map`, `timestamp`, `list`, `number`, …). Unit tests assert rules
*source text* only, so they cannot catch a rules-language error. `firebase.json` and
`.firebaserc` are tracked deliberately (public projectId/appId only).

**4 composite indexes** are required (all other queries are single-field/auto-indexed):
`challenges{isActive,createdAt}`, `loans{isActive,createdAt}`,
`transactions{category,date}` (DESC) and `transactions{category,date}` (ASC). Firestore
needs equality fields before the range/orderBy field. Adding a multi-field query means
adding its index here or the query fails at runtime in production.

**`firestore.indexes.json` is the *required* set, not a mirror of production.** Live
production has 5 undeclared, orphaned indexes (console leftovers: `recurring_payments`
`{isActive,nextDueDate}`, `transactions{participants|recipientId|senderId,createdAt}`,
`transactions{recurringPaymentId,date}`) — `git log -S` over `lib/` plus
`firebase firestore:indexes` (the CLI *does* have a list command; there is no `gcloud`
here) confirmed no shipped version issued those queries. The warning on every deploy is
expected — **leave it**. Do NOT paste them in: the contract test pins every declared
index to the file that queries it, so unsourced orphans hollow out the test. Never
`--force` (it deletes live indexes absent from the file).

`test/firestore_indexes_test.dart` is the enforcement mechanism — a **contract test**:
`requiredIndexes` lists each query shape, `querySources` pins it to the issuing file, and
it asserts no redundant index, that every declared `collectionGroup` is queried in `lib/`,
and that all four are `COLLECTION`-scoped.

### Deployment discipline

- **A rules/index `--dry-run` proves the file compiles, never that it is complete** — the
  2026-09-27 dry run passed cleanly and the file was still missing 5 live indexes. Diff the
  required set against `firebase firestore:indexes` before trusting either side.
- **Tightening rules must be checked against already-installed clients, not just current
  source.** Before restricting a collection's updates, walk every write path in the current
  code and confirm older APKs still satisfy the new rule — a create rule requiring a
  new-client-only field, or an update rule whose `diff()` the old client fails, locks out
  every user who hasn't updated.
- **Never deploy with `--force`** until the file is known to be a superset of production.

## Integration Tests

Never run under plain `flutter test`. Manual run (emulator-5554, live Firebase):

```bash
# Credentials come from CI secrets; paste as --dart-define locally.
flutter test integration_test -d emulator-5554 --no-uninstall \
  --dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=... \
  --dart-define=PRO_TEST_EMAIL=... --dart-define=PRO_TEST_PASSWORD=... \
  --file-reporter json:build/report/integration.json
mkdir -p build/report/screenshots
adb shell run-as app.vercel.justaman045.money_control ls -1 cache/screenshots 2>/dev/null | while read f; do
  adb exec-out run-as app.vercel.justaman045.money_control cat "cache/screenshots/$f" > "build/report/screenshots/$f"
done
dart run tool/generate_test_report.dart --unit=build/report/unit.json \
  --integration=build/report/integration.json \
  --screenshots=build/report/screenshots --out=build/report/report.html
```

CI (`.github/workflows/flutter_build.yml`, Flutter **3.47.7**): analyze → UI audit →
unit/widget tests (`test` job), then `build`/`build_web`. E2E is **skipped by default** —
the `integration_test` job runs only on a manual `workflow_dispatch` with
`run_integration_tests: true` (live accounts via the four secrets). When opted in it still
gates: `build`/`build_web` use an explicit status guard (success-or-skipped), so a failing
E2E opt-in blocks the release while a skipped one proceeds. Integration tests and release
builds never run on PRs (E2E mutates the shared accounts), so a green PR check = analyze +
UI audit + unit tests. On merge to `master`, CI bumps `pubspec.yaml` to `2.0.<run_number>`,
updates `app_version.json` + the README download link, creates signed release
`v2.0.<run_number>`, and deploys web to GitHub Pages under `/WealthSync/`. Version/README
commit loops are avoided by skipping commits whose message starts with `CI:`. Every run
uploads a self-contained `report.html` artifact.

**Read `integration_test/test_helpers.dart` before writing a test.** Every test starts with
`launchAndSignIn(account: TestAccount.free|pro)` and wraps its body in
`testWidgetsWithScreenshots`. Helpers already absorb suite flakiness:
`handleSplashAndOnboarding`/`loginIfNeeded`, `waitForHome`/`waitFor`/`waitForGone`/
`waitForCheck`/`waitForController`, `tapNavTab` (auto-reveals the auto-hiding bottom bar),
`scrollUntilVisible`/`tapUntilMarker`/`tapWhenVisible`, `createTransaction`/
`createReceiveTransaction`, `ensureCategoryExists`/`seedCategory`, `clearAccountData`/
`resetTestData`, `probePro`/`assertUpgradeScreen`, `dismissDialogs`, `pumpAndSettleSafe`/
`pumpReal`, `sweepAssetEntry`. Hand-rolled pumps are the main source of new flakes.

Gotchas:

1. **Dart-defines are required** or auth fails with `[firebase_auth/channel-error]`
   ("Given String is empty or null"). `test_credentials.dart` uses `String.fromEnvironment`
   with empty defaults on purpose.
2. **Two accounts, never shared** — `TEST_*` is FREE, `PRO_TEST_*` is PRO.
   `ensureAccountState()` force-resets the free account to Free each launch and fails loudly
   if the Pro account doesn't report Pro (configure it in the console; the app cannot
   self-grant Pro). Free-path assertions (`'Budgeting'`, `'Upgrade to Pro'`, `'Monthly'`)
   only work against the free account; a subscribed-Pro account shows the management view
   (`'You are a Pro Member!'`, `'Renews on:'`) — `subscription_screen_test` asserts
   accordingly and never taps "Cancel Plan". The *script* selects accounts: `PRO_FILES` in
   `tool/run_integration_tests.sh` lists the 6 Pro files (`subscription_flow_test
   budget_categories_test goals_challenges_test lent_money_split_bill_test
   subscription_screen_test pro_features_test`) — a new Pro file missing from it runs
   against the free account and fails on paywall assertions.
3. **`createTransaction` waits for open AND pop** — after submit the screen lingers ~700 ms
   for the confetti celebration, and 'Total Balance' already exists in the offstage home
   route below, so `waitForHome` alone races into the next tap.
4. **Decorative blobs must not block taps** — the balance-card gradient circles are wrapped
   in `IgnorePointer`; they overlap Send/Receive once the streak banner grows the card.
5. **`_InviteFriendsCard`'s listener needs an `onError`** — the `users/{email}` snapshots
   stream errors with permission-denied after sign-out; without it the settings sign-out
   test fails on an unhandled exception (`settings.dart`).
6. **Data-dependent analytics markers** — 'Monthly Trend' only renders with ≥2 months
   ('Current Period' otherwise); 'Expense Breakdown' needs non-zero expenses.
   `analytics_reports_test.dart` seeds an expense + income and accepts either trend title.
7. **`flutter test` uninstalls the app after integration runs** (the Flutter tool's
   `--uninstall` defaults true), wiping the cache that holds screenshots. Always pass
   `--no-uninstall` (CI does). Per-file reinstalls use `adb install -r`, so screenshots
   accumulate while the app stays installed.
8. **`testWidgetsWithScreenshots` auto-captures screenshots** — success writes
   `result_<name>.png` to `<app cache>/screenshots/`, failure `failure_<name>.png` (error
   rethrown so the test still fails). Capture is engine-first (`layer.toImage()` — no
   `convertFlutterSurfaceToImage()` surface swap, which stresses the emulator's gfxstream
   ColorBuffer path), falling back to `binding.takeScreenshot()`. `generate_test_report.dart`
   embeds them base64 into `report.html`; new tests must keep using the wrapper. A FAIL row
   with no error text is labeled **HOST LOST** — the emulator/adb dropped mid-test (infra,
   never an assertion).
9. **Emulator dies from host-GL accumulation across app launches — restart between files.**
   The death is tied to the SECOND app launch: the first file survives ~11 min, the second
   dies ~7 min in. `-gpu guest` does NOT help (API 34 google_apis image falls back to host
   `lavapipe`). Fix: `restart_emulator()` in `tool/run_integration_tests.sh` boots a fresh
   emulator before every file after the first. `recover_device()` only helps an adb wedge;
   after it fails the script tries a full restart and only gives up (setting `EMULATOR_DEAD`)
   when that fails. Editing that script? It runs under `set -e` — capture `run_file` exit
   codes with `cmd || RC=$?`, NEVER a bare `cmd` + `RC=$?` (a failing bare call kills the
   recovery path).

## UI Copy / Revamp Audit

- When restyling a screen, move copy that integration tests assert on into
  `lib/Config/app_strings.dart` in the same change. Tests must assert `find.text(AppStrings.x)`
  — never re-type the literal — so copy stays compile-time safe on both sides. Data-dependent
  literals (amounts, counts, plan prices) stay inline.
- **A section title must describe where its tap goes.** The home section once rendered
  `quickSend` ("Quick Send") while `onTap` pushed `CategoriesHistoryScreen`; it now uses
  `AppStrings.categoryHistoryTitle` ("Category History"), and `SectionTitle`'s trailing link
  is `AppStrings.viewAll`. Check the destination before picking a key — a title reused from
  a different feature is how that happened.
- `tool/check_ui_strings.sh --strict` (CI, after analyze) tracks mechanical design-debt caps
  (raw `Color(0x…)`, `GlassContainer`, gradients, `BackdropFilter`) in
  `tool/revamp_baseline.env`. Lower caps after each wave; never raise.
- Design tokens live in `lib/Components/colors.dart`: `AppColors` (indigo `primary`
  `0xFF4F46E5`, zinc neutrals, `success`/`error`/`warning`), `AppRadius`, `AppShadows`,
  `chartSeries`. Pre-revamp brand hexes (cyan `0xFF00E5FF`, purple `0xFF6C63FF`, navy
  `0xFF1A1A2E`, mint `0xFF69F0AE`, pink `0xFFFF2975`) are fully rebranded — never
  reintroduce them. Category data colors (Material palette, seeded `0xFFFF7043`) stay inline.
