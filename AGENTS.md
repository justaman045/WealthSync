# AGENTS.md

This file provides critical rules and patterns for AI coding assistants working on this Flutter project.

## CRITICAL RULES (Follow These Always)

### 1. GetX Controller Access — NEVER Use Field Initializers

```dart
// ❌ WRONG — crashes during onboarding before controllers are registered
class _MyScreenState extends State<MyScreen> {
  final _controller = Get.find<TransactionController>();
}

// ✅ CORRECT — defer to initState() with registration guard
class _MyScreenState extends State<MyScreen> {
  late final TransactionController _controller;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    _controller = Get.find<TransactionController>();
  }
}
```

**Why**: Field initializers run before `initState()`. During onboarding, controllers registered in `AuthChecker._handleAuthChange()` don't exist yet.

**Applies to**: ALL screens, components, and widgets that use `Get.find<>()`.

### 2. Dispose TextEditingControllers in Dialogs

Dialogs/bottom sheets that instantiate `TextEditingController` inline must explicitly dispose them. The dialog `Future` is the lifecycle anchor:

```dart
// showDialog — use try/finally
Future<void> _showDialog() async {
  final ctrl = TextEditingController();
  try {
    await showDialog(context: context, builder: (_) => AlertDialog(...));
  } finally {
    ctrl.dispose();
  }
}

// showModalBottomSheet — use .whenComplete()
void _showSheet() {
  final ctrl = TextEditingController();
  showModalBottomSheet(...).whenComplete(() => ctrl.dispose());
}
```

**Better pattern for sheets with multiple controllers**: Make the sheet a `StatefulWidget` that owns controllers (created in `initState`, disposed in `dispose`). This avoids the crash where `showModalBottomSheet` returns before the sheet's widgets are unmounted (keyboard-triggered rebuilds try to use disposed controllers). See `_AddSheet` in `asset_detail_screen.dart`, `_Sheet` in `vehicle_detail_screen.dart`, etc.

### 3. mounted Check After async

```dart
// ✅ Always guard setState() after await
await someAsyncOperation();
if (!mounted) return;
setState(() { ... });
```

### 4. Use Get.overlayContext for Global Dialogs

```dart
// In utility functions (not inside a widget's build):
showGeneralDialog(context: Get.overlayContext!, ...);
// NOT: showGeneralDialog(context: Get.context!, ...);
```

## Architecture

**MVC-Service-Repository pattern** using **GetX** for state management and DI:

- `lib/Models/` — Plain Dart data classes with `fromMap`/`toMap` Firestore serialization
- `lib/Repositories/` — Firestore data access layer only
- `lib/Services/` — Business logic (not GetX controllers)
- `lib/Controllers/` — GetX controllers binding services to reactive UI state
- `lib/Screens/` — Screen widgets only; no business logic
- `lib/Components/` — Reusable widgets and app-wide constants
- `lib/Config/` — Configuration objects (e.g., `AssetScreenConfig` definitions)
- `lib/Utils/` — `IconHelper` (explicit icon list to prevent tree-shaking)
- `lib/data/` — Static seed data

**ThemeController exception**: defined inline in `main.dart` (not in `lib/Controllers/`) because it must be available before any screen is built.

## Controller Dependencies & Registration

### Dependency Order

1. **Top-level `mainCommon()`** (app-wide, no auth dependency): `PrivacyController`, `CurrencyController`, `AuthController`, `SubscriptionController`, `PaymentConfigService`, `IapService`, `BiometricService`.

2. **Inside `AuthChecker._handleAuthChange()` after login** (speak TransactionController first): `TransactionController`, then `ProfileController`, `AnalyticsController`, `BudgetController`, `GoalsController`, `LoanController`, `ChallengesController`, `LentMoneyController`, `RecurringPaymentController`.

`BudgetController` and `AnalyticsController` both call `Get.find<TransactionController>()` during init — registering them in `mainCommon()` crashes with "not found" because the user hasn't logged in yet.

