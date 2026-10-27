# AGENTS.md

Critical rules for this Flutter + GetX + Firebase app. Package name is
`money_control` (used in imports). Read the section matching your task; the
gotchas below each encode a bug that already shipped once.

## Commands

```bash
flutter pub get
flutter analyze --no-fatal-infos   # CI gate: warnings are fatal, infos are not
tool/check_ui_strings.sh               # UI design-debt audit: report only (executable bit set)
bash tool/check_ui_strings.sh --strict # fail if debts exceed tool/revamp_baseline.env caps
flutter test                       # unit/widget tests ONLY (test/); integration tests never run here
flutter test test/<file>_test.dart # single file
bash tool/run_integration_tests.sh # canonical E2E runner: whole suite, internally one file at a time, fresh emulator per file (needs env creds + booted emulator-5554; `E2E_FILES="a_test.dart b_test.dart"` runs a subset — that is how CI gates pushes; single-file runs use the flutter test block below)
bash tool/rules_tests/run.sh       # Firestore + Storage rules against the emulators (needs Node 24.12+ and JDK 21+; `npm ci` on first run)
bash tool/smoke_release_apk.sh     # installs + launches a release APK on emulator-5554 (R8/startup-crash gate)
flutter gen-l10n                   # after editing lib/l10n/*.arb (l10n.yaml + generate: true)
flutter run
flutter build apk --release
flutter build appbundle --release
flutter build web --release --base-href /WealthSync/   # GitHub Pages deploy
```

