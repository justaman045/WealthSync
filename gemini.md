# WealthSync Flutter Project — Session Learnings

## Project Overview
Personal finance Flutter app using GetX + Firestore. MVC-Service-Repository pattern. Targeting Spark (free) plan by caching aggressively with SharedPreferences.

## Architecture
- State: GetX controllers (`GetxController` with Rx vars, `bindStream`, cache-first loading)
- DI: `Get.put()` / `Get.find()` (2-phase: app-wide in `mainCommon()`, auth-dependent in `AuthChecker._handleAuthChange()`)
- Cache: `lib/Services/cache_service.dart` — TTL-based SharedPreferences with `cache_` key prefix
- Models: Plain Dart classes with `fromMap`/`toMap` (Firestore serialization)
- Assets: 24 subcollections + `wealth/portfolio` summary doc

## Critical Rules

### 1. `.limit()` breaks balance on stream
Don't use `.limit(N)` on transaction streams that feed `totalBalance`. Balance sums ALL transactions. Limit only applies to cached snapshot, not stream.

### 2. Cache invalidation after read
```dart
void _loadFromCache() {
  final cached = LocalCacheService.get(_cacheKey);
  if (cached != null) { /* restore from cache */ }
  LocalCacheService.invalidate(_cacheKey); // Always invalidate after read
}
```
This prevents stale/incomplete cached data (e.g., from previous `.limit()`) from persisting.

### 3. Firestore rules: split user doc write
```javascript
function isPrivilegeElevation() {
  let affected = request.resource.data.diff(resource.data).affectedKeys();
  let blocked = ['isAdmin', 'referralCount', 'subscriptionStatus', 'trialEndDate', 'referredBy'];
  return affected.hasAny(blocked);
}

match /users/{userEmail} {
  allow create: if isOwner(userEmail);
  allow update: if (isOwner(userEmail) && !isPrivilegeElevation()) || isReferralAllowed();
  allow delete: if isOwner(userEmail);
}
```

### 4. Account deletion must be exhaustive
The `_subcollections` list must include ALL 36 collections (11 core + `category_rules` + 24 asset subcollections). Explicitly delete `wealth/portfolio` doc. Partial deletion leaves orphaned data.

### 5. GDPR export: include everything
Export wealth doc + all 36 subcollections as JSON. Serialize Timestamps to ISO strings. Include metadata (exported_at, user_email).

### 6. SmsService static leak
```dart
// Called in main.dart logout path
SmsService.resetCache(); // clears _correctionCache, _historyCache, _rulesLoaded
```

### 7. Onboarding: Firestore first, SharedPreferences fallback
```dart
Future<bool> _checkOnboardingStatus(String email) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
  if (doc.exists && doc.data()?['is_onboarded'] == true) {
    await prefs.setBool('is_onboarded', true); // sync to local
    return true;
  }
  return prefs.getBool('is_onboarded') ?? false;
}
```

### 8. SMS amount regex for Indian UPI messages
Primary regex must include `debited by|credited by` patterns. Indian banks use "debited by 86.00" format (no Rs/INR prefix). The bare amount fallback finds leftmost 2+ digit number which can match wrong values (e.g., "X5488" before "86.00").

### 9. SharedPreferences cache store
Hive 2.x requires SDK <3.0.0 (incompatible with Dart 3.11). Use SharedPreferences with:
- JSON encode/decode
- TTL wrappers
- Timestamp→ISO→Timestamp serialization
- `cache_` prefix for keys
- App version auto-invalidation via `package_info_plus`

### 10. No unnecessary casts
`collectionRef.orderBy()` already returns `Query`. `as Query` triggers `unnecessary_cast` warning which fails CI with `--no-fatal-infos`.

### 11. `var doc.data()` is non-nullable on QueryDocumentSnapshot
In cloud_firestore 4.x, `QueryDocumentSnapshot.data()` returns `Map<String, dynamic>` (non-nullable). No `as Map<String, dynamic>` cast needed.

## File Locations

| File | Purpose |
|------|---------|
| `lib/Services/cache_service.dart` | SharedPreferences TTL cache |
| `lib/Controllers/transaction_controller.dart` | Cache-first + snapshots stream |
| `firestore.rules` | Rules with `isPrivilegeElevation()`, `isReferralAllowed()`, 36 subcollections |
| `lib/Services/user_service.dart` | Account deletion cascade (36 subcollections) |
| `lib/Screens/Settings/data_support_settings.dart` | CSV export + GDPR JSON export |
| `lib/Services/sms_service.dart` | SMS parsing (amount regex + debit/credit classification) |
| `lib/main.dart` | Onboarding check, SmsService.resetCache() on logout |

## Dependency Order
- **mainCommon()**: Privacy, Currency, Auth, Subscription, PaymentConfigService, IapService, BiometricService
- **_handleAuthChange() after login**: Transaction → Profile → Analytics → Budget → Goals → Loan → Challenges → LentMoney → RecurringPayment