| Controller | Depends On | Registration |
|------------|-----------|-------------|
| TransactionController | — | `AuthChecker._handleAuthChange()` |
| ProfileController | TransactionController | After TransactionController |
| AnalyticsController | TransactionController | After TransactionController |
| BudgetController | TransactionController | After TransactionController |
| PrivacyController | — | `mainCommon()` |
| CurrencyController | — | `mainCommon()` |
| SubscriptionController | — | `mainCommon()` |
| GoalsController | — | `mainCommon()` |
| LoanController | — | `mainCommon()` |
| ChallengesController | — | `mainCommon()` |
| LentMoneyController | — | `mainCommon()` |
| RecurringPaymentController | — | `mainCommon()` |

### Self-Registration Pattern

Screens that depend on controllers must self-register with `Get.isRegistered()` + `Get.put()` guards in `initState()`. This is essential because the onboarding flow (`is_onboarded == false`) shows screens before `_handleAuthChange()` has registered any controllers.

Files using this pattern:

| File | Controllers |
|------|------------|
| `lib/Screens/add_transaction.dart` | TransactionController |
| `lib/Screens/analytics.dart` | TransactionController |
| `lib/Screens/recurring_payments_screen.dart` | TransactionController |
| `lib/Screens/edit_profile.dart` | ProfileController |
| `lib/Screens/homescreen.dart` | ProfileController, TransactionController |
| `lib/Screens/budget.dart` | BudgetController |
| `lib/Screens/settings.dart` | ProfileController |
| `lib/Screens/transaction_history.dart` | TransactionController |
| `lib/Screens/cateogaries_history.dart` | BudgetController |
| `lib/Screens/add_lent_money_screen.dart` | LentMoneyController, CurrencyController |
| `lib/Screens/lent_money_screen.dart` | LentMoneyController, CurrencyController |
| `lib/Screens/forecast_screen.dart` | AnalyticsController |
| `lib/Screens/category_management.dart` | SubscriptionController, TransactionController |
| `lib/Screens/split_bill_screen.dart` | LentMoneyController |
| `lib/Screens/savings_challenges_screen.dart` | TransactionController |
| `lib/Screens/analysis.dart` | TransactionController |
| `lib/Components/balance_card.dart` | PrivacyController, TransactionController, LentMoneyController, RecurringPaymentController |
| `lib/Components/quick_send.dart` | TransactionController |
| `lib/Components/recent_payment_list.dart` | TransactionController |

## Wealth / Asset Management System

### Architecture

One Firestore subcollection per asset type under `users/{userEmail}/`, plus a single `wealth/portfolio` summary document for dashboard aggregation.

**Subcollections** (24 total, listed in `AssetScreenConfig` and `firestore.rules`):
- **Liquid & Fixed Income**: `fd_accounts`, `ppf_accounts`, `post_office_schemes`, `bonds`, `chit_funds`
- **Equity & Growth**: `stock_holdings`, `sip_holdings`, `etf_holdings`, `foreign_stocks`, `startup_investments`
- **Retirement**: `pf_accounts`, `vpf_accounts`, `nps_accounts`
- **Alternative Assets**: `gold_holdings`, `sgb_holdings`, `jewelry_items`, `crypto_holdings`, `reit_holdings`, `p2p_loans`
- **Physical Assets**: `agri_land`, `properties`, `vehicles`
- **Protection & Business**: `insurance_policies`, `business_assets`
- **Liabilities**: `bnpl_entries`, `credit_cards`

### WealthPortfolio Model (`lib/Models/wealth_data.dart`)

Single document at `users/{email}/wealth/portfolio` storing all asset category totals as named fields (e.g., `sip`, `fd`, `stocks`, `gold`, `realEstate`, etc.) plus `custom` map, `targets`, `hiddenKeys`, `lastUpdated`, `monthlyExpenseOverride`.

Notable properties:
- `totalAssets` — sum of all asset fields + custom entries
- `totalLiabilities` — sum of `loans + creditCard + bnpl`

### WealthService (`lib/Services/wealth_service.dart`)

