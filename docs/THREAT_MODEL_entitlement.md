# Threat model: Pro entitlement without a server

WealthSync runs on the Firebase **Spark (free)** plan, so the project cannot
deploy Cloud Functions. There is no server-side purchase verification and no
privileged write path: every entitlement decision is made either in Dart on the
device or by `firestore.rules` on the Firestore server.

This document records what that buys, what it costs, and which residual risk is
accepted on purpose. It is the reference for the next person who asks "why not
just verify the receipt?" — the answer is a billing decision, not a bug.

## What "Pro" means in the data model

`users/{email}` carries the entitlement:

| Field | Meaning |
|-------|---------|
| `subscriptionStatus` | `'pro'`, `'pending'`, `'free'` |
| `isPro` | mirror of `subscriptionStatus == 'pro'`, kept for older reads |
| `purchaseToken` | Google Play purchase token (written by `IapService`) |
| `planType` / `expiryDate` | plan label and the verified expiry |
| `trialEndDate` | end of a free trial **or** a referral grant |
| `referralCount` / `referralCredited` | referral bookkeeping, see below |
| `isAdmin` | admin surface access; set from the console only |

The client (`SubscriptionController`) computes `isPro` as
`status == pro || trialEndDate in the future || isAdmin`. Every gate in the UI
reads that, and nothing else.

## Enforcement points

1. **`firestore.rules`** — the only enforcement that survives a modified APK.
   - `isOwnerUpdate` refuses `isAdmin`, `referredBy` and `referralCredited`,
     refuses any `referralCount` change (a payout goes through
     `isClaimPayout`), and allows `trialEndDate` only to move *earlier*
     (`isTrialShrink`).
   - `isTrialStart` — the first trial, 7 days, only when `trialEndDate` is
     absent (the same signal the UI derives `trialUsed` from). It also checks
     ownership *itself* and allows `trialEndDate` as the **only** changed
     field: `allow update` ORs its branches, so a branch without those two
     guards could write any account's profile (or carry a purchase-looking Pro
     claim alongside the trial date) while still being a "trial grant".
   - `isReferralApplication` — one 30-day month per profile, and only for a code
     document that exists and is not the caller's own.
   - `isClaimPayout` — the only way to extend an existing `trialEndDate`: the
     profile's `referralCredited` ledger must grow, each newly credited uid must
     be a claim recorded on the caller's code document, the ledger may never
     shrink, and the extension is at most 30 days per credited claim (hard
     ceiling 45 days ahead through `validTrialCap`).
   - `isProfileErase` — the explicit data-erase reset, and the only write that
     may *drop* `trialEndDate`/`referralCredited`/the entitlement fields. Because
     it may touch any field, it also refuses to put a gated value back: the
     erase cannot set `isAdmin` (an admin may still drop it), cannot end with a
     `trialEndDate` or `referralCredited`, and cannot end `isPro: true` or
     `subscriptionStatus: 'pro'`. Without that, "erase my data" doubled as
     "make me an admin".
   - `subscriptionStatus: 'pro'` and `isPro: true` require `validProClaim` — a
     non-empty `purchaseToken`. A naive "write pro" self-grant fails.
   - Admins (`users/{email}.isAdmin`) may write another user's entitlement, by
     design; `isAdmin` is not writable from the client.
2. **The client** — `IapService` writes `subscriptionStatus`/`purchaseToken`
   only after a Google Play purchase reports `purchased` and the verification
   step returns. This is a UX and correctness layer (so a legitimately paid user
   gets their Pro immediately), not a security boundary.

## Attack surface and outcome