**Pre-commit gate (CI's `test` job, in order):** `flutter analyze --no-fatal-infos` →
`bash tool/check_ui_strings.sh --strict` → `flutter test` → `flutter build web --release`
(dart2js check, every event). All four must pass. A second CI job, `rules`, runs
`bash tool/rules_tests/run.sh` and is required before any release build.
(`run_integration_tests.sh` is mode 644 and always invoked as `bash …`; `tool/smoke_release_apk.sh`
is invoked as `bash …` for the same reason. `tool/rules_tests/run.sh` bootstraps its own
`npm ci`.) CI runs Flutter **3.47.7**; `pubspec.yaml` declares `sdk: ^3.9.2`.

**The web compile check is now in the `test` job, not only in `build_web`** — `flutter analyze`
and `flutter test` both run against the VM, and dart2js is stricter than the analyzer in a few
places. A type error that passes the first three can still fail the web build (see the
`recordError`/`Map<String, Object?>` note below for a shipped example), so PRs compile the web
release build too. Run `flutter build web --release` locally before pushing any change to a
shared signature or a service that web compiles.

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
| `test/` | unit/widget tests. Contract tests guarding silent failures: `feature_flags_test`, `feature_gate_test`, `toggle_gate_test`, `background_flags_test`, `firestore_indexes_test`, `platform_contract_test`, `referral_reward_math_test`, `balance_overlay_math_test`, `early_return_guard_test`, `analysis_fixed_classification_test`, `spending_filter_test`, `category_treatment_test` |
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
- **A deletion that dies after the data is gone is resumed on the next sign-in.**
  `deleteAccount` writes `users/{email}/meta/deletion` (`{uid, startedAt}`) *after* the 34
  subcollections are empty and *before* the profile/auth user are removed — a process kill
  in between otherwise leaves the account signed in with no data and no way to finish the
  request it was told was complete. `AuthController.resumeInterruptedDeletion` runs from
  `main.dart`'s `_handleAuthChange` (native only, before the phase-2 registrations) and
  finishes it: release the code, delete the profile, delete the auth user, purge the sealed
  device copies, sign out (the auth stream then runs the single teardown list).
  Two ordering rules: the marker is written **after** the wipe (written first, a resume
  would delete an account whose data was still intact), and it is a **tombstone** — Firestore
  does not cascade a document delete into subcollections, so it outlives the profile, and
  `isDeletionMarkerFor` refuses a marker whose `uid` is not the signed-in account's
  (delete → sign up again with the same email must never erase the new account; that stale
  marker is deleted instead). Rules open only the literal `meta/deletion` path, owner-only,
  uid-bound, write-once (no update branch) — pinned by `tool/rules_tests/run.js` and
  `test/deletion_resume_test.dart`. `meta` is deliberately NOT in `UserService.subcollections`
  (the marker must survive the wipe, and it is not user data to export).
- **Sign-up is serialized with the auth stream.** `createUserWithEmailAndPassword`
  signs in immediately → `_handleAuthChange` signs unverified accounts back out
  mid-write. `signup.dart` sets `AuthController.signupInProgress`, checked at the
  very top of `_handleAuthChange` **before** the `_handledUid` dedupe (so the
  emission isn't recorded as handled), and does its own `await signOut()` at the end.
- **One post-sign-in destination.** `AuthController.routeAfterSignIn(user)` is the only place a
  completed sign-in chooses `MainShell` vs `OnboardingScreen`, and it asks
  `OnboardingStatus.isOnboardedFor` — the same check `main.dart`'s root `FutureBuilder` uses.
  Both login paths used to hardcode `MainShell` (so a brand-new account skipped setup and then
  met it on the next cold start) and sign-up hardcoded `OnboardingScreen` (so an existing
  account tapping "Sign up with Google" was re-onboarded — and onboarding merge-writes
  `monthly_budget` to 0). The Google profile write is gated on
  `additionalUserInfo?.isNewUser`: `createdAt`/`provider` are otherwise rewritten for a
  returning account (`googleSignupProfileFields` in `lib/Utils/`, pure and unit-tested).
  `test/onboarding_routing_test.dart` scans for a route around it, and the E2E helper
  `completeOnboardingIfNeeded` finishes the screen a genuinely new account lands on.
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

**Both free-Pro paths are bounded by `firestore.rules`, not by the client.** Spark has
no Cloud Function, so the rules are the only enforcement that survives a modified APK:
`isTrialStart` (7 days, only when `trialEndDate` is absent — the same signal the UI
derives `trialUsed` from), `isTrialShrink` (later `trialEndDate` only via a payout),
`isReferralApplication` (one 30-day month, code doc must exist and not be your own) and
`isClaimPayout` (the profile's `referralCredited` ledger must grow, each newly credited
uid must be a real claim, the ledger never shrinks, ≤30 days/claim). `isReferralReward`
— which let any signed-in user write `subscriptionStatus: 'pro'` into any account with a
`referralCode` — is deleted; a payout is a `trialEndDate` grant on the referrer's own
doc. `isProfileErase` is the single write allowed to *remove* the gated fields (the GDPR
reset); allowing a plain removal would reset `trialUsed` for another free trial.
**`allow update` ORs its branches, so every branch must check ownership and its own
field set itself** — `isTrialStart` shipped without either and was a write-anything
bypass on any profile that had no `trialEndDate` yet; `isProfileErase`, which may touch
any field, must also refuse to *set* a gated value back (it could mint `isAdmin`).
Both are pinned by `tool/rules_tests/run.js` and `test/referral_test.dart`.
`tool/rules_tests/run.js` pins all of it behaviourally (27 entitlement checks of 48) and
`test/referral_test.dart` pins the rules text. Residual risk (a forged `purchaseToken`
passes `validProClaim`; delete+recreate resets the ledger, still capped at 45 days) is
recorded in `docs/THREAT_MODEL_entitlement.md` — read it before "fixing" a bound.

Codes are random 8 chars from an alphabet without I/O/0/1 (`generateReferralCode()` takes
no arguments). They used to be `name[0:4] + uid[0:2]`, which made a code guessable from a
display name. A code doc stores `ownerUid` only — anyone who knows a code may read the
document, so `owner` (owner's email) leaked it; legacy docs still carry it and the rules
accept both shapes. Delete + GDPR erase release the code doc (it is top-level, so
`UserService.subcollections` never covered it).

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
early-return in privacy mode. The chips sit in a `Wrap` that **must stay inside a
`Flexible`**: a `Wrap` in a `Row` is laid out with unbounded width, so it can never wrap
and the header row overflows by 11 px on a 320dp-wide device (the only guard is the E2E
home screen, so a "harmless" layout tweak here fails the suite, not the analyzer).
`pendingSubscriptions` is the one recurring figure that
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

**Daily-limit category treatment (Auto / Fixed bill / Ignored)** — a per-category
override layered on the keyword classifier. One resolver, `resolveDailyLimitRole(
category, treatmentOverrides: …)` in `wealth_math.dart` (enum `DailyLimitRole {fixed,
variable, ignored}`), is the *only* way to decide a category's role; the override wins,
otherwise `isFixedExpenseCategory` decides, and a category is never silently ignored.
- **Persisted on the category doc**: `CategoryModel.treatmentOverride` (`'fixed'` |
  `'ignored'` | null = Auto), written by the "Daily limit treatment" chip row in
  `_CategoryDialog` (`category_management.dart`). `toMap()` always emits the key, so a
  reset back to Auto *clears* it (Firestore `.update()` with a null field). No
  rules/index/deploy change: `users/{email}/categories` is already owner-writable.
- **The override map** comes from `buildTreatmentOverrides(categories)` (name →
  lowercased+trimmed, Auto/blank skipped) — build it once per load and pass it down;
  `resolveDailyLimitRole` ALSO falls back to a case/space-insensitive scan of the keys,
  so a raw `"  sip "` key still matches. Normalise on **both** sides.
- **Every classification site must switch together**: `analysis.dart` (4 sites —
  current-month variable, today's fixed/ignored, fixed forecast, category insights) and
  `splitMonthlyExpenses()` (`spending_filter.dart`, 3-bucket `MonthlyExpenseSplit`).
  They are kept in sync by `test/analysis_fixed_classification_test.dart`, which now pins
  `resolveDailyLimitRole(` ≥3× in `analysis.dart` and in the filter — extending the split
  means adding a call site there too, else one bucket desyncs from the card's figure.
- `todayVariableSpent` subtracts **both** today's fixed *and* today's ignored;
  Category Insights renders an `ignored` category as **nothing** (an "on track"/"pending"
  frame would be a lie) — the heatmap `dailySpending` keeps showing ignored spend on
  purpose (it is real spend). The Other Items screen's collapsible sections are the
  drill-down: `discretionary` / `fixed` (bills) / `ignored` (not counted in limit), with
  a `feature_flags: category`-gated link into Category Management.

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
  `isComingSoon`/`isHidden`/`visibleToMe`/`setStatus`, `FeatureFlag.find`, `_flagHidden`,
  `_requireFeature`, `ComingSoonScreen.forFlag`, `featureKey:` and `FeatureSection([...])`
  call-sites, and fails if a key is never gated (and if a gate key is unregistered). So
  registering a key is not enough — wire its gate in the same change, add it to a group,
  and keep the test's 55-key list in sync. Gate with these keys as string literals.
- **Transport** (`lib/Services/feature_flag_service.dart`): native
  `.snapshots(includeMetadataChanges: true)` in `onInit`; **web 60s `.get()` poll** via
  `startPolling()` from `main.dart` after login (JS b815/ca9 constraint). Firestore
  wiring lives in protected `startRealtime()` so test fakes can `super.onInit()` +
  no-op it. `statusOf` must read `_status[key]`, not `_status.value[key]` (GetX 4.7.2
  marks `.value` `@protected`; `operator []` registers the Obx dependency the same).
  - **The native listener is auth-gated** (`lib/Utils/auth_gated_listener.dart`), and
    **both** `FeatureFlagService` and `PaymentConfigService` (same pattern, same file
    family) use it. Both are registered in **Phase 1**, before login, and `app_config`
    is `allow read: if request.auth != null` — so subscribing directly fired an
    unauthenticated read that Firestore denied as
    `Listen for Query(app_config/feature_flags) failed: PERMISSION_DENIED`, logged as
    `FeatureFlagService: using defaults (…)` on **every cold start**. It was harmless
    (caught, defaults to `enabled`, re-emits after login) but read like a failure in
    every log. Do **not** "simplify" it back to a bare `.snapshots()` subscribe, and do
    not move it to Phase 2 — the gate is what keeps the denied read from happening
    without touching the fragile web listener ordering (see the web-SDK note above).
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

## Observability (Analytics + Crashlytics)

`lib/Services/app_analytics.dart` is the **only** entry point for event logging and
non-fatal reporting. Do not call `FirebaseAnalytics`/`FirebaseCrashlytics` directly, and
never pass a bare event-name string — add it to `AnalyticsEvent` first. A typo'd name at a
call site (`paywall_view` vs `paywallView`) splits one funnel into two with no error
anywhere.

- **Two invariants it exists to enforce**: `log`/`recordError`/`setUserId` **never throw**
  (a failed diagnostic must not take down the flow that called it) and **never block**
  (fire-and-forget — no call site awaits them). Both are pinned by
  `test/app_analytics_test.dart`, including the `[core/no-app]` path where Firebase isn't
  initialised. `_sanitize` drops `null`/List/Map/Object params because the SDK throws on
  non-primitive values, and `log` is called from inside tap handlers.
- **`init` is gated on `!isTest`** in `main.dart` alongside the Crashlytics wiring, so
  integration tests never pollute the production funnel. `configureCollection()` sets
  `setCrashlyticsCollectionEnabled(!kDebugMode)` — a developer's hot-reload crash must not
  land in the release dashboard.
- **The user id is set per-uid in `_handleAuthChange`** (one place, covers every sign-in
  path including a restored cold-start session) and **cleared in
  `AuthController.disposeUserScopedState()`**. Do not add a second clear path — that list
  is the canonical teardown owner, and a duplicate list is exactly the drift bug that
  leaked `AuditController` state.
- **`feature_gate_hit` is the highest-value event**: it fires from the *tap* guards
  (`ensureFeatureVisible`/`ensureFeatureUsable` in `feature_gate.dart`), never from
  `visibleToMe` — which also runs during `build()` and would log a hit every frame a
  gated surface renders. It is the only signal for which of the 55 flags are dead weight.
- **Paywall telemetry lives in `SubscriptionScreen.initState`**, not at the ~8 call sites
  that navigate to it — new entry points can't forget it.

Caught errors do **not** reach Crashlytics by default: only uncaught framework/async
errors do (`FlutterError.onError`, `PlatformDispatcher.onError`). When adding a
`try/catch` around a write or a purchase, call `AppAnalytics.recordError(e, s, reason: …)`
alongside the `debugPrint` — otherwise it is invisible in release. Currently wired for
transaction writes (`transaction_repository`, incl. the offline-queue fallback) and IAP
failures.

**`recordError`'s `context` is `Map<String, Object?>` on purpose — keep it nullable.**
Most values you'd want to attach are nullable (`purchase.productID`, every Firestore
field), so a `Map<String, Object>` parameter forces a `!` at each call site. Nulls are
dropped by the method. This is not a style preference: narrowing it back to
`Map<String, Object>` **passes `flutter analyze` and then fails `flutter build web`** with
`A value of type 'String?' can't be assigned to a variable of type 'Object'` — dart2js
rejects what the analyzer accepts, and only the `build_web` CI job catches it. Pinned by
`test/app_analytics_test.dart`.

## Write Paths & Backups

`LocalBackupService.backupUserTransactions(email, reportErrors: false)` must run after
**every** transaction write, not just add/edit: `transaction_controller` (add/delete),
`edit_transaction`, `audit_controller` (sign fix), `import_service` (CSV bulk),
`sms_import_screen`, and `recurring_service` (`markAsPaid` + `processDuePayments`). The
coalescing throttle makes the extra calls free; a missing one leaves the mirror stale.
Same for `BudgetService.checkBudgetExceeded` on bulk imports (the add/edit screens raise
the alert, so a CSV/SMS import that blows a budget would otherwise stay silent). Only
check categories from **expense** rows.

**Both on-device copies are sealed with AES-GCM** (`lib/Services/backup_cipher.dart`): the
transaction mirror (`LocalBackupService`) and the daily whole-account snapshot
(`FullBackupService`), because the privacy policy promised encryption while they sat in
the app sandbox as plain JSON. The key is generated on the device and kept in the
platform keystore via `flutter_secure_storage`; a missing keystore **falls back to
plaintext rather than to no backup** (an unreadable backup is the failure this whole area
exists to prevent), and a sealed payload that will not authenticate reads as "no backup",
never as a crash. Do not "simplify" the fallback away. `open()` also passes legacy
plaintext through, so an existing mirror keeps restoring and is re-sealed on the next
write. A file the user downloads is deliberately plaintext — it leaves the app sandbox and they
are expected to open it. That is `FullBackupService.download`, used by both the backup
screen and the privacy screen's "Download My Data" (which captures the same complete
archive: the old transactions-only `exportBackupFile` was neither complete nor reachable
from outside the sandbox, so it is gone).

**The daily snapshot keeps one dated safety copy for 7 days** (`safetyCopyTtl`). Larger-
wins protects against shrinkage, but not against a live file that is corrupt or
implausibly *bigger* (a bad restore that duplicated every document); when the live file
replaces an older one, the replaced bytes are copied verbatim (still in their envelope) to
`full_<safe>_<yyyy-MM-dd>.json`, and copies older than a week are pruned. `readLocalSnapshot`
falls back to the newest safety copy when the live file will not parse, so one bad write
cannot hide a week of good snapshots. Account deletion and the GDPR erase call
`FullBackupService.clearLocalSnapshot()` + `LocalBackupService.clearUserBackup()` — a full
copy of every collection surviving "delete all my data" would defeat the request.

It is a **FULL collection read** (`col.get(Source.server)` over every `transactions`
doc, ~260 KB for 709 items), so it coalesces: one in-flight run per account,
`minInterval` (30 s) between successful runs, a `_dirty` flag, and a trailing `Timer`
flushing writes inside the window. Callers get "scheduled", not "read". Two rules:
`reportErrors: false` on automatic callers (a red "Backup failed" snackbar after a
*successful* write reads as data loss, and `ErrorHandler._show` clears the confirmation
snackbar); `force: true` from the explicit Settings action (`data_support_settings.dart`)
so it really reads. The read stays un-ordered/server-sourced — do NOT add the listener's
`orderBy('createdAt')` for a cache hit (docs missing that field drop out, and this is the
recovery path). Test seams: `fetchOverride`/`writeOverride`/`readOverride` +
`resetSchedulingForTest()` (`test/local_backup_coalesce_test.dart`). Those three
short-circuit *before* `BackupCipher`, so they cannot see the envelope —
`backupDirOverride` keeps the real file path and is what
`test/local_backup_encryption_test.dart` asserts on (sealed mirror, sealed preserved
slot, legacy plaintext still readable, wrong-key payload reads as "no backup").

**The mirror must never destroy the pre-deletion snapshot.** The automatic backup
*overwrites* the only local copy it keeps — harmless while the data only grows, but
exactly wrong after a mass deletion: the next write replaces the pre-deletion history
with the emptied one, and the recovery path is gone. That is the sequence that lost
791 live transactions on 2026-10-21 (account wiped → next write fired the backup →
the only local copy was overwritten with the empty collection). So a backup holding
**fewer** documents than the one on disk preserves the previous snapshot in a second
slot (`backup preserved_<safe-email>` — the space makes the key un-collidable with a
real account's key, since a sanitized email never contains one), and the preserved
copy is only ever replaced by a **larger** one. `restoreUserTransactions` takes the
larger of the two slots, and `hasUserBackup` checks both — otherwise the UI reported
"No local backup found. Tap 'Backup Data' first." while the data sat on the device.
Equal counts *refresh* (the account may have swapped one transaction for another).
Pinned by `test/local_backup_preserve_test.dart`.

## Full Backup (download / restore)

`FullBackupService` + `BackupArchive` are the user-held safety net. Scope =
`UserService.subcollections` (the same list the account-deletion flow uses, so backup
and delete cannot drift) + `users/{email}` profile + `wealth/portfolio`.

- **Capture** reads every collection; one failed read is **surfaced**, not swallowed
  (`onCollectionError`), because an incomplete backup that reports success is the
  failure mode this feature exists to prevent.
- **The format guard is strict**: `fileType` + `formatVersion` must match, or the file
  is refused with an actionable `BackupFormatException` — never "restored 0 documents"
  and reported as a success. An archive newer than the build is refused too.
- **Firestore types survive JSON** via tagged envelopes (`__ts__` / `__geo__` / `__ref__`).
  A bare ISO string is revived to a Timestamp only in a **date-named field** (the
  allow/deny-list model inherited from `LocalBackupService`) — the blanket
  "any ISO-looking string" rule destroyed notes like "2026-01-15T10:00 was the party".
- **Restore is merge-only** (`SetOptions(merge: true)`, original doc ids): idempotent,
  and it can never delete what currently exists. Per-collection failures are reported.
- **The restore writes into the account signed in NOW**, not the one the archive was
  taken from (`_currentUserEmail()`; the `signedInEmailOverride` seam makes it
  testable). That is what lets a user rebuild a deleted account — signing up again
  and restoring their old file. Writing to the *archived* address is denied by
  `firestore.rules` (an owner may only write their own document), so the restore
  would silently write nothing.
- **Identity is remapped onto the signed-in account, never guessed.** Format 2 archives
  record the uid they were taken from (`BackupArchive.uid`, falling back to the archived
  profile's `uid` for a format-1 file); `remapIdentityForRestore` rewrites `uid`, and
  `senderId`/`recipientId` **only when the value is the archived owner's**, onto the current
  account. Two failures it exists to prevent: leaving the old uid behind makes every
  uid-filtered query (sent/received, analytics, split bills) skip the restored history — the
  whole point of rebuilding a deleted account; rewriting ids blindly would move a split-bill
  friend's transaction onto the restoring account. No recorded uid ⇒ ids are left alone.
  `currentFormatVersion` is 2 so a build that predates the rewrite refuses the file rather
  than restoring history it cannot re-identify. Pinned by
  `test/backup_identity_remap_test.dart`.
- **The profile restore strips the server-authoritative fields**
  (`BackupArchive.serverAuthoritativeProfileFields`: `subscriptionStatus`, `isPro`,
  `trialEndDate`, `trialUsed`, `planType`, `expiryDate`, `purchaseToken`, `isAdmin`,
  `referredBy`, `referralCount`). Two reasons: `isOwnerUpdate` refuses most of them
  on an owner write — so including them fails the **whole** profile write and the user
  loses their name and phone too — and where the rules allow it, restoring them lets a
  stale backup **regress a paying user's Pro status**. The live values survive because
  the write is a merge.
- **The capture redacts the purchase credential** (`BackupArchive.credentialProfileFields`
  = `purchaseToken`). The file is meant to be emailed around or dropped in a cloud
  drive; a purchase token in it is a purchase token in someone's inbox. The
  entitlement fields are *kept* in the file as an honest record of the account — they
  are simply never written back.
- **A Firestore batch is atomic, so a rejected batch falls back to per-document
  writes.** One document the rules refuse would otherwise fail all 400 in the batch.
  The fallback runs only for a *document rejection* (`_documentRejectionCodes`); a
  transient failure (`unavailable`) is not retried 400 times over. Only documents the
  server actually accepted are counted — a failed batch must never be reported as
  "restored", which is the false success this feature exists to prevent.
- **The archive's JSON encoding never throws** (`BackupArchive.toJson` uses
  `jsonSafeValue` as the encoder's `toEncodable`; `FullBackupService._jsonSafe`
  delegates to it so the two envelope formats cannot drift). A backup that fails to
  write is the one failure this feature cannot have.
- **Automatic daily snapshot** (`background_worker.dart` `_checkDailySnapshot`): a full
  copy of the whole account on the device, so protection works for a user who never
  opens the backup screen. The schedule is the pure helper `shouldRunDailySnapshot`
  (after 22:00, once per calendar day, a failed run retried at most hourly — the
  worker wakes every 15 min, so an unguarded retry would re-read every collection 96×
  a day). Honours the `full_backup` kill-switch like every other background task.
  The snapshot uses the same shrink-guard: a smaller snapshot is **rejected**, so the
  day a deletion is noticed does not destroy the last complete copy.
- Feature flag `full_backup` (group "Data Management"); analytics events
  `full_backup_downloaded` / `full_backup_restored` via `AppAnalytics`.
- Tests: `test/full_backup_service_test.dart` (format guard, type round-trip,
  shrink-guard), `test/backup_strings_contract_test.dart` (AppStrings ↔ ARB pairing),
  `integration_test/full_backup_test.dart` (live capture → delete → restore, plus the
  device snapshot). `tool/check_ui_strings.sh` counts integration-test literals, so
  copy asserted by a test belongs in `lib/Config/app_strings.dart`.

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
25. **Verify with a freshly built APK, not the one already on the device.** The installed
    `app-release.apk` is whatever was built last; a code change requires
    `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
    (~126 MB) first. Installing over a higher `versionCode` fails
    `INSTALL_FAILED_VERSION_DOWNGRADE`, so `adb uninstall app.vercel.justaman045.money_control`
    then `adb install -r` — that wipes the login session, so live checks need credentials
    or a fresh sign-in. Also: `android/app/google-services.json` is gitignored (drop the
    Firebase Console file in locally) and Android tools are **not on PATH** —
    `export PATH="$HOME/Android/Sdk/platform-tools:$HOME/.sdks/flutter/bin:$PATH"` first.
26. **Let the emulator boot from a human session; agent-initiated `-avd` boots segfault.**
    `nohup`/`setsid emulator -avd … -gpu swiftshader_indirect|off|guest` died right after
    GPU init ("dumped core"), and `multiinstance.lock` / `hardware-qemu.ini.lock` /
    `/run/user/1000/avd/running/*` go stale after those crashes. Check
    `adb devices` + `adb shell getprop sys.boot_completed` == 1 before installing, and
    clear the stale locks if `emulator-5554` refuses to appear.
27. **A `push` rejected with "fetch first" means someone (CI's version bumps) moved
    `master`** — `git pull --rebase` fails while the tree is dirty, so `git stash` →
    rebase → `stash pop`, and expect `android/build/**` churn to leave a
    `problems-report.html` unstaged. Never build or analyze mid-rebase: Gradle surfaces a
    bare `1 error` with no diagnostic above the tail of a truncated build log, so a failed
    build's cause only shows up on a clean tree.
28. **An async prefill must never overwrite what the user typed.** `edit_profile.dart`'s
    `initState` Firestore read can land *after* the user starts typing on a slow connection;
    assigning the controllers there discarded the edit and the following save wrote the old
    value back, so a rename silently did nothing (the E2E rename flow caught it, and it had
    never passed in CI). Prefill through `_prefill`, which skips any controller in `_edited`.
    The same form must also never write `age: null` — `buildProfileUpdate`
    (`lib/Utils/profile_update.dart`, pinned by `test/profile_update_test.dart`) omits
    `dob`/`age` unless a date of birth is set, because the Wealth Builder's age gate
    (`main_shell.dart` `_checkAgeGate`) refuses to open without an age, so a rename used to
    lock the user out of the Wealth tab.

## Platform-Specific

- **Google Sign-In**: pinned to `^6.2.2`. Do NOT upgrade to v7+ — `signIn()` was replaced
  with a stream-based API that has a race condition.
- **One client, and it deliberately signs out first.** `lib/Services/google_auth_service.dart`
  owns the only `GoogleSignIn` instance. `signIn()` dispatches with `canSkipCall: true`, so
  with a cached `_currentUser` it returns that same account **without any UI** (Android), and
  the web client re-authenticates the remembered user with `prompt: ''` + `login_hint`
  instead of `select_account`. That combination is why the app appeared to always sign in
  the first Google account. `obtainCredential()` therefore calls `signOut()` before
  `signIn()` on every tap — removing it silently restores the cached-account behaviour.
  A second `GoogleSignIn` instance (sign-up used to build its own) has a second cache and is
  cleared by a different `signOut()`. `test/google_auth_service_test.dart` pins the single
  instantiation, the `signOut()` → `signIn()` order, and that neither screen builds a client.
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
  `home_widget`, `share_plus`, `shared_preferences_android`,
  `workmanager_android`, `package_info_plus`, `mobile_scanner`) log a migration warning.
  Track upstream; no action until Flutter drops KGP support.
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
- **Release ships exactly ONE universal APK.** `build` runs `flutter build apk --release`
  (universal `app-release.apk`), an `apksigner verify` assertion step, then uploads that
  single file (artifact `apk`, release asset `app-release.apk`); the README links
  `releases/latest/download/app-release.apk`. **Split-per-ABI builds were removed on
  purpose — do not re-add `--split-per-abi`.** Two reproduced failures came from them:
  (1) an ABI split installs only on a device carrying that ABI, so the arm64 split failed on
  32-bit/x86 phones ("app not meant for this device") and the x86_64 split can never install
  on any phone; (2) Flutter overrides a split's versionCode to `abiVersion * 1000 +
  versionCode` (`FlutterPlugin.kt`; arm64 split = 2169 vs universal 169), so anyone who
  side-loaded the arm64 split could never take the in-app update — the updater downloads the
  *universal* APK and Android rejects the lower versionCode with
  `INSTALL_FAILED_VERSION_DOWNGRADE` (reproduced on the emulator). One universal APK installs
  everywhere and carries the versionCode the updater downloads.
  **`enableV1Signing` is a silent no-op on AGP 9.1.0** — both CI and local release APKs report
  `Verified using v1 scheme (JAR signing): false` even though `META-INF/CERT.SF`/`CERT.RSA`
  exist (23 ML Kit/cupertino asset entries are omitted from the JAR manifest, invalidating
  v1). This does **not** block installs at `minSdk 24`+ (Android validates v2/v3 and ignores
  v1 — a locally built APK installs fine on SDK 37), but the `apksigner verify` CI step stays
  as the guard against a genuinely broken signature.
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

`firestore.rules`, `firestore.indexes.json` and `storage.rules` are **not** deployed by CI
(no credentials in the repo). Deploy by hand when any of them changes:

```bash
firebase login
firebase use moneycontroljustaman045           # .firebaserc is tracked
firebase deploy --only firestore:rules,firestore:indexes --dry-run   # always first
firebase deploy --only firestore:rules,firestore:indexes
# Storage is NOT deployed: the project is on Spark, where Cloud Storage cannot
# be provisioned, so `--only storage` always aborts with "Firebase Storage has
# not been set up" — adding it aborts the Firestore rules deploy with it.
```

The dry run is a real rules compiler (`is Map` fails; the compiler wants lowercase `map`,
`timestamp`, `list`, `number`, …), but it proves only that the file *parses*. CI's `rules`
job is the behavioural check: `tool/rules_tests/run.sh` loads both rule sets into the
Firestore/Storage emulators (which compiles them) and runs
`tool/rules_tests/run.js` against owner isolation, malformed-transaction rejection,
self-admin/self-pro escalation, and profile-picture ownership + size/content-type limits.
Dart tests (`test/storage_rules_test.dart`, the rules sections of
`test/firestore_indexes_test.dart`) assert *source text* only — they cannot catch a
rules-language error. `firebase.json` and `.firebaserc` are tracked deliberately (public
projectId/appId only; `firebase.json` also carries the `storage` entry and the emulator
ports the rules job uses).

**Storage rules are owner-only and UID-scoped** (`users/{uid}/profile.jpg`): `read`/`delete`
for the owner, `create`/`update` additionally require an `image/*` content type, `< 5 MB`,
and that exact filename. There is no other writable object — the user-facing backup archive
is a *downloaded file*, never uploaded to Storage.
**Cloud Storage is not provisioned and cannot be on this project.** New Firebase projects
get Storage only on the Blaze plan and this one stays on Spark, so
`moneycontroljustaman045.firebasestorage.app` has no bucket. The profile-picture upload was
therefore **removed** — `pickAndUploadImage`, the camera badge on Edit Profile, and the
`firebase_storage` dependency are all gone; `AppAvatar` shows the sign-in provider's
`photoURL` (Google-hosted) or `assets/profile.png`. `storage.rules` and its emulator tests
stay as a dormant contract (they cost nothing and are enforced the day a Blaze upgrade
creates the bucket), but the CI `deploy_firebase` job deploys **Firestore only** —
`test/ci_workflow_contract_test.dart` fails if `,storage` is added back, because that abort
takes the Firestore rules with it.

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

CI (`.github/workflows/flutter_build.yml`, Flutter **3.47.7**):

| Job | Runs on | What it proves |
|-----|---------|----------------|
| `test` | every push/PR | analyze → UI audit → unit/widget tests → **web release compile** (dart2js). PRs get the same gate as master. |
| `rules` | every push/PR | `tool/rules_tests/run.sh` boots the Firestore + Storage emulators, compiles both rule sets, and runs `tool/rules_tests/run.js`. |
| `integration_test` | master push (critical subset), nightly `schedule` or `workflow_dispatch` with `run_integration_tests: true` (full suite) | `bash tool/run_integration_tests.sh`. Never on PRs — it mutates the shared accounts. |
| `deploy_firebase` | `workflow_dispatch` with `deploy_firebase: true`, on `master` only | `--dry-run` compile then `firebase deploy --only firestore:rules,firestore:indexes` using the `FIREBASE_TOKEN` secret. Never runs on a push; Storage is excluded because Spark cannot provision a bucket. |
| `build` | master push / dispatch (on `master`) | release AAB + **one universal APK**, `apksigner verify`, plus assertions that `versionName`/`versionCode` match `2.0.<run_number>`/`<run_number>` and that the APK still carries `arm64-v8a` + `armeabi-v7a` + `x86_64`. Uploads artifacts, publishes nothing. |
| `android_smoke` | after `build` | `tool/smoke_release_apk.sh` installs that exact APK on an emulator and fails on a missing pid, a startup `FATAL EXCEPTION`, or an ANR — the R8-only failure mode no debug test can see. |
| `release` | after `build` + `android_smoke` | creates `v2.0.<run_number>` with AAB/APK/`SHA256SUMS`, **then** commits `pubspec.yaml` + `app_version.json` as one `CI:` commit. |
| `build_web` | master push / dispatch (on `master`) | `flutter build web --release --base-href /WealthSync/` → GitHub Pages. |

E2E runs on **every master push** as a four-file release-critical subset
(`E2E_FILES` — settings, full backup, data management, transaction management,
~35 min) and as the **full 25-file suite** nightly/on dispatch. PRs still skip it
(no emulator cost, no account mutation). `build`/`release`/`build_web` carry an
explicit `success`-or-`skipped` guard, so the subset really gates a release while
a PR stays fast. The `schedule` run never publishes — all three publishing jobs
exclude `github.event_name == 'schedule'`.

Production rules deploy is a **dispatch-only** job (`deploy_firebase`) so a push
can never mutate production security rules: it runs the published `--dry-run`
compile first, then deploys. It needs the `FIREBASE_TOKEN` secret (`firebase
login:ci`); without it the job fails fast with an actionable message.

Two ordering rules the pipeline depends on:

- **The version is stamped before the build but committed after the smoke test.** A failed
  build can no longer leave `master` claiming a version that never shipped, and a release
  cannot exist for an APK that was never launched.
- **The version commit is one commit, made last.** Two hand-maintained pushes were two
  chances to race a merge; the push loop rebases on `origin/master` and retries three times.

`paths-ignore` covers `pubspec.yaml`, `app_version.json` and `README.md`, so the `CI:` commit
cannot re-trigger a release cycle. A real dependency edit still runs the build because it
also rewrites the tracked `pubspec.lock`. The release-commit step also carries a backstop
guard keyed on the **committer identity** (`github.event.head_commit.committer.name`), not on
the commit message: Actions' `contains()`/`startsWith()` are case-**in**sensitive, so a
`!contains(head_commit.message, 'CI:')` guard is false for every commit titled `ci: …`. That
exact mistake skipped the version bump for `v2.0.200` — the release published while
`app_version.json` stayed one version behind.

Workflow-level `permissions` is `contents: read`; only `release` and `build_web` opt into
`contents: write` (the Pages API and OIDC grants the workflow used to request globally were
never used by `peaceiris/actions-gh-pages`). Secrets are never interpolated into a `run:`
script: `GOOGLE_SERVICES_JSON`, `UPLOAD_KEYSTORE` and the store credentials are forwarded
through `env:` and read as shell variables (the google-services write + NDK install live in
`.github/actions/android-setup`, shared by `build` and `integration_test`, and fail fast with
an actionable message when a secret is missing). `test`/`build_web` never touch the Android
Firebase config at all.

Every run uploads a self-contained `report.html` artifact. `test/ci_workflow_contract_test.dart`
pins this structure (job set, the `needs:` edges that gate publishing, least-privilege
permissions, the env-only secret handling), so dropping a guard is a red unit test rather
than a silent release of an unverified APK.

**Read `integration_test/test_helpers.dart` before writing a test.** Every test starts with
`launchAndSignIn(account: TestAccount.free|pro)` and wraps its body in
`testWidgetsWithScreenshots`. Helpers already absorb suite flakiness:
`handleSplashAndOnboarding`/`loginIfNeeded` (plus `completeOnboardingIfNeeded`, which
finishes the **post-login** setup screen — a brand-new fixture account lands there instead
of home, and the pre-login walkthrough is a different screen), `waitForHome`/`waitFor`/`waitForGone`/
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
10. **A freshly booted emulator can report `sys.boot_completed=1` while DNS is still dead.**
   Every Firebase call then fails with
   `UnknownHostException: Unable to resolve host "firestore.googleapis.com"`, surfacing as
   `AuthErrorCodes.NETWORK_REQUEST_FAILED` on the login call — which looks exactly like an
   auth bug but is pure infrastructure. `ensure_connectivity()` in
   `tool/run_integration_tests.sh` now gates each file on
   `adb shell ping -c <hostname>` (a hostname, not an IP: plain IP reachability succeeds
   while DNS is still broken), re-enables data and warns rather than skipping. When login
   fails on a local `flutter run`, check `adb shell ping firestore.googleapis.com` **first**
   — this is the most common false alarm.
11. **The account wipe is opt-in — `--dart-define=E2E_ALLOW_WIPE=true`.** `clearAccountData`
    used to run on every `launchAndSignIn`, deleting all 34 subcollections (transactions,
    categories, budgets, goals, loans, recurring payments, lent money, challenges and all
    26 wealth collections) of whichever account the file launched against. The suite also
    runs against the **Pro** account, which is a real, hand-curated account rather than a
    disposable fixture — so the same call that reset a test fixture destroyed 791 live
    transactions on 2026-10-21, with no recovery path (Firestore has no client-side
    backup; scheduled backup/PITR is a paid-tier feature and is not retro-enableable;
    the on-device cache prunes server-deleted documents to path-only stubs).
    `kAllowAccountWipe` now defaults to **off**; CI opts in through the workflow env
    (its accounts are disposable) and `tool/run_integration_tests.sh` defaults to **off**
    as well. Pointing the runner at a real account must never wipe it — if a test needs
    a clean slate, seed its own data instead.
12. **The Wealth tab is age-gated, so the harness seeds an age.** `main_shell.dart`
    `_checkAgeGate` shows a "Setup Required" dialog and refuses to switch tabs when the
    profile has no `age`/`dob`; the wipe does not touch the profile, and the CI fixtures
    predate the gate — six wealth files and the tab tour timed out waiting for "Wealth
    Builder" on the first nightly run. `launchAndSignIn` now calls `ensureProfileAge`
    (a rule-legal owner write of `age: 30` when neither is stored). Keep it there: any new
    wealth test depends on it, and `edit_profile_test` must not clear the field it seeds.
13. **Assertions must not depend on scroll position or on another file's leftovers.**
    `edit_profile_test` asserted the typed name through `find.text` after scrolling to the
    save button; it now asserts the persisted `users/{email}` doc (the real contract) and
    waits for the async prefill before typing. Theme is a **device-level** preference that
    survives sign-out and the wipe, so `misc_settings_test` normalises dark mode before
    asserting the toggle instead of assuming light. The subscriptions screen renders
    "Add Subscription" twice while the list is empty (FAB + empty-state action) — tap
    `find.widgetWithText(FloatingActionButton, …)`, not the ambiguous text.

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