- `getPortfolio()` — one-shot fetch
- `streamPortfolio()` — real-time stream (dashboard subscribes to this)
- `updateAsset(key, value)` — writes to `wealth/portfolio` with `SetOptions(merge: true)`
- `updateAssetTarget(key, targetValue)` — writes target override
- `calculateBankBalance(transactions)` — computes bank balance from transaction history
- `generateSmartInsights(portfolio, transactions)` — financial insights
- `calculateAssetTargets(portfolio, transactions, userProfile)` — age-based target calculations using milestone tables (Fidelity lifecycle model adapted for India)

### AssetScreenConfig (`lib/Config/asset_screen_configs.dart`)

Drives both the card appearance on the dashboard and the dynamic form fields in `AssetDetailScreen`. Each asset type has a static config specifying:
- `title` / `collection` / `assetKey`
- `accentColor` / `icon`
- `fields` — `List<AssetFieldDef>` defining the form (text, number, date, dropdown)
- `amountField` — the field that gets summed for the card total

### AssetDetailScreen (`lib/Screens/asset_detail_screen.dart`)

Generic screen for all asset types defined in `AssetScreenConfig`. Takes `AssetScreenConfig` as input, renders:
- Summary header with total
- StreamBuilder on the subcollection
- Cards with delete capability
- `_AddSheet` (bottom sheet) for adding entries

**Key patterns**:
- `_AddSheet` owns `TextEditingController`s (created in `initState`, disposed in `dispose`)
- `_syncedEmpty` flag ensures portfolio is reset to 0 when the subcollection becomes empty
- `_syncTotal()` recomputes sum from the subcollection and calls `WealthService.updateAsset()`

### Custom Screens

