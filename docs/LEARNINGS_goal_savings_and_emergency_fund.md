# Learnings: goal savings suggestions, emergency-fund cash, and CI green-state

Durable notes from the monthly-allotment / Wealth-tab work (`2.0.292`–`2.0.295`).
Each item below was expensive to rediscover and is pinned by a test or a CI run.

## 1) The emergency fund is a flagged goal, not a standalone account

- There is **no** emergency-fund Firestore collection or model. It is a regular
  goal doc at `users/{email}/goals/{goalId}` with `isEmergencyFund: true`, plus
  `EmergencyFundService` which derives a **target** (`6 × monthly income`) from
  `computeExpectedIncome`.
- `TransactionController.totalBalance` is the transaction-derived bank cash.
  Net worth (`wealth_builder.dart` → `_buildNetWorthCard`) reads that balance,
  the `wealth/portfolio` doc, custom assets and liabilities. It **never** reads
  goals — so adding `currentAmount` to net worth double-counts cash that was
  seeded from that same balance.
- Product decision confirmed with the user: money put into the EF is an
  **earmark**, not a new inflow. It may sit in the tracked bank account *or a
  different bank account*. Add Progress on a goal creates **no** transaction.

## 2) `seededFromBank` / `cashOutsideBank` is the double-count guard

- `GoalModel.seededFromBank` records how much of the EF's `currentAmount` came
  from the live bank balance (already in Net worth via Bank).
- `GoalModel.cashOutsideBank` = `max(0, currentAmount - seededFromBank)` for EF
  goals only, `0` for ordinary goals. This is the only part safe to add to Bank
  and Net worth.
- `GoalsController.emergencyFundCashOutsideBank` exposes it; `wealth_builder.dart`
  adds it via `cashIncludingEmergencyFund` to the Bank card, net-worth card,
  allocation pie and ideal-income chart, and watches `GoalsController.goals`
  with an `ever` worker so deposits refresh those figures.
- `EmergencyFundService._seedProgress` uses `GoalsController.setProgress`
  (not `updateProgress`) so seeding an existing balance never fakes a monthly
  Add Progress allotment. `migrateLegacySeed()` back-fills the overlap once for
  old EF goals; it waits for `GoalsController.goals` to load and is guarded by
  `_legacySeedChecked`.
- Tests: `test/goal_model_test.dart` → `GoalModel.cashOutsideBank` group
  (seed excluded, beyond-seed counted, legacy zero, never negative, ordinary
  goals zero, Add Progress preserves seed, serialization round trip).

## 3) Savings suggestions: the shown amount must equal the drop-out threshold

**Bug reported by the user:** "suggested 54, I add 54, then it asks for 45 more,
then removes it." Reproduced exactly as a `3000 → 1500 → …` loop.

- Root cause: two different numbers were used. Drop-out compared the month's
  allotment against a fixed **full-pot baseline**, but the UI displayed a
  re-split of the **remaining pot**. When other goals had already consumed part
  of the pot, the displayed amount was smaller than the hidden baseline, so
  depositing it left the goal in the list asking for a smaller amount again.
  Concretely: pot 10000, goal A allotted 0, goal B allotted 4000 → A shown 3000
  but baseline 5000; add 3000 → shown 1500; add 1500 → shown 750; … until 5000.
- Fix in `computeGoalSavingsPlan` (`lib/Utils/wealth_math.dart`): iterate to a
  fixed point — drop every goal whose `monthlyAllocation` meets the amount
  **currently shown** (its `split.allocation[id]`), re-split `availablePot`
  across the survivors, repeat until the list stops shrinking. EF 60% cap and
  "last goal standing" unlock are recomputed each pass.
- Invariants preserved: displayed suggestions sum to "Available to allot", EF
  priority and deadline urgency still drive the split, all prior plan tests
  pass unchanged.
- Regression test: `test/goal_savings_plan_test.dart` → "adding the shown
  suggestion removes the goal even when another goal already consumed part of
  the pot". It **fails** against the old baseline code (shows 3000, expected
  6000) and passes with the fix.
- General rule: any future change to this plan must keep "the amount displayed
  for a goal" identical to "the amount that drops the goal", or the loop returns.

## 4) CI green-state recovery loop (repeat for every push)

- Pre-push gate, in order: `flutter analyze --no-fatal-infos` →
  `bash tool/check_ui_strings.sh --strict` → `flutter test` →
  `flutter build web --release --base-href /WealthSync/`.
- After pushing, watch with
  `gh run watch <id> --interval 30 --exit-status > /tmp/opencode/ci_x.log 2>&1; echo "CI_EXIT=$?" >> /tmp/opencode/ci_x.log`
  in the background; do **not** poll — the shell notification carries the result.
- `Publish GitHub release` commits a `CI: Release <version>` bump. Pull it with
  `git pull --ff-only origin master`, then verify `pubspec.yaml` version and
  `gh release view --json tagName,publishedAt`. Only then declare work done.
- The user's bar is "everything is good to go for the users": all active jobs
  green **and** the release tag published, not just local tests passing.

## 5) Signals that look bad but are not

- `kotlin-stdlib:2.2.21` resolution failure in "Build AAB with signing" was
  transient — a rerun passed. No `android/` change was involved.
- Version-bump collisions (`[rejected] master -> master (fetch first)`,
  `CONFLICT in app_version.json / pubspec.yaml`) come from overlapping runs;
  they clear on a fresh push based on the already-bumped master. See
  `docs/LEARNINGS_dependabot_release_race.md` §2.
- Node.js 20 deprecation annotation from `softprops/action-gh-release@v2` is
  harmless (runner forces Node 24).
- Integration tests and Firebase rules deploy are skipped in CI by design.
