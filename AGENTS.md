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

```dart
// showDialog — try/finally
Future<void> _showDialog() async {
  final ctrl = TextEditingController();
  try {
    await showDialog(context: context, builder: (_) => ...);
  } finally {
    ctrl.dispose();
  }
}

// showModalBottomSheet — .whenComplete()
void _showSheet() {
  final ctrl = TextEditingController();
  showModalBottomSheet(...).whenComplete(() => ctrl.dispose());
}
```

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

## Known Controller Dependencies

| Controller | Depends On | Registration Location |
|------------|-----------|----------------------|
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

## Code Style

- No comments unless explicitly requested
- Use `flutter_screenutil` suffixes: `.w`, `.h`, `.sp` — never hardcoded pixels
- Use `CurrencyController.to.currencySymbol.value` — never hardcoded `₹`
- Throw `Exception("message")`, never `throw "message"`
- `QueryDocumentSnapshot.data()` is non-nullable — don't use `!`
- `DocumentSnapshot.data()` is nullable — requires `?` or null check

## Transaction Sign Convention

- Expense: `amount = -abs(value)`, `senderId = user.uid`
- Income: `amount = +abs(value)`, `recipientId = user.uid`

## SMS Classification Priority

1. Refund/cashback → always credit
2. `debited` / `deducted` / `withdrawn` / `spent` / `sent` → debit
3. `credited` / `deposit` → credit
4. `received by` → **debit** (merchant received from user)
5. `received in` / `received to` / `received into` / `received from` → credit
6. Default → debit

## Google Sign-In

Pinned to v6.2.2. Do NOT upgrade to v7+.

## Key Files

| Path | Purpose |
|------|---------|
| `lib/main.dart` | App entry, controller registration, auth flow |
| `lib/Controllers/transaction_controller.dart` | Core transaction CRUD + stream |
| `lib/Repositories/transaction_repository.dart` | Firestore access layer |
| `lib/Services/sms_service.dart` | SMS parsing + auto-import |
| `lib/Services/offline_queue.dart` | Offline transaction queue |
| `lib/Services/budget_service.dart` | Budget aggregation + alerts |
| `lib/Components/balance_card.dart` | Home screen balance display |
| `lib/Components/methods.dart` | Navigation + global dialogs |
| `lib/Screens/add_transaction.dart` | Send/receive money screen |
| `lib/Screens/analytics.dart` | Spending analytics screen |
| `lib/Screens/analysis.dart` | AI insights screen |
| `android/app/src/main/kotlin/.../MainActivity.kt` | UPI payment MethodChannel |