| Attack | Outcome |
|--------|---------|
| Write `subscriptionStatus: 'pro'` / `isPro: true` from a modified client | **Blocked** — no `purchaseToken` |
| Write `isAdmin: true` (create or update) | **Blocked** for non-admins |
| Write `isAdmin: true` inside an "erase my data" write | **Blocked** — the erase branch re-checks the gated fields |
| Write another user's profile through the trial branch | **Blocked** — each grant branch checks ownership itself |
| Write into another user's document | **Blocked** (owner-only) |
| Start a second free trial | **Blocked** — `trialEndDate` already exists |
| Extend a trial by rewriting `trialEndDate` | **Blocked** — a later date needs a claim-backed payout |
| Self-refer with your own code | **Blocked** — rules and client both compare owner uid |
| Replay a referral claim | **Blocked** while the ledgers persist — a claim in `referralCredited` (or the code document's `credited`) cannot fund a second extension |
| Invent a code (`referredBy: 'NOPE'`) for 30 days | **Blocked** — the code document must exist |
| Apply a real code twice to roll the month forward | **Blocked** — a profile may apply once |
| Grant Pro to a friend's account (the old `isReferralReward`) | **Blocked** — the rule is gone |
| Read a code document to harvest the owner's email | **Not possible for new codes** — the document stores `ownerUid` only. Legacy documents still carry `owner` and are not migrated, since the rules accept both shapes. |
| Forge a purchase token (any non-empty string) | **Succeeds** — see below |
| Delete and recreate your own profile to reset the ledger | **Succeeds, bounded** — see below |
| Erase data (GDPR) and start a fresh trial | **Succeeds, bounded** — see below |

## Accepted residual risk

**1. A forged purchase token passes `validProClaim`.** The rule can prove a
purchase token *exists*, not that Google issued or charged for it. A modified
client can write `{subscriptionStatus: 'pro', purchaseToken: 'x'}` and keep Pro
indefinitely.

This is the cost of the Spark plan and the only item that grants unlimited Pro.
It is accepted because:

- Exploiting it requires installing a modified APK, understanding Firestore
  field names, and having a valid login — i.e. it is not reachable from the
  shipped app or from any UI path.
- The server-side alternative (Play Developer API verification of the purchase
  token, with a service-account credential) needs a Cloud Function, which needs
  Blaze. When that upgrade happens, the fix is a single callable function that
  re-verifies `purchaseToken` and writes the entitlement with the Admin SDK;
  rules would then refuse client writes to those fields entirely.
- Revenue at risk is bounded by the size of the user base that is willing to
  reverse-engineer the client, and a paid tier is usually the response.

**2. Deleting and recreating the profile resets the ledgers.** A user may delete
their own `users/{email}` document (the account-deletion and GDPR flows do it
anyway) and then write a fresh one. `referralCredited` goes with it, so the same
claims become payable again — but only while the code document still lists them
*and* its own `credited` map is not consulted... which it is, by the client
(`_drainClaims` takes the union), so a *shipped* client cannot replay. A
*modified* client can, and the ceiling is `validTrialCap`: 45 days ahead, never
more, and it cannot be re-earned once the code document is gone.

The same trick resets `trialEndDate`, buying another 7-day first trial. That is
the same 7 days the GDPR erase already implies.

**3. The GDPR erase buys a fresh 7-day trial** (and, if the profile is rewritten
with a code again, a referral month — the reset removes `referredBy` too).
`isProfileErase` is the only write allowed to remove `trialEndDate`, because a
plain removal would let any client reset `trialUsed` at will. Erasing all of
one's financial data for seven-to-thirty days of Pro is a bad trade for the
user, so it is not treated as an attack.

**4. Admins can grant anything.** `isAdmin` is console-only and the admin writes
are audited (`AuditController`); this is the intended escape hatch for support.

## Compatibility with installed builds

Rules ship to every client at once, while installed APKs update over days. Two
shapes the previous release (2.0.202) writes are affected:

- Its referral payout writes `{referralCount, trialEndDate}` **without**
  `referralCredited`, which `isClaimPayout` refuses (no newly credited claim ⇒
  no extension). The payout is *deferred*, not lost: the claim is still on the
  code document, and the next payout from an updated client includes it because
  the client's unpaid set is the union of both ledgers.
- Its trial start (`trialEndDate: now + 7d`, no existing key) and its
  cancel/expire writes (a past `trialEndDate`, `isPro: false`) all satisfy the
  new rules.

Everything else 2.0.202 writes — profile fields, onboarding, transactions,
assets, and code creation with the legacy `owner` + `ownerUid` shape — keeps
working; the code-document rules accept both shapes.

## What would change under Blaze

In priority order, if the project ever moves to a paid plan:

1. A callable/HTTPS function that verifies `purchaseToken` against the Play
   Developer API and writes `subscriptionStatus`/`expiryDate` with the Admin
   SDK. Remove client write access to those fields from `firestore.rules`.
2. A scheduled function that expires subscriptions and reconciles Play
   `subscriptionStatus` (the client's `_expireSubscription` is best-effort and
   only runs when the app is open).
3. Real-time Database or Firestore triggers for referral payout, so the claim
   ledger lives server-side and the delete/recreate resets above disappear.

Until then, the rules above are the contract: they are covered behaviourally by
`tool/rules_tests/run.js` (27 entitlement checks out of 48, against the
Firestore emulator) and textually by `test/referral_test.dart`. Changing a bound in
`firestore.rules` without updating both is how this file becomes a lie.

## Deployment note

Rules are **not** deployed by CI on push. `deploy_firebase` is a manual
`workflow_dispatch` job (dry-run first) because it mutates production security
rules for every installed client — including the ones that cannot be patched.
