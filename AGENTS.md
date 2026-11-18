# AGENTS.md

WealthSync (package `money_control`): Flutter + GetX + Firebase personal-finance app. MVC-Service-Repository. Product context is `README.md`; this file is the operating manual — only things expensive to rediscover.

## Setup

```bash
flutter pub get
```

- Android tools are **not** on PATH: `export PATH="$HOME/Android/Sdk/platform-tools:$HOME/.sdks/flutter/bin:$PATH"`.
- `android/app/google-services.json` is gitignored — download it from the Firebase console locally; CI injects it from a secret. Android builds fail without it.
- `pubspec.yaml` **and** `pubspec.lock` are both tracked. A dependency edit must regenerate the lock (`flutter pub get`); a bare `version:` bump is skipped by CI's `paths-ignore` (it won't retrench the build).
- `lib/firebase_options.dart` is committed — it holds the Firebase project config for all platforms and is passed to `Firebase.initializeApp`. Do not treat it as per-install.

## Commands

```bash
flutter pub get
flutter analyze --no-fatal-infos        # warnings fatal; infos are not
bash tool/check_ui_strings.sh --strict  # UI revamp debt caps; fails if exceeded
flutter test                            # unit + widget tests in test/ only — never integration_test/
flutter test test/wealth_math_test.dart # single file
flutter gen-l10n                        # after editing lib/l10n/*.arb (generated Dart is committed)
flutter build web --release --base-href /WealthSync/  # dart2js is stricter than the analyzer
flutter build apk --release
bash tool/rules_tests/run.sh            # Firestore+Storage rules vs emulators (Node >=24.12, JDK 21)
bash tool/run_integration_tests.sh      # E2E: fresh emulator per file; needs creds + emulator-5554
bash tool/smoke_release_apk.sh build/app/outputs/flutter-apk/app-release.apk
```

`E2E_FILES="a_test.dart b_test.dart"` runs a subset. `PRO_FILES` inside `tool/run_integration_tests.sh` decides which files run against the Pro account — a new Pro file missing from it silently runs free and fails on paywall copy.

**Pre-push gate, in order:** `flutter analyze --no-fatal-infos` → `check_ui_strings.sh --strict` → `flutter test` → `flutter build web --release --base-href /WealthSync/`. CI's `test` job runs all four; the `rules` job is required before a release. Integration tests are disabled in CI (`if: false`) by design; default branch is `master`, release and Pages jobs run only there.

CI pins Flutter **3.47.7** (pubspec only requires `^3.9.2`). Android NDK is env-overridable (`ANDROID_NDK_VERSION`, default `28.2.13676358`); any job that compiles Android needs the pin. Android CI uses JDK 17; the rules job uses JDK 21 — a newer local JBR (Java 25) breaks the Gradle build.

## Entry points

- `lib/main.dart` — `mainCommon()`, `_handleAuthChange()`, inline `ThemeController`
- `lib/Screens/` — widgets only; `main_shell.dart` owns the name-keyed bottom nav
- `lib/Controllers/` — GetX controllers; `lib/Services/` — business logic (+ `PerformanceController`/`ConnectivityController`)
- `lib/Repositories/` — Firestore access only; `lib/Models/` — `fromMap`/`toMap`; `lib/Config/` — feature flags, asset registry, tab destinations, app strings; `lib/Platform/` / `lib/Utils/` — helpers & platform stubs

**Two-phase controller registration — order matters.** Phase 1 in `mainCommon()`: ThemeController → PrivacyController → CurrencyController → AuthController → SubscriptionController → PaymentConfigService → FeatureFlagService → PerformanceController → ConnectivityController → IapService → BiometricService. Phase 2 in `_handleAuthChange()`: TransactionController → ProfileController → AnalyticsController → BudgetController → GoalsController → EmergencyFundService → LoanController → ChallengesController → LentMoneyController → RecurringPaymentController. `BudgetController`/`AnalyticsController` call `Get.find<TransactionController>()` in init — registering them in phase 1 crashes. Screens self-register (`Get.isRegistered()` + `Get.put()` in `initState`); onboarding runs before phase 2.

On web the phase-2 registrations are staggered with 500 ms delays so the first persistent Firestore `.snapshots()` listener precedes any transient `.get()` (Firebase JS SDK b815/ca9 corruption). `checkSubscriptionStatus()` is skipped on resume on web.

## Traps that already shipped bugs

