#!/usr/bin/env bash
# Runs the integration-test suite one file at a time so a single hung file
# (test-body or app-connect level) can never block the rest of the suite. Each
# file gets a hard `timeout`; screenshots are pulled from the emulator after
# every file so a later failure can't lose earlier files' images. The exit code
# is non-zero if ANY file failed or was killed — the workflow gates the release
# build on this job passing.
#
# If a file fails because the emulator's adb connection dropped (gfxstream
# wedges on this headless setup), the device is recovered once and the file is
# retried, so one emulator hiccup can't cascade into "no device found" failures
# for every remaining file. Real test failures (device still reachable, test
# events emitted) are NOT retried — a genuine bug should not silently double
# its CI time.
#
# The one exception is a launch-level failure (device still reachable): the 15m
# timeout kill (exit 124) signals the app froze/ANR'd under the software
# renderer and never printed a result, and an empty reporter file signals the
# app never connected or the tool died before any output. Both can leave the
# emulator in a bad state, so they are retried once on a fresh qemu — a genuine
# bug will just fail the retry too. A failure that also took the device offline
# flows through the recovery path instead.
#
# Recovery only helps an adb wedge — it can never revive a dead emulator
# PROCESS (qemu gone, port 5554 refused). If recovery fails once, the emulator
# is presumed dead and every remaining file is skipped fast (a ~2 min tail)
# instead of burning ~85 s of futile recovery per file.
#
# Credentials come from the environment (set as step env on the calling
# workflow), never interpolated into this file.
#
# Invoked as a single `bash tool/run_integration_tests.sh` line because
# reactivecircus/android-emulator-runner executes its `script:` input one line
# at a time via `/usr/bin/sh -c`, which cannot carry multi-line loops.
set -e

