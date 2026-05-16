# WealthSync Flutter Project — Session Learnings

## Project Context
Personal finance app, Flutter + GetX + Firebase (Spark plan). This session implemented 5 outstanding tasks + 1 bug fix.

---

## Tasks Completed

### 1. Balance Bug Fix (`.limit(50)` on stream)
- **Problem**: The transaction stream had `.limit(50)` applied, so `totalBalance` only summed the latest 50 transactions, not all of them. Balance dropped from ~43K to -5.6K.
- **Fix**: Removed `.limit(50)` from `bindTransactions()`. Added `LocalCacheService.invalidate(_cacheKey)` after loading cache to force re-fetch with complete data.
- **Rule**: Never `.limit()` a stream that feeds `totalBalance` — it iterates ALL transactions.

### 2. Firestore Rules Hardening (`firestore.rules`)
- Split `allow write` into `create`/`update`/`delete` on `users/{userEmail}`
- Added `isPrivilegeElevation()` function blocking owner updates to: `isAdmin`, `referralCount`, `subscriptionStatus`, `trialEndDate`, `referredBy`
- Referral writes still work via `isReferralAllowed()` exception
- Deployed: `firebase deploy --only firestore`

### 3. Account Deletion (`lib/Services/user_service.dart`)
- `_subcollections` grew from 11 to 36 entries (+ `category_rules` + all 24 asset subcollections)
- `wealth/portfolio` doc now deleted explicitly before the subcollection loop
- No more orphaned data after deletion

### 4. GDPR Data Export (`lib/Screens/Settings/data_support_settings.dart`)
- New `_handleGdprExport()` fetches wealth doc + all 36 subcollections as structured JSON
- `FilePicker.platform.saveFile(bytes: bytes, fileName: 'WealthSync_gdpr_export.json')`
- Timestamps serialized to ISO strings; metadata (exported_at, user_email) included
- New "Export All Data (GDPR)" tile added to settings

### 5. SmsService Static Cache Leak
- `SmsService` has static `_correctionCache`, `_historyCache`, `_rulesLoaded` — stale across sessions
- Added `SmsService.resetCache()` to logout path in `main.dart`

### 6. Onboarding State Fix (`lib/main.dart`)
- `_checkOnboardingStatus(email)` checks Firestore `users/{email}.is_onboarded` first
- If found in Firestore, syncs to SharedPreferences (survives app reinstall)
- Falls back to SharedPreferences if Firestore fetch fails or field doesn't exist

### 7. SMS Parsing Bug Fix
- **Problem**: "debited by 86.00" format not caught by primary regex (only had `Rs|INR|MRP|Amt|Amount`)
- Fallback bare-amount regex matched `5488` from `X5488` before `86.00`
- **Fix**: Added `debited by|credited by|by Rs\.?` to primary amount regex
- Bare amount fallback simplified: `\d{2,}` without comma grouping (western comma notation was wrong for Indian amounts anyway)

---

## Key Architectural Decisions

### Cache Strategy (Spark plan optimization)
- SharedPreferences (not Hive — SDK incompatibility with Dart 3.11)
- TTLs: 30s transactions, 60s wealth, 5min everything else
- Cache-first: show stale data immediately, stream refreshes in background
- Prefix `cache_` to avoid collisions with app prefs
- App version auto-invalidation via `package_info_plus`
- Only transaction controller keeps `.snapshots()` (real-time balance feel)
- All other controllers use one-shot `.get()` with cache

### Firestore Read Budget
- Before: ~600 reads/user/day (unbounded streams) → ~80 users max on Spark
- After: ~30 reads/user/day (cache-first + one-shot) → ~1000+ users on Spark

## Files Modified

| File | Change |
|------|--------|
| `firestore.rules` | `isPrivilegeElevation()`, split write into create/update/delete |
| `lib/Services/user_service.dart` | 36 subcollections (was 11), explicit wealth doc deletion |
| `lib/Screens/Settings/data_support_settings.dart` | GDPR JSON export handler + new tile |
| `lib/main.dart` | `SmsService.resetCache()`, `_checkOnboardingStatus()` |
| `lib/Services/sms_service.dart` | Added `debited by\|credited by` to amount regex |
| `lib/Controllers/transaction_controller.dart` | Removed `.limit(50)`, added cache invalidation after read |
| `lib/Repositories/transaction_repository.dart` | Removed unnecessary `as Query` cast |