- Never `Get.find<>()` in a field initializer — guard + `Get.put` inside `initState`.
- Own `TextEditingController`s in the `StatefulWidget`, dispose in `State.dispose()` (modals/sheets). `route.popped` completes on pop, not after the exit animation.
- Check `mounted` after every `await` before `setState`/`context`.
- Global dialogs use `Get.overlayContext!`, not `Get.context!`. Never mix `Get.dialog()` with `Navigator.pop()`/`Get.snackbar()` — use `showDialog()` + `Navigator.of(context, rootNavigator: true).pop()` + `ScaffoldMessenger`.
- A guard that loses its `return;` is invisible: `if (!guard) { }` compiles clean. `test/early_return_guard_test.dart` scans `lib/` for empty `if` bodies. In `Obx` use `return const SizedBox.shrink();`.
- Never build a stream in `build()` — hold it in a nullable field and use `??=`. A stream that depends on a changing filter stays inline.
- Never `.limit()` the balance stream (it sums all transactions). After restoring from cache, call `LocalCacheService.invalidate(key)`.
- `Exception("message")`, never `throw "message"`. `CurrencyController.to.currencySymbol.value`, never a literal `₹`.
- `compact()` floors, never rounds up (`wealth_math.dart`): `compact(1500)` → `"1K"`, `compact(1_000_000)` → `"10.0L"`.
- Cache O(n) getters with `Rx` + an `ever` worker (`totalBalance` iterates everything). Cache `Theme.of` results in `build()`.
- No `setState` in `TweenAnimationBuilder.onEnd`; no `ShaderMask` on animated text; `BackdropFilter` sigma ≤ 4 wrapped in `RepaintBoundary`.
- Skip `!` casts on `jsonDecode`: check `is Map`/`is List` first; use `(x as dynamic)?.toString()` for numeric casts.

## Money semantics

- Expense: `amount = -abs(v)`, `senderId = uid`, `recipientId = ""`. Income: `amount = +abs(v)`, `senderId = ""`, `recipientId = uid`.
- Budget aggregation filters `amount < 0` before `.abs()`. `import_service.dart` must not `.abs()` amounts. Budget alerts on bulk CSV/SMS imports need an explicit `BudgetService.checkBudgetExceeded` call, only from expense rows.
- Expected income / daily limit: `computeExpectedIncome` + `computeDailyLimit` (`wealth_math.dart`). `manual` wins only when `manualMonthly > 0`; otherwise a blend of this month and the 3-month average. Persisted as `income_mode`/`income_manual_monthly`.
- Daily-limit category role has exactly one resolver: `resolveDailyLimitRole(...)` (`fixed`/`variable`/`ignored`). Every classification site calls it — `analysis.dart` (2 sites), `bills_math.dart`, `splitMonthlyExpenses()` — kept in sync by `test/analysis_fixed_classification_test.dart`.
- `insurance.sumAssured` is **not** an asset: excluded from `totalAssets`, allocation, net worth. Changing it is a product decision.
- Dashboard uses `streamPortfolio()`, not `getPortfolio()`; transaction-derived wealth values need the `ever` worker in `wealth_builder.dart` to stay reactive.

## Firestore, rules, backups

- Firebase free (Spark) plan: no Cloud Functions, Cloud Storage, or messaging fan-out. `test/spark_plan_guard_test.dart` fails on `cloud_functions`/`firebase_storage` imports or `httpsCallable`/`uploadBytes` calls. Offline persistence stays on (`persistenceEnabled: true` in `main.dart`).
- One listener per collection: `TransactionController` owns transactions, `RecurringPaymentController` owns recurring payments; a screen never calls a repository stream directly.
- Adding an asset type: add to `UserService.subcollections` **and** the `firestore.rules` wildcard (writes are denied otherwise), plus a `WealthAssetRegistry` descriptor and either an `AssetConfigs` entry or a hand-written screen.
- `firestore.indexes.json` is the required set, not a production mirror. 3 composite indexes (`challenges`, `loans`, `transactions`), each pinned to its querying file by `test/firestore_indexes_test.dart`. Live orphan indexes are expected — do not paste them in. Never `--force`.
- Rules deploy is manual/dispatch-only (`deploy_firebase`), Firestore only: Storage can't be provisioned on Spark, and `--only storage` aborts the Firestore deploy. `--dry-run` proves compilation, not completeness.
- `allow update` ORs its branches — every branch checks ownership and its own field set. Free-Pro paths (`isTrialStart`, `isReferralApplication`, `isClaimPayout`) are bounded by `firestore.rules`; read `docs/THREAT_MODEL_entitlement.md` before "fixing" a bound.
- Referral writes are transactions, with the code doc read **inside** the transaction (`txn.get(codeRef)`); `runTransaction<bool>` returns `false` for invalid/already referred. Payout math is `debugComputeTrialEnd`.
- `LocalBackupService.backupUserTransactions(email, reportErrors: false)` runs after *every* transaction write (add/edit/delete, CSV, SMS, audit fix, recurring) — the throttle makes extras free. Both on-device copies are AES-GCM sealed (`backup_cipher.dart`); missing keystore falls back to plaintext; unauthenticated payload reads as "no backup", never a crash.
- A smaller backup must never overwrite the larger one: it goes to the preserved slot (`backup preserved <email>` / `txprev_<email>.json`); `restoreUserTransactions`/`hasUserBackup` consider both. This sequence lost 791 live transactions.
- `FullBackupService` captures `UserService.subcollections` + profile + wealth summary. Restore is merge-only into the **currently signed-in** account, with identity remapped (`remapIdentityForRestore`); profile restore strips `serverAuthoritativeProfileFields`, file redacts `purchaseToken`. Format is version 2 (records source uid); a build older than the file refuses it. Daily snapshot keeps a 7-day `safetyCopyTtl` copy and rejects shrinkage (`shouldRunDailySnapshot`).
- Account deletion writes a `users/{email}/meta/deletion` tombstone *before* wiping data, so `AuthController.resumeInterruptedDeletion` finishes an interrupted delete on next sign-in. `meta` is deliberately **not** in `subcollections`.