4 screens exist for complex asset types that need custom layouts:
- `RealEstateDetailScreen` — properties (`vehicles` subcollection, but note: actually uses `properties` collection — in rules it's `properties`)
- `VehicleDetailScreen` — vehicles (`vehicles` subcollection)
- `InsurancePolicyScreen` — insurance policies (`insurance_policies` subcollection)
- `CreditCardDetailScreen` — credit cards (`credit_cards` subcollection)

Each has `_Sheet` or `_AddSheet` that owns `TextEditingController`s in `initState`/`dispose`.

### Dashboard Navigation Pattern (`lib/Screens/wealth_builder.dart`)

The dashboard (`WealthBuilderScreen`) subscribes to `WealthService.streamPortfolio()` for real-time updates (not a one-shot fetch). Two navigation patterns:
- Generic assets: `Get.to(() => AssetDetailScreen(config: AssetConfigs.fd))`
- Custom screens: `Get.to(() => const VehicleDetailScreen())`

## Firestore Security Rules (`firestore.rules`)

### Key Functions

```javascript
function isOwner(email) { /* request.auth.token.email == email */ }
function isAdmin() { /* checks users/{email}.isAdmin == true */ }
function validTransaction() { /* validates amount, date, senderId, recipientId */ }
function isReferralAllowed() { /* permits cross-user referral writes */ }
```

### Referral Write Rule

`isReferralAllowed()` permits any authenticated user to write `referralCount`, `subscriptionStatus`, `trialEndDate` to a user doc **if** the target doc has a `referralCode` field. This enables the referral transaction (referee writes to referrer's doc) without allowing arbitrary writes:

```javascript
function isReferralAllowed() {
  let affected = request.resource.data.diff(resource.data).affectedKeys();
  let isReferralFields = affected.hasOnly(['referralCount', 'subscriptionStatus', 'trialEndDate']);
  let targetHasCode = resource.data.keys().hasAny(['referralCode']);
  return request.auth != null && targetHasCode && isReferralFields;
}
```

### Per-Asset Subcollection Wildcard

The `match /{collection}/{docId}` under `users/{userEmail}` lists all 24 asset subcollection names in an `in` check. Existing specific rules (transactions, wealth, goals, loans, etc.) are unaffected and take precedence.

### Default Deny

The bottom `match /{document=**}` with `allow read, write: if false;` denies everything not explicitly matched.

## Referral System (`lib/Services/referral_service.dart`)

### Code Generation
`generateReferralCode(name, uid)` creates a deterministic 6-char code: first 4 chars from name + last 2 chars from uid suffix. Collision check appends additional uid chars if needed.

### Flow
1. **On `_InviteFriendsCard` init**: calls `ReferralService.ensureReferralCode()` which writes `referralCode` and `referralCount: 0` to `users/{email}`
2. **Onboarding**: user enters a referral code → `onboarding_screen.dart:81` calls `applyReferralCode(code)`
3. **applyReferralCode**: Firestore transaction —
   - Finds referrer by `referralCode` field query
   - Prevents self-referral and double-application (`referredBy` check)
   - Writes `referredBy` + `trialEndDate` (30 days) to referee doc
   - Increments `referralCount`, sets `subscriptionStatus: 'pro'`, extends `trialEndDate` (30 days) on referrer doc
4. **Settings display**: `_InviteFriendsCard` in `settings.dart` uses `.snapshots()` on `users/{email}` for real-time count updates

## Code Style

- No comments unless explicitly requested
- Use `flutter_screenutil` suffixes: `.w`, `.h`, `.sp` — never hardcoded pixels
- Use `CurrencyController.to.currencySymbol.value` — never hardcoded `₹`
- Throw `Exception("message")`, never `throw "message"`
- `QueryDocumentSnapshot.data()` is non-nullable — don't use `!`
- `DocumentSnapshot.data()` is nullable — requires `?` or null check
- All sizes use design reference `390×844`

## Transaction Sign Convention

- **Send (expense)**: `amount = -abs(value)`, `senderId = user.uid`, `recipientId = ""`
- **Receive (income)**: `amount = +abs(value)`, `senderId = ""`, `recipientId = user.uid`
- Budget aggregation: filter `amount < 0` before calling `.abs()` — using `amount.abs()` on every transaction counts income toward budget limits, triggering false over-budget alerts

## SMS Classification Priority (`lib/Services/sms_service.dart`)

1. Refund/cashback → always credit
2. `debited` / `deducted` / `withdrawn` / `spent` / `sent` → debit
3. `credited` / `deposit` → credit
4. `received by` → **debit** (merchant received from user)
5. `received in` / `received to` / `received into` / `received from` → credit
6. Default → debit

## Google Sign-In

Pinned to **v6.2.2** (`pubspec.yaml: google_sign_in: ^6.2.2`). Do **not** upgrade to v7+. v7 replaced blocking `signIn()` with `authenticate()` + `authenticationEvents` stream, which has a race condition where the result event fires before `authenticationEvents.first` starts listening.

## Common Bug Patterns to Avoid

1. **Field initializer `Get.find<>()`** — Crashes during onboarding. Always defer to `initState()` with a `Get.isRegistered()` guard.
2. **`setState()` after async gap** — Always check `if (!mounted) return;` before `setState()` following an `await`.
3. **CSV import sign stripping** — `import_service.dart` must NOT call `.abs()` on amounts; expenses must remain negative.
4. **Overlay context for global dialogs** — Use `Get.overlayContext`, never a captured `BuildContext` from before an `await`.
5. **Trial state race condition** — `subscription_controller.dart` trial flags must be set *after* Firestore confirms the write, not before.
6. **TextEditingController disposed while sheet is open** — When sheet is `StatefulWidget`, own controllers in `initState`/`dispose`. When inline, use `try/finally` (dialog) or `.whenComplete()` (bottom sheet).
7. **One-shot dashboard fetch** — Always use `streamPortfolio()` (not `getPortfolio()`) so amounts update immediately after adding entries and navigating back.
8. **Referral rules blocking cross-user writes** — `firestore.rules` must have `isReferralAllowed()` exception on `users/{userEmail}` write rule.
9. **Salary detection false positives** — In `analytics.dart _buildSalaryDetection`, filter EMI/loan transactions out of the candidate pool BEFORE computing median/max. Only check `recipientName` for exclusion keywords — `note` and `category` can legitimately be "Transfer"/"NEFT" for real salary.
10. **APK download URL** — Always construct from release tag: `releases/download/$tag/app-release.apk`. Do NOT scan `assets[]` — GitHub lists `.aab` alphabetically first.

## UPI Payments (`lib/Screens/add_transaction.dart` + `MainActivity.kt`)

Uses a **Kotlin MethodChannel** (`money_control/upi`) — not `url_launcher` — because getting the payment result back requires `startActivityForResult`. Static `_upiApps` list with hard-coded package names:
- GPay (`com.google.android.apps.nbu.paisa.user`), PhonePe, Paytm, BHIM, CRED, null (system chooser)

`canLaunchUrl()` is unreliable for UPI on Android 11+. Always show all apps and handle `APP_NOT_FOUND` via try/catch — if a specific app is not installed, retry without `packageName`.

## GetX `ever()` Workers

Every `ever()` / `once()` / `debounce()` call returns a `Worker` that must be stored and disposed:

```dart
Worker? _myWorker;
_myWorker = ever(someRx, (_) { ... });
_myWorker?.dispose(); // in dispose() or onClose()
```

## Firebase & Deployment

- `firebase.json` has `firestore.rules` config pointing to `firestore.rules`
- Deploy: `firebase deploy --only firestore --project moneycontroljustaman045`
- Rules are also applied via CI; token auth uses `FIREBASE_TOKEN` env var (deprecated, use `GOOGLE_APPLICATION_CREDENTIALS` going forward)

## Key Files

| Path | Purpose |
|------|---------|
| `lib/main.dart` | App entry, controller registration (2-phase), auth flow |
| `lib/Controllers/transaction_controller.dart` | Core transaction CRUD + stream |
| `lib/Repositories/transaction_repository.dart` | Firestore access layer |
| `lib/Screens/wealth_builder.dart` | Dashboard with `streamPortfolio()`, asset grid, navigation |
| `lib/Screens/asset_detail_screen.dart` | Generic asset detail screen + `_AddSheet` |
| `lib/Config/asset_screen_configs.dart` | All 24 `AssetScreenConfig` definitions |
| `lib/Models/wealth_data.dart` | `WealthPortfolio` model (25+ numeric fields) |
| `lib/Services/wealth_service.dart` | Portfolio CRUD, streaming, insights, target calculation |
| `lib/Services/referral_service.dart` | Referral code gen, apply, stats |
| `lib/Screens/settings.dart` | `_InviteFriendsCard` (referral display + share) |
| `lib/Screens/onboarding_screen.dart` | Onboarding with referral code input |
| `lib/Screens/vehicle_detail_screen.dart` | Custom vehicles screen |
| `lib/Screens/real_estate_detail_screen.dart` | Custom real estate screen |
| `lib/Screens/insurance_policy_screen.dart` | Custom insurance screen |
| `lib/Screens/credit_card_detail_screen.dart` | Custom credit card screen |
| `lib/Services/sms_service.dart` | SMS parsing + auto-import |
| `lib/Services/offline_queue.dart` | Offline transaction queue |
| `lib/Services/budget_service.dart` | Budget aggregation + alerts |
| `lib/Components/balance_card.dart` | Home screen balance display |
| `lib/Components/methods.dart` | Navigation + global dialogs |
| `lib/Screens/add_transaction.dart` | Send/receive money screen |
| `lib/Screens/analytics.dart` | Spending analytics screen |
| `lib/Screens/analysis.dart` | AI insights screen |
| `lib/Settings/` | `general_settings.dart`, `security_settings.dart`, `data_support_settings.dart` |
| `android/app/src/main/kotlin/.../MainActivity.kt` | UPI payment MethodChannel |
| `firestore.rules` | Security rules with `isReferralAllowed()`, per-asset wildcard |
| `firebase.json` | Firebase config (`firestore`, `flutter`, `functions`) |
