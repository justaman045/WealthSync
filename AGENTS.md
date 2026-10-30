# AGENTS.md

WealthSync (package `money_control`): Flutter + GetX + Firebase personal-finance app.
MVC-Service-Repository. Product context is in `README.md`; this file is the
operating manual — only things that are expensive to rediscover.

## Commands

```bash
flutter pub get
flutter analyze --no-fatal-infos      # warnings ARE fatal; infos are not
bash tool/check_ui_strings.sh               # design-debt report only
bash tool/check_ui_strings.sh --strict      # fails above tool/revamp_baseline.env caps
flutter test                                # test/ only — never integration_test/
flutter test test/wealth_math_test.dart     # single file
flutter gen-l10n                            # after editing lib/l10n/*.arb
flutter build web --release --base-href /WealthSync/
flutter build apk --release

bash tool/rules_tests/run.sh          # Firestore+Storage rules vs emulators (Node >=24.12, JDK; npm ci on first run)
bash tool/run_integration_tests.sh    # E2E: fresh emulator per file; needs creds + emulator-5554
bash tool/smoke_release_apk.sh build/app/outputs/flutter-apk/app-release.apk
```

`E2E_FILES="a_test.dart b_test.dart"` runs a subset. `PRO_FILES` inside
`run_integration_tests.sh` decides which files run against the Pro account — a new
Pro file missing from it silently runs on the free account and fails on paywall copy.

**Pre-push gate, in order:** `flutter analyze --no-fatal-infos` → `check_ui_strings.sh
--strict` → `flutter test` → `flutter build web --release`. All four are CI's `test` job.
dart2js is stricter than the analyzer: touching a shared signature or a web-compiled
service requires the web build, or CI fails where analyze passed. The `rules` job is
required before a release. Integration tests are **disabled in CI** (`if: false`) by
design until features are manually verified.

CI pins Flutter **3.47.7**. Android NDK is env-overridable (`ANDROID_NDK_VERSION`,
default `28.2.13676358`); any job that compiles Android needs the pin.

## Layout and entry points

| Path | Role |
|---|---|
| `lib/main.dart` | `mainCommon()`, `_handleAuthChange()`, inline `ThemeController` |
| `lib/Screens/` | widgets only; `main_shell.dart` owns the name-keyed bottom nav |
| `lib/Controllers/` | GetX controllers (state ↔ services) |
| `lib/Services/` | business logic; also `PerformanceController`/`ConnectivityController` |
| `lib/Repositories/` | Firestore access only |
| `lib/Models/` | `fromMap`/`toMap` data classes |
| `lib/Config/` | `asset_screen_configs.dart` (22 generic asset screens), `feature_flags.dart` (source of truth), `tab_destinations.dart`, `app_strings.dart` |
| `lib/Platform/` | 9 `*_platform.dart` + `*_platform_stub.dart` pairs |
| `lib/Utils/` | pure helpers (`wealth_math.dart`, `spending_filter.dart`, `profile_update.dart`, …) |
| `test/`, `integration_test/` | unit/widget vs emulator E2E (read `test_helpers.dart` first) |

### Two-phase controller registration — order matters

Phase 1 in `mainCommon()`: ThemeController → PrivacyController → CurrencyController →
AuthController → SubscriptionController → PaymentConfigService → FeatureFlagService →
PerformanceController → ConnectivityController → IapService → BiometricService.

Phase 2 in `_handleAuthChange()`: TransactionController → ProfileController →
AnalyticsController → BudgetController → GoalsController → LoanController →
ChallengesController → LentMoneyController → RecurringPaymentController.

`BudgetController`/`AnalyticsController` call `Get.find<TransactionController>()` in init —
registering them in phase 1 crashes. Screens self-register with
`Get.isRegistered()` + `Get.put()` in `initState` (onboarding runs before phase 2).

## Traps that already shipped bugs

- **Never `Get.find<>()` in a field initializer** — controllers are not registered yet;
  do the guard + `Get.put` inside `initState`.
- **Own `TextEditingController`s in a `StatefulWidget` and dispose in `State.dispose()`**
  for modals/sheets. `route.popped` completes on *pop*, not after the exit animation; a
  reactive rebuild during that window re-attaches to a disposed controller. `try/finally`
  is only safe for dialogs whose content never rebuilds reactively.
- **Check `mounted` after every `await`** before `setState`/`context`.
- **Global dialogs use `Get.overlayContext!`**, not `Get.context!`. Never mix
  `Get.dialog()` with `Navigator.pop()`/`Get.snackbar()` — use `showDialog()` +
  `Navigator.of(context, rootNavigator: true).pop()` + `ScaffoldMessenger`.
