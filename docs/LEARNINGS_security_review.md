# Learnings: Security/Privacy/Build Review Findings

## 1) Full Backup Restore (identity remap)
- **Issue**: `FullBackupService.restoreFromFile` writes collections as-is without remapping identity fields (`uid`, `senderId`, `recipientId`, `email`, account identifiers). Restoring to a recreated account leaves transactions tied to the old identity.
- **Location**: `lib/Services/full_backup_service.dart:296`, `lib/Services/full_backup_service.dart:365`
- **Recommendation**:
  - When restoring into the *current signed-in account* (or on re-signup), remap: set `uid = currentUser.uid`, normalize `email` to current user email, rewrite `senderId`/`recipientId` to reflect current user, and update profile fields to current identity where appropriate.
  - Also strip server-authoritative/profile-sensitive fields (already handled for some) and ensure ownership is enforced.
  - Add tests covering restore to a different account/after account recreation.
  - Consider refusing restore if source email differs from current email, or require explicit confirmation + remap.

## 2) Account Deletion Order
- **Issue**: Firestore deletion before `FirebaseAuth.instance.currentUser?.delete()` means auth failure after data wipe leaves signed-in empty account.
- **Location**: `lib/Services/user_service.dart:93`
- **Recommendation**:
  - Prefer deleting auth user first if possible (with re-auth), or do in safe order: ensure re-auth, delete auth account, then delete Firestore data (or use Cloud Functions with Admin SDK). 
  - Or: delete data in a way recoverable/with confirmation, and if auth deletion fails, attempt to restore/flag account and sign out safely. Never leave user signed in with all data deleted without clear recovery path.
  - Add error handling and state rollback/cleanup logging.

## 3) GDPR "Delete all data" Incomplete
- **Issue**: Only updates consent fields; name, phone, address, photo URL, provider, UID, other profile data remain.
- **Location**: `lib/Screens/terms_and_policy.dart:117`
- **Recommendation**:
  - Delete or anonymize all user document fields in `users/{email}` (or the profile doc). Follow principle of data minimization / complete erasure.
  - Use `UserService.deleteAccount()` flow or ensure all profile fields are cleared. Consider writing a tombstone if required by law but remove PII.
  - Audit all profile fields and ensure rules/flows cover them.

## 4) Subscription State Leak Between Accounts
- **Issue**: Web/native callbacks apply snapshots using captured email without verifying current account; missing-user snapshots fail to clear `trialEndDate`, `trialUsed`, `planType`.
- **Location**: `lib/Controllers/subscription_controller.dart:80`, `lib/Controllers/subscription_controller.dart:141`
- **Recommendation**:
  - Always verify `FirebaseAuth.instance.currentUser?.email` matches the snapshot email before applying. If not, ignore or clear.
  - On sign-out/account change, reset all subscription state (`resetForSignOut()` already exists). Ensure listeners are cancelled or gated.
  - When user doc doesn't exist, explicitly reset trial/plan fields to defaults (not just leave stale values).
  - Add guards in stream callbacks.

## 5) Release Signing Fallback to Debug
- **Issue**: Missing signing secret produces release APK/AAB signed with debug keystore.
- **Location**: `android/app/build.gradle.kts:39`
- **Recommendation**:
  - Fail the build if release signing config is incomplete/missing (do not fall back to debug). 
  - Use `signingConfigs` properly with environment variables/keystore files; validate in CI.
  - Add check: if building release and no valid signing key, throw Gradle error.
  - Never ship debug-signed release builds.

## 6) Offline Queue Cross-Account Sync
- **Issue**: Device-global queue syncs pending records into whichever account is currently signed in without validating owner.
- **Location**: `lib/Components/methods.dart:55`
- **Recommendation**:
  - Include `ownerEmail`/`ownerUid` in queued transaction records.
  - On sync, verify owner matches current signed-in user; if not, discard or quarantine (don't write to wrong account).
  - Clear queue on sign-out/account switch.
  - Add tests for account switching with pending queue.

## 7) GDPR Export Incomplete
- **Issue: Export omits `backups`, `insips` (typo?) `insights`, `preferences`, `logs` which are treated as user data in deletion/rules.
- **Location**: `lib/Screens/Settings/data_support_settings.dart:153`
- **Recommendation**:
  - Include all user-owned subcollections used by deletion flow (`UserService.subcollections` includes relevant ones; check if export misses backups/insights/preferences/logs). 
  - Align export scope with deletion scope.
  - Add contract test comparing export and deletion scopes.

## 8) Sensitive Android Permissions
- **Issue: Manifest requests SMS, MMS/WAP push, location, camera, APK installation permissions - require Play policy justification/declarations.
- **Location**: `android/app/src/main/AndroidManifest.xml:4`
- **Recommendation**:
  - Review each permission against core functionality and Play Console policies (especially SMS/READ_SMS/RECEIVE_SMS, REQUEST_INSTALL_PACKAGES).
  - Remove unnecessary permissions; use runtime permissions with rationale.
  - If SMS is core feature, ensure declaration/form is submitted. REQUEST_INSTALL_PACKAGES is highly restricted.
  - Consider using `tools:remove` or splitting by product flavors if not needed for all variants.

## Validation
- `flutter analyze --no-fatal-infos`: passed
- `flutter test`: 572 tests passed
- `flutter build web --release`: passed
- UI audit at caps: passed
- WASM warnings from `image 4.5.4` are dependency-related, not app failures.