## Auth & session teardown

- `AuthController.disposeUserScopedState()` is the **one** teardown list: nine user-scoped controllers + `AuditController`, SMS/recurring caches, `IncomeSettings`/`SavingsSettings`, `OfflineQueueService.clearPending()`, `WidgetActionQueue.reset()`, `AppAnalytics` user id, awaited `LocalCacheService.clearAll()`. Both sign-out paths call it; a second list already drifted and leaked audit state.
- A failed `signOut()` aborts teardown; a Firestore failure after a successful sign-in signs back out. A throw in `_handleAuthChange` resets `_handledUid` so the next emission retries.
- Sign-up sets `signupInProgress`, checked at the top of `_handleAuthChange` **before** the uid dedupe, then does its own `signOut()`.
- `AuthController.routeAfterSignIn(user)` is the only post-sign-in routing decision; asks `OnboardingStatus.isOnboardedFor`. `is_onboarded` is device-wide, stamped with `is_onboarded_email`.
- `deleteAccount` pre-flights auth freshness (5-min window) before touching data and refuses first; the screen must `signOut()` after deletion.
- `SubscriptionController.resetForSignOut()` clears trial state, or the next user on a shared device inherits Pro.

## Feature flags

- Registry `lib/Config/feature_flags.dart` (`all` + `groups`); global doc `app_config/feature_flags`, missing ⇒ `enabled`. Statuses: `enabled`, `comingSoon` (non-admins get the placeholder), `hidden` (removed for everyone).
- `test/feature_flags_test.dart` scans `lib/` and fails if a registered key is never gated or a gate key is unregistered — **register and wire the gate in the same change**.
- Gate tiers: `ensureFeatureVisible(context, key)` before navigation; `ensureFeatureUsable` when the surface stays but taps die; `FeatureGate(flagKey:, child:)` on bodies; `FeatureVisible`/`SliverFeatureVisible` for sub-components (a plain box inside a sliver crashes); `FeatureSection(flagKeys: [...])` for settings groups.
- Bottom nav is **name-keyed** via `tab_destinations.dart`, not index.
- Background flags read `app_config/feature_flags` per tick and are fail-closed via the `bg_feature_flags` mirror; only `hidden` halts work.
- `FeatureFlagService` and `PaymentConfigService` use the auth-gated listener (`Utils/auth_gated_listener.dart`). Do not "simplify" to bare `.snapshots()` (they register pre-login and the read is denied); do not move them to phase 2.

## Observability

- `lib/Services/app_analytics.dart` is the only entry point for Analytics/Crashlytics. Add event names to `AnalyticsEvent` first — a typo splits a funnel silently. `log`/`recordError`/`setUserId` never throw or block; `recordError`'s `context` is `Map<String, Object?>` (narrowing passes `analyze` and fails the web build).
- Caught errors do not reach Crashlytics unless you call `AppAnalytics.recordError` next to the `debugPrint`. `feature_gate_hit` fires from tap guards only, never `visibleToMe`. `AppAnalytics.init` is gated on `!isTest`.

## Platform & release

