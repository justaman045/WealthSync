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
flutter test                        # 3 unit/widget test files
flutter run
flutter build apk --release
flutter build appbundle --release
flutter gen-l10n                    # after editing ARB files in lib/l10n/
```

CI (`.github/workflows/flutter_build.yml`): analyze → test → build. Flutter **3.35.5**, Dart `^3.9.2`. Version auto-bumped by CI (`pubspec.yaml`, `app_version.json`, README download link).

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
| `test/` | 3 unit/widget test files |
| `integration_test/` | 7 integration tests (require Firebase emulator) |

ThemeController is inline in `main.dart` (registered before any screen).

## Controller Registration (2-Phase)

**Phase 1 — `mainCommon()`**: PrivacyController, CurrencyController, AuthController, SubscriptionController, PaymentConfigService, IapService, BiometricService.

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

**Dashboard** must use `streamPortfolio()` (not `getPortfolio()`) — one-shot fetch leaves amounts stale after navigating back. Confirmed in `wealth_builder.dart:56` (primary subscription). Note: `_loadData()` at line 82 also calls `getPortfolio()` for geo-enrichment, but the primary real-time data comes from the stream.

**Generic screen**: `AssetDetailScreen(config:)` for all 24 types. Custom screens: `RealEstateDetailScreen`, `VehicleDetailScreen`, `InsurancePolicyScreen`, `CreditCardDetailScreen`.

## Code Style

- `flutter_screenutil` suffixes (`.w`, `.h`, `.sp`) — no hardcoded pixels; design ref 390×844
- `CurrencyController.to.currencySymbol.value` — never `₹`
- `Exception("message")` — never `throw "message"`
- `QueryDocumentSnapshot.data()` is non-nullable (no `!` or `as Map`)
- `DocumentSnapshot.data()` is nullable (needs `?` or null check)

## SMS Classification

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
6. **`compact()` rounds** — `compact(1500)` → `"2K"` (not `"1.5K"`).
7. **Don't mix GetX + Flutter navigator** — `Get.dialog()` + `Navigator.pop()` + `Get.snackbar()` crashes. Use `showDialog()` + `Navigator.of(context, rootNavigator: true).pop()` + `ScaffoldMessenger.showSnackBar()`.
8. **FilePicker.saveFile() returns content:// on Android** — cannot `File(uri).writeAsString()`. Pass `bytes: Uint8List.fromList(utf8.encode(csv))`.
9. **`orderBy() as Query` is unnecessary cast** — triggers `unnecessary_cast` warning.
10. **SmsService static cache leak** — `resetCache()` called on logout to clear static `_correctionCache`, `_historyCache`, `_rulesLoaded`.
11. **Trial state race** — subscription trial flags must be set *after* Firestore confirms the write.
12. **BackdropFilter sigma** — keep sigma ≤ 4 and wrap in `RepaintBoundary`. Sigma 10 + two instances = severe scroll jank (`glass_container.dart`).
13. **Avoid ShaderMask on animated text** — renders child offscreen each frame. Use direct `TextStyle(color:)` instead (`balance_card.dart`).
14. **setState in TweenAnimationBuilder.onEnd** — triggers full subtree rebuild on every animation completion. Use `ValueNotifier` + `.value = ` instead.
15. **Cache O(n) getters** — `totalBalance` iterates all transactions. Use `Rx` + `ever` worker so the loop only runs when data actually changes (`transaction_controller.dart`).
16. **Cache Theme.of** — 13 calls per build in `analytics.dart` → cache `_cachedTheme` and `_cachedIsDark` in `build()`, restore `get isDark => _cachedIsDark`.
17. **Unchecked `jsonDecode` casts** — always check `is Map` / `is List` before `as`. Prevents crashes on corrupted cache (`category_service.dart`, `offline_queue.dart`, `sms_import_screen.dart`).

## Platform-Specific

- **Google Sign-In**: Pinned to `^6.2.2` (`pubspec.yaml`). Do not upgrade to v7+ — `signIn()` replaced with stream-based API that has a race condition.
- **UPI Payments**: Kotlin MethodChannel (`money_control/upi`), not `url_launcher`. Hard-coded package names: GPay, PhonePe, Paytm, BHIM, CRED, null (system chooser). `canLaunchUrl()` unreliable on Android 11+ — show all apps and handle `APP_NOT_FOUND` via try/catch.
- **Built-in Kotlin**: As of Flutter 3.35, plugins that apply KGP directly (`file_picker`, `firebase_storage`, `home_widget`, `share_plus`, `shared_preferences_android`, `workmanager_android`, `package_info_plus`) trigger a migration warning. Track upstream updates; no action needed until Flutter drops KGP support.
- **google-services.json**: Gitignored. CI injects from `secrets.GOOGLE_SERVICES_JSON`. For local builds, download from Firebase Console to `android/app/google-services.json`.