- **A guard that loses its `return;` is invisible to every gate.** `if (!guard) { }`
  compiles clean and passes tests; `test/early_return_guard_test.dart` scans `lib/` for
  empty `if` bodies. Inside `Obx(() { … })` the fix is `return const SizedBox.shrink();`.
- **Never build a stream in `build()`** — hold it in a nullable field and use `??=`
  (`_entries` in asset screens, `_usersStream` in admin screens). A stream that depends on
  a changing filter stays inline.
- **Never `.limit()` the balance stream** — the balance sums all transactions. After
  restoring from cache, call `LocalCacheService.invalidate(key)`.
- `QueryDocumentSnapshot.data()` is non-nullable; `DocumentSnapshot.data()` is nullable.
- `Exception("message")`, never `throw "message"`. `CurrencyController.to.currencySymbol.value`,
  never a literal `₹`.
- **`compact()` floors, never rounds up** (`wealth_math.dart`): `compact(1500)` → `"1K"`,
  `compact(1_000_000)` → `"10.0L"`. Rounding up overstates a balance.
- Cache O(n) getters with `Rx` + an `ever` worker (`totalBalance` iterates everything).
- Cache `Theme.of` results in `build()` (analytics did 13 calls/build).
- No `setState` in `TweenAnimationBuilder.onEnd`; no `ShaderMask` on animated text;
  `BackdropFilter` sigma ≤ 4 and wrap in `RepaintBoundary`.
- Skip `!` casts on `jsonDecode`: check `is Map`/`is List` first. Use
  `(x as dynamic)?.toString()` for numeric casts.

## Money semantics

- **Expense**: `amount = -abs(v)`, `senderId = uid`, `recipientId = ""`.
  **Income**: `amount = +abs(v)`, `senderId = ""`, `recipientId = uid`.
- Budget aggregation filters `amount < 0` before `.abs()`; `import_service.dart` must not
  `.abs()` amounts. Budget alerts on bulk CSV/SMS imports need an explicit
  `BudgetService.checkBudgetExceeded` call, and only from expense rows.
- Expected income / daily limit: `computeExpectedIncome` + `computeDailyLimit` in
  `wealth_math.dart`. `manual` only wins when `manualMonthly > 0`; otherwise blend of
  this month and the 3-month average. Persisted as `income_mode`/`income_manual_monthly`.
- **Daily-limit category role has exactly one resolver**: `resolveDailyLimitRole(...)`
  (`fixed`/`variable`/`ignored`). Every classification site must call it —
  `analysis.dart` (4 sites) and `splitMonthlyExpenses()` — kept in sync by
  `test/analysis_fixed_classification_test.dart`. Today's variable spend subtracts both
  fixed and ignored; Category Insights renders an `ignored` category as nothing.
- `insurance.sumAssured` is **not** an asset: excluded from `totalAssets`, allocation and
  net worth. Changing that is a product decision.
- Dashboard must use `streamPortfolio()`, not `getPortfolio()`; transaction-derived wealth
  values need the `ever` worker in `wealth_builder.dart` to stay reactive.

## Firestore, rules, backups

- Asset types live one subcollection per type under `users/{email}/`. The registry is
  `UserService.subcollections` (26 asset collections + core/aux). Adding an asset type
  means adding it to that list **and** to the `firestore.rules` wildcard, or writes are
  denied.
- `firestore.indexes.json` is the **required** set, not a mirror of production. 4 composite
  indexes, each pinned to its querying file by `test/firestore_indexes_test.dart`. Live
  orphan indexes are expected — do not paste them in. Never `--force`.
- Rules deploy is manual/dispatch-only (`deploy_firebase`), Firestore only: Storage cannot
  be provisioned on Spark, and `--only storage` aborts the Firestore deploy with it.
  `--dry-run` proves the file *compiles*, never that it is complete.
- **`allow update` ORs its branches** — every branch must check ownership and its own field
  set. Free-Pro paths (`isTrialStart`, `isReferralApplication`, `isClaimPayout`) are
  bounded by `firestore.rules`; read `docs/THREAT_MODEL_entitlement.md` before "fixing" a
  bound.
- Referral writes are transactions, with the code doc read **inside** the transaction
  (`txn.get(codeRef)`) and `runTransaction<bool>` returning `false` for invalid/already
  referred. Payout math is `debugComputeTrialEnd`.
- **Backups**: `LocalBackupService.backupUserTransactions(email, reportErrors: false)` must
  run after *every* transaction write (add/edit/delete, CSV, SMS, audit fix, recurring) —
  the throttle makes extras free. Both on-device copies are AES-GCM sealed
  (`backup_cipher.dart`); a missing keystore falls back to plaintext deliberately, and an
  unauthenticated payload reads as "no backup", never a crash.