mkdir -p build/report/parts build/report/screenshots
# Purge stale per-file reporter JSON. A file skipped because the emulator died
# writes no new JSON, so last run's file would otherwise be parsed by
# generate_test_report.dart and rendered as a green PASS for a run that never
# happened. Screenshots are kept (existing images are a useful fallback and are
# guarded against re-pull), but the parts dir must be empty at the start.
rm -f build/report/parts/*.json

# True when the emulator is reachable AND not offline ("adb: device offline"
# shows up in `adb devices` as the state "offline").
device_ok() {
  adb devices 2>/dev/null | grep -qE '^emulator-5554[[:space:]]+device$'
}

# Re-establishes the adb connection to a wedged emulator and waits for Android
# to fully boot. Returns 0 on success, 1 if the device never comes back.
recover_device() {
  echo "Recovering emulator adb connection..."
  adb reconnect 2>/dev/null || true
  sleep 3
  if ! device_ok; then
    adb kill-server 2>/dev/null || true
    adb start-server 2>/dev/null || true
  fi
  # wait-for-device can block forever on a dead emulator — bound it and let the
  # poll loop below decide whether the device actually came back.
  timeout 20 adb wait-for-device 2>/dev/null || true
  for _ in $(seq 1 30); do
    if device_ok && [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
      echo "Emulator back online."
      return 0
    fi
    sleep 2
  done
  echo "Emulator did not recover."
  return 1
}

# Kills the emulator process and launches a fresh one. Host-side gfxstream/GL
# state accumulates across app launches and deterministically killed the qemu
# process in three consecutive CI runs — a fresh qemu process resets all of it
# so every file runs as the first app instance. (The worst offenders were the
# Analytics / AI Insights screens; those tests are split into short per-screen
# files so no file renders the heavy charts long enough to hit the crash.) Flags
# mirror the action's emulator-options in flutter_build.yml (plus -no-snapshot
# for a deterministic cold boot). Only useful when a qemu process actually
# exists to restart; on a truly dead emulator this can revive it, so the caller
# can retry the current file after a full restart.
restart_emulator() {
  echo "Restarting emulator (fresh qemu process)..."
  adb -s emulator-5554 emu kill 2>/dev/null || true
  # Wait for the old process to fully exit and release port 5554.
  for _ in $(seq 1 15); do
    if ! adb devices 2>/dev/null | grep -q '^emulator-5554'; then
      break
    fi
    sleep 2
  done
  sleep 2
  # Clear stale AVD/qemu locks left behind by a crashed boot. Without this the
  # new qemu fails to bind port 5554 and every remaining file is skipped — the
  # exact cascade this function exists to prevent.
  rm -f "$HOME/.android/avd/test.avd/multiinstance.lock" \
        "$HOME/.android/avd/test.avd/hardware-qemu.ini.lock" 2>/dev/null || true
  rm -rf "/run/user/$(id -u)/avd/running" 2>/dev/null || true
  # The emulator binary location varies by runner image; honour the SDK root
  # env vars the Android tooling already exports before falling back.
  local emulator_bin="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/usr/local/lib/android/sdk}}/emulator/emulator"
  if [ ! -x "$emulator_bin" ]; then
    emulator_bin="$(command -v emulator || true)"
  fi
  if [ -z "$emulator_bin" ]; then
    echo "Emulator binary not found (looked under \$ANDROID_SDK_ROOT/\$ANDROID_HOME)."
    return 1
  fi
  nohup "$emulator_bin" -port 5554 -avd test \
    -no-snapshot -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim \
    -camera-back none -no-metrics -cores 4 >/tmp/emulator-restart.log 2>&1 &
  for _ in $(seq 1 45); do
    if device_ok && [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
      echo "Emulator restarted and booted."
      return 0
    fi
    sleep 2
  done
  echo "Emulator restart failed."
  return 1
}

# Waits for the emulator to actually reach the internet before a test file runs.
#
# A cold-booted AVD (and `restart_emulator`, which boots a new qemu per file)
# can report `sys.boot_completed=1` while DNS is still unpopulated. The app then
# fails EVERY Firebase call with `UnknownHostException: Unable to resolve host
# "firestore.googleapis.com"`, surfacing as `AuthErrorCodes.NETWORK_REQUEST_FAILED`
# on the login call — which looks like an auth bug but is pure infrastructure.
# Resolving the name (not just pinging an IP) is the check that matters, since
# plain IP reachability succeeds while DNS is still broken.
#
# Returns 0 once resolvable; non-zero after [tries] attempts. Callers warn
# rather than hard-fail, because a genuinely offline device should still run
# the offline-capable files instead of skipping the whole suite.
wait_for_connectivity() { # [tries]
  local tries="${1:-15}"
  for _ in $(seq 1 "$tries"); do
    # `ping -c1 <hostname>` performs both a DNS lookup and a reachability test.
    if adb shell ping -c 1 -W 2 firestore.googleapis.com >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

# Nudges the device's connectivity back on. A fresh AVD sometimes comes up with
# the radio/wifi datapath down; toggling data forces Android to re-evaluate.
ensure_connectivity() {
  if wait_for_connectivity 3; then
    return 0
  fi
  echo "Connectivity not ready — re-enabling data and retrying..."
  adb shell svc wifi enable >/dev/null 2>&1 || true
  adb shell svc data enable >/dev/null 2>&1 || true
  adb shell cmd connectivity airplane-mode disable >/dev/null 2>&1 || true
  if wait_for_connectivity 15; then
    echo "Connectivity restored."
    return 0
  fi
  echo "WARNING: emulator cannot resolve firestore.googleapis.com — Firebase-backed"
  echo "WARNING: tests in this file will likely fail with NETWORK_REQUEST_FAILED."
  return 1
}

# Test files that exercise Pro feature flows must run against the PRO account
# (PRO_TEST_EMAIL/PRO_TEST_PASSWORD); everything else runs against the FREE
# account (TEST_EMAIL/TEST_PASSWORD). The two accounts are never shared — the
# free account is force-reset by the harness, the pro account is configured
# out-of-band in the Firebase console. Add new *pro* files to this list.
#
# Matched as whole words ("$name" surrounded by spaces), NOT substring: a
# substring match made any future file whose name is contained in a Pro entry
# (e.g. features_test inside pro_features_test) silently run as PRO.
PRO_FILES="subscription_flow_test budget_categories_test goals_challenges_test lent_money_split_bill_test subscription_screen_test pro_features_test"

is_pro_file() { # name
  case " $PRO_FILES " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

run_file() {
  local f="$1"
  local name="$2"
  local email="$TEST_EMAIL"
  local password="$TEST_PASSWORD"
  if is_pro_file "$name"; then
    email="$PRO_TEST_EMAIL"
    password="$PRO_TEST_PASSWORD"
    echo "=== $name: PRO account ($PRO_TEST_EMAIL)"
  else
    echo "=== $name: free account"
  fi
  timeout 15m flutter test "$f" -d emulator-5554 --no-uninstall \
    --dart-define=TEST_EMAIL="$email" \
    --dart-define=TEST_PASSWORD="$password" \
    --dart-define=PRO_TEST_EMAIL="$PRO_TEST_EMAIL" \
    --dart-define=PRO_TEST_PASSWORD="$PRO_TEST_PASSWORD" \
    --file-reporter "json:build/report/parts/$name.json"
}

pull_screenshots() {
  local pkg="app.vercel.justaman045.money_control"
  adb shell run-as "$pkg" ls -1 cache/screenshots 2>/dev/null | while read -r g; do
    # Skip only files that already exist AND are non-empty. A failed pull used
    # to leave a 0-byte file that this guard then treated as "already pulled",
    # so the image was never retried and the report embedded a broken PNG.
    if [ -s "build/report/screenshots/$g" ]; then
      continue
    fi
    # Pull to a temp file first: the redirection creates the destination before
    # adb runs, so a wedged device would leave an empty file in place.
    local tmp="build/report/screenshots/.$g.tmp"
    if adb exec-out run-as "$pkg" cat "cache/screenshots/$g" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      mv "$tmp" "build/report/screenshots/$g"
    else
      rm -f "$tmp"
    fi
  done
  echo "--- screenshots pulled so far: $(ls build/report/screenshots 2>/dev/null | wc -l)"
}

FLUTTER_EXIT=0
EMULATOR_DEAD=0
DEAD_SINCE=""
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
FIRST_FILE=1
for f in integration_test/*_test.dart; do
  name=$(basename "$f" .dart)
  if [ "$EMULATOR_DEAD" = "1" ]; then
    echo "SKIP: $name (emulator confirmed dead after $DEAD_SINCE — no recovery attempt)."
    FLUTTER_EXIT=1
    SKIP_COUNT=$((SKIP_COUNT + 1))
    continue
  fi
  # Host GL state accumulates across app launches and killed the emulator at
  # the second file in three consecutive runs — give every file after the first
  # a fresh qemu process so each runs as a first app instance. The action's
  # emulator (booted fresh before the script runs) covers the first file.
  if [ "$FIRST_FILE" = "0" ]; then
    if ! restart_emulator; then
      EMULATOR_DEAD=1
      DEAD_SINCE="$name"
      FLUTTER_EXIT=1
      SKIP_COUNT=$((SKIP_COUNT + 1))
      echo "FAIL: $name (emulator restart failed — treating emulator as dead; remaining files will be skipped fast)."
      continue
    fi
  fi
  FIRST_FILE=0
  # Gate every file on real connectivity: a freshly booted qemu can report
  # boot_completed while DNS is still dead, and the resulting Firebase failures
  # look like auth bugs. Warn (don't skip) — offline-capable files still run.
  ensure_connectivity || true
  echo "=== Running $name ==="
  RC=0
  run_file "$f" "$name" || RC=$?
  if [ "$RC" -eq 0 ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  elif device_ok && { [ "$RC" = "124" ] || [ ! -s "build/report/parts/$name.json" ]; }; then
    # Launch-level failure: either the 15m timeout killed the file (the app
    # froze/ANR'd under the software renderer and never printed a result) or
    # the run ended without a single test event (the app never connected or
    # the tool died before any output). Both can leave the emulator in a bad
    # state, so retry once on a fresh qemu — a genuine bug will just fail the
    # retry too. A hang where the device ALSO went offline falls through to
    # the offline-recovery path below.
    if [ "$RC" = "124" ]; then
      launch_reason="15m timeout, device reachable (hang)"
    else
      launch_reason="no test events, device reachable"
    fi
    echo "FAIL: $name ($launch_reason — restarting emulator and retrying once)."
    if restart_emulator; then
      pull_screenshots
      RC2=0
      run_file "$f" "$name" || RC2=$?
      if [ "$RC2" -eq 0 ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "PASS on launch-retry: $name"
      else
        FLUTTER_EXIT=1
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "FAIL on launch-retry: $name"
      fi
    else
      EMULATOR_DEAD=1
      DEAD_SINCE="$name"
      FLUTTER_EXIT=1
      echo "FAIL: $name (emulator restart failed after launch-level failure — treating emulator as dead; remaining files will be skipped fast)."
    fi
  elif device_ok; then
    # Device reachable and the run produced real test events → this is a
    # genuine test failure, not emulator loss.
    FLUTTER_EXIT=1
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: $name (test failure, device reachable — no retry)."
  else
      echo "FAIL: $name (device offline — attempting one recovery + retry)."
      if recover_device; then
        pull_screenshots
        if run_file "$f" "$name"; then
          PASS_COUNT=$((PASS_COUNT + 1))
          echo "PASS on retry: $name"
        else
          FLUTTER_EXIT=1
          FAIL_COUNT=$((FAIL_COUNT + 1))
          echo "FAIL on retry: $name"
        fi
      elif restart_emulator; then
        pull_screenshots
        if run_file "$f" "$name"; then
          PASS_COUNT=$((PASS_COUNT + 1))
          echo "PASS on restart-retry: $name"
        else
          FLUTTER_EXIT=1
          FAIL_COUNT=$((FAIL_COUNT + 1))
          echo "FAIL on restart-retry: $name"
        fi
      else
        EMULATOR_DEAD=1
        DEAD_SINCE="$name"
        FLUTTER_EXIT=1
        echo "FAIL: $name (emulator unreachable after recovery and restart — treating emulator as dead; remaining files will be skipped fast)."
      fi
  fi
  pull_screenshots
done

echo "=== Suite finished ==="
echo "Integration passed: $PASS_COUNT -- failed: $FAIL_COUNT -- skipped: $SKIP_COUNT"
exit $FLUTTER_EXIT