- `google_sign_in` stays on `^6.2.2` (v7's stream API races). One client in `google_auth_service.dart`; `obtainCredential()` calls `signOut()` before `signIn()`, or Android returns the cached account with no UI.
- Android-only capabilities go through `isAndroidPlatform` (`Utils/platform_support.dart`), never `dart:io` `Platform` (breaks web) and never `defaultTargetPlatform` alone.
- Web: Firebase JS SDK b815/ca9 corruption shapes the auth flow — `enableNetwork()` deferred until after login, phase-2 registrations delayed on web, `ThemeController.resubscribe()` re-invoked, `checkSubscriptionStatus()` skipped on resume. Any reordering can re-trigger a full-page reload crash.
- R8 minify is on for release (`isMinifyEnabled = true`); unit/E2E tests run debug, so a release-only crash is invisible. `android/app/proguard-rules.pro` keeps `* extends androidx.room.RoomDatabase` with its constructor (WorkManager builds `WorkDatabase_Impl` reflectively). After touching minify/proguard/AGP/deps, build **and launch** a release APK.
- Release ships exactly **one universal APK**. Do not re-add `--split-per-abi` (splits get `versionCode = abiVersion * 1000 + n`, so the in-app updater's universal download is rejected with `INSTALL_FAILED_VERSION_DOWNGRADE`).
- `UpdateChecker.downloadAndInstallApk` is checksum-first and streams: fetches `SHA256SUMS` before the APK (missing checksum fails closed as `checksumUnavailable`), hashes through `sha256.bind(file.openRead())` — never `readAsBytes()` (OOMs on a ~128 MB APK). A verified APK stays in cache so a retry doesn't re-download. `test/update_checker_download_test.dart` pins it, including a source guard against `readAsBytes`.
- `android/` uses Gradle 9.3.1 / AGP 9.1.0 / KGP 2.4.0, with `android.builtInKotlin=false` + `android.newDsl=false`. Android CI pins JDK 17; a newer local JBR (Java 25) has broken the Gradle build. Don't lower Firebase/geocoding versions.
- iOS: the Workmanager `uniqueName` must equal the identifier in `BGTaskSchedulerPermittedIdentifiers` (`Info.plist`) or every schedule fails with Code 3.

## L10n, copy, UI debt

- Generated l10n Dart is **committed** (`lib/l10n/app_localizations*.dart`): an ARB edit ships with its regenerated pair.
- Copy asserted by integration tests belongs in `lib/Config/app_strings.dart`; tests assert `find.text(AppStrings.x)`, never the literal. A section title must describe where its tap goes.
- Tokens live in `lib/Components/colors.dart` (`AppColors.primary` = `0xFF4F46E5`, `AppRadius`, `AppShadows`, `chartSeries`). Pre-revamp cyan/purple/navy/mint/pink hexes are fully rebranded — never reintroduce them. Category data colors stay inline.
- Lower caps in `tool/revamp_baseline.env` after each revamp wave; **never raise**.

## Integration tests

Every file starts with `launchAndSignIn(account: TestAccount.free|pro)` and wraps its body in `testWidgetsWithScreenshots`. Credentials come from `--dart-define=TEST_EMAIL=…` (`String.fromEnvironment`, so an empty default fails auth with a channel error).

- The account wipe is opt-in: `clearAccountData` no-ops unless `--dart-define=E2E_ALLOW_WIPE=true`. CI opts in against disposable accounts; never point the runner at a real account. `launchAndSignIn` also seeds `age: 30` (Wealth tab is age-gated).
- Use the helpers (`waitFor*`, `tapNavTab`, `scrollUntilVisible`, `createTransaction`, `completeOnboardingIfNeeded`, `pumpAndSettleSafe`). Hand-rolled pumps are the main source of new flakes.
- `flutter test` uninstalls the app after an integration run and wipes cached screenshots — always pass `--no-uninstall` (CI does).
- A freshly booted emulator can report `sys.boot_completed=1` with dead DNS; Firebase then fails with `NETWORK_REQUEST_FAILED`. Check `adb shell ping firestore.googleapis.com` before suspecting auth code.
- `run_integration_tests.sh` restarts the emulator between files (host-GL accumulation kills the second app launch). On a hardware-accelerated local AVD set `E2E_NO_RESTART=1`; `E2E_AVD_NAME` overrides the AVD name (default `test`).

## When in doubt

Tests are contracts — read the relevant one before changing control flow, CI, rules, or backup code: `early_return_guard_test`, `feature_flags_test`, `feature_gate_test`, `ci_workflow_contract_test`, `firestore_indexes_test`, `platform_contract_test`, `app_analytics_test`, `local_backup_*`, `backup_identity_remap_test`. Security/entitlement reasoning: `docs/THREAT_MODEL_entitlement.md`, `docs/LEARNINGS_security_review.md`.