- **A smaller backup must never overwrite the larger one**: it goes to the
  `backup preserved_<email>` slot, and `restoreUserTransactions`/`hasUserBackup` consider
  both. This is the sequence that lost 791 live transactions.
- `FullBackupService` captures `UserService.subcollections` + profile + wealth summary.
  Restore is merge-only, into the **currently signed-in** account, with identity remapped
  (`remapIdentityForRestore`); the profile restore strips
  `serverAuthoritativeProfileFields` and the file redacts `purchaseToken`. Format is
  version 2 — a newer build refuses an older-version file rather than restoring history it
  cannot re-identify. Daily snapshot keeps a 7-day `safetyCopyTtl` copy and rejects
  shrinkage (`shouldRunDailySnapshot`).
- Account deletion writes a `users/{email}/meta/deletion` tombstone *after* the wipe;
  `AuthController.resumeInterruptedDeletion` finishes an interrupted delete on next
  sign-in. `meta` is deliberately **not** in `subcollections`.

## Auth and session teardown

- `AuthController.disposeUserScopedState()` is the **one** teardown list: nine user-scoped
  controllers + `AuditController`, SMS/recurring caches, `AppAnalytics` user id, and an
  **awaited** `LocalCacheService.clearAll()`. Both sign-out paths call it. A second list
  already drifted and leaked audit state.
- A failed `signOut()` must abort teardown; a Firestore failure *after* a successful
  sign-in must sign back out. A throw in `_handleAuthChange` resets `_handledUid` so the
  next emission retries.
- Sign-up sets `signupInProgress`, checked at the top of `_handleAuthChange` **before** the
  uid dedupe, then does its own `signOut()`.
- `AuthController.routeAfterSignIn(user)` is the only post-sign-in routing decision; it
  asks `OnboardingStatus.isOnboardedFor`. `is_onboarded` is device-wide and stamped with
  `is_onboarded_email`.
- `deleteAccount` pre-flights auth freshness (5-min window) before touching data and
  refuses first; the screen must `signOut()` after deletion.
- `SubscriptionController.resetForSignOut()` clears trial state, or the next user on a
  shared device inherits Pro.

## Feature flags

Registry is `lib/Config/feature_flags.dart` (`all` + `groups`); global doc
`app_config/feature_flags`, missing ⇒ `enabled`. Statuses: `enabled`, `comingSoon`
(non-admins get the placeholder), `hidden` (removed for everyone).

- `test/feature_flags_test.dart` scans `lib/` and fails if a registered key is never gated
  or a gate key is unregistered — register **and** wire the gate in the same change.
- Gate tiers: `ensureFeatureVisible(context, key)` before navigation;
  `ensureFeatureUsable` when the surface stays but taps die; `FeatureGate(key:, child:)` on
  bodies; `FeatureVisible`/`SliverFeatureVisible` for sub-components (a plain box inside a
  sliver crashes); `FeatureSection(flagKeys: [...])` for settings groups.
- Bottom nav is **name-keyed** via `tab_destinations.dart`, not index.
- Background flags read `app_config/feature_flags` per tick and are **fail-closed** via the
  `bg_feature_flags` mirror; only `hidden` halts work.
- `FeatureFlagService` and `PaymentConfigService` use the auth-gated listener
  (`Utils/auth_gated_listener.dart`). Do not "simplify" back to a bare `.snapshots()` — they
  register pre-login and the read is denied. Do not move them to phase 2 either.

## Observability

`lib/Services/app_analytics.dart` is the only entry point for Analytics/Crashlytics. Add
event names to `AnalyticsEvent` first — a typo splits a funnel silently. `log`/`recordError`/
`setUserId` never throw and never block, and `recordError`'s `context` is
`Map<String, Object?>` on purpose (narrowing it passes `analyze` and fails the web build).
Caught errors do not reach Crashlytics unless you call `AppAnalytics.recordError` next to
the `debugPrint`. `feature_gate_hit` fires from tap guards only, never `visibleToMe`.
`AppAnalytics.init` is gated on `!isTest`.

## Platform and release

