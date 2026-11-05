# Learnings: Dependabot failures, release race, and green-state recovery

## 1) Dependabot security-update job failing: `security_update_not_possible` (minimatch)

- **Issue**: The scheduled Dependabot workflow (`npm_and_yarn` against
  `/tool/rules_tests`) failed on the default branch with
  `security_update_not_possible` for `minimatch`.
- **Detail**: earliest fixed version `11.0.1`; latest resolvable version
  `9.0.9`. Blocking path: `firebase-tools@15.34.1 -> glob@10.5.0 (minimatch ^9.0.4)`.
- **Fix**: added `minimatch` to the `ignore` list of the
  `package-ecosystem: npm / directory: /tool/rules_tests` entry in
  `.github/dependabot.yml` (same policy as the pre-existing `uuid`,
  `@grpc/grpc-js`, `@opentelemetry/core` ignores), with an explanatory comment.
- **Follow-up**: Dependabot subsequently opened
  `chore(deps): bump firebase-tools from 15.34.1 to 15.34.2 in /tool/rules_tests`
  (PR #21) — the real upstream fix path; merged.

## 2) Release-publish job failed on a merge-commit push

- **Issue**: After merging Dependabot PRs, the `Publish GitHub release` job of
  the `Build Flutter APK` workflow failed: the version-bump commit (`CI: Release
  2.0.267`) was created, then the push was rejected (remote moved during the
  run) and the retry rebase hit conflicts in `pubspec.yaml` / `app_version.json`.
- **Fix / state**: cleared by dispatching a fresh `Build Flutter APK` workflow
  run on `master` (run `42087546412`) which completed **success** across all jobs,
  including `Publish GitHub release`. Releases continued: `v2.0.268` (latest).

## 3) Operational notes that made this tractable

- The `Publish GitHub release` job commits `CI: Release <version>` and pushes;
  the workflow has rebase-retry logic, but a fast-moving master can still make
  the rebase conflict — re-running the same run does not clear it; a fresh run on
  a stable head does.
- Dependabot PRs that only touch CI tooling (GitHub Actions bumps) are validated
  by the `test` job; the release/publish/smoke jobs are skipped on PRs.