- **`google_sign_in` stays on `^6.2.2`** (v7's stream API races). One client in
  `google_auth_service.dart`; `obtainCredential()` calls `signOut()` before `signIn()`, or
  Android returns the cached account with no UI.
- Android-only capabilities go through `isAndroidPlatform` (`Utils/platform_support.dart`),
  never `dart:io` `Platform` (breaks web) and never `defaultTargetPlatform` alone.
- **Web: the Firebase JS SDK b815/ca9 corruption is why the auth flow is shaped oddly.**
  `enableNetwork()` is deferred until after login, phase-2 registrations are delayed on web,
  `ThemeController.resubscribe()` is re-invoked, and `checkSubscriptionStatus()` is skipped
  on resume. Any reordering can re-trigger a full-page reload crash.
- **R8 minify is on for release; unit/E2E tests run debug, so a release-only crash is
  invisible.** `android/app/proguard-rules.pro` keeps `* extends androidx.room.RoomDatabase`
  with its constructor (WorkManager builds `WorkDatabase_Impl` reflectively). After touching
  minify/proguard/AGP/deps, build and **launch** a release APK.
- Release ships exactly **one universal APK**. Do not re-add `--split-per-abi` (ABI splits
  get `versionCode = abiVersion * 1000 + n`, so the in-app updater's universal download is
  rejected with `INSTALL_FAILED_VERSION_DOWNGRADE`).
- **The in-app updater is checksum-first and streams everything.** `UpdateChecker.
  downloadAndInstallApk` fetches `SHA256SUMS` *before* the APK (a missing checksum fails
  closed as `checksumUnavailable`), hashes through `sha256.bind(file.openRead())` — never
  `readAsBytes()`, which OOMs on a ~128 MB APK and is how "download hits 100 % then fails"
  shipped — and only fails the size gate on *truncation*, leaving the SHA-256 as the real
  check. A verified APK stays in the cache dir so a retry does not re-download 128 MB.
  Failures log `update_download_failed`/`update_install_failed` with a `reason`: a phone has
  no logcat. `test/update_checker_download_test.dart` pins all of it, including a source
  guard against `readAsBytes`.
- `android/app/google-services.json` is gitignored — download it locally from the Firebase
  console (CI injects it from a secret). Android tools are not on PATH:
  `export PATH="$HOME/Android/Sdk/platform-tools:$HOME/.sdks/flutter/bin:$PATH"`.
- `android/` uses Gradle 9.3.1 / AGP 9.1.0 / KGP 2.4.0, with
  `android.builtInKotlin=false` + `android.newDsl=false` (Flutter's escape hatch for
  KGP-applying plugins). Don't lower Firebase/geocoding versions.
- iOS: the Workmanager `uniqueName` must equal the identifier in
  `BGTaskSchedulerPermittedIdentifiers` (`Info.plist`) or every schedule fails with Code 3.

## L10n, copy, and UI debt

- Generated l10n Dart is **committed** (`lib/l10n/app_localizations*.dart`): an ARB edit
  ships with its regenerated pair.
- Copy asserted by integration tests belongs in `lib/Config/app_strings.dart`; tests assert
  `find.text(AppStrings.x)`, never the literal. A section title must describe where its tap
  goes.
- Tokens live in `lib/Components/colors.dart` (`AppColors.primary` = `0xFF4F46E5`,
  `AppRadius`, `AppShadows`, `chartSeries`). Pre-revamp cyan/purple/navy/mint/pink hexes are
  fully rebranded — never reintroduce them. Category data colors stay inline.
- Lower caps in `tool/revamp_baseline.env` after each revamp wave; **never raise**.

## Integration tests

Every file starts with `launchAndSignIn(account: TestAccount.free|pro)` and wraps its body
in `testWidgetsWithScreenshots`. Credentials come from `--dart-define=TEST_EMAIL=…`
(`String.fromEnvironment`, so an empty default fails auth with a channel error).

- **The account wipe is opt-in**: `clearAccountData` no-ops unless
  `--dart-define=E2E_ALLOW_WIPE=true`. CI opts in against disposable accounts; never point
  the runner at a real account. `launchAndSignIn` also seeds `age: 30` because the Wealth
  tab is age-gated.
- Use the helpers (`waitFor*`, `tapNavTab`, `scrollUntilVisible`, `createTransaction`,
  `completeOnboardingIfNeeded`, `pumpAndSettleSafe`). Hand-rolled pumps are the main source
  of new flakes.
- `flutter test` uninstalls the app after an integration run and wipes cached screenshots —
  always pass `--no-uninstall` (CI does).
- A freshly booted emulator can report `sys.boot_completed=1` with dead DNS; Firebase then
  fails with `NETWORK_REQUEST_FAILED`. Check `adb shell ping firestore.googleapis.com`
  before suspecting auth code.
- Let a human session boot the emulator; agent-initiated `-avd` starts segfault and leave
  stale locks in `/run/user/1000/avd/running/`. `run_integration_tests.sh` restarts the
  emulator between files because host-GL accumulation kills the second app launch.

## When in doubt

- Tests are contracts: `early_return_guard_test`, `feature_flags_test`, `feature_gate_test`,
  `ci_workflow_contract_test`, `firestore_indexes_test`, `platform_contract_test`,
  `app_analytics_test`, `local_backup_*`, `backup_identity_remap_test`. Read the relevant
  one before changing control flow, CI, rules, or backup code.
- Security/entitlement reasoning lives in `docs/THREAT_MODEL_entitlement.md` and
  `docs/LEARNINGS_security_review.md`.
