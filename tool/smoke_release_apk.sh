#!/usr/bin/env bash
# Installs the *release* APK on a booted emulator and proves it actually
# launches and stays alive.
#
# Why this exists: R8/minify is ON for release, and unit/integration tests run
# DEBUG builds, so a shrunk reflective constructor only shows up when a release
# APK launches. That exact class of bug (Room's `WorkDatabase_Impl.<init>` being
# stripped under R8 full mode) shipped in every release until it was caught by
# hand. This script is the automated version of that check.
#
# It deliberately asserts little about the UI: the app boots to the login
# screen, whose copy is localized and therefore a moving target. The signals
# that matter are process liveness (a startup crash leaves no pid), a rendered
# window, and the absence of `FATAL EXCEPTION` / `ANR in <pkg>` in logcat.
#
# Usage: bash tool/smoke_release_apk.sh [path-to-apk]
# Requirements: `adb` on PATH and exactly one booted device/emulator.
set -uo pipefail

PKG="app.vercel.justaman045.money_control"
ACTIVITY=".MainActivity"
APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"
BOOT_TRIES="${SMOKE_BOOT_TRIES:-120}"
LAUNCH_TRIES="${SMOKE_LAUNCH_TRIES:-60}"
SETTLE_SECONDS="${SMOKE_SETTLE_SECONDS:-10}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -f "$APK" ] || fail "release APK not found: $APK"
echo "Release APK: $APK ($(du -h "$APK" | cut -f1))"

adb wait-for-device || fail "no adb device"

booted() {
  [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]
}

for _ in $(seq 1 "$BOOT_TRIES"); do
  booted && break
  sleep 2
done
booted || fail "emulator never reported sys.boot_completed=1"

# A stale install (e.g. a debug build) must not mask a release-only bug: the
# smoke check has to exercise exactly the artifact that will be published.
adb uninstall "$PKG" >/dev/null 2>&1 || true

echo "Installing..."
adb install -r "$APK" || fail "release APK failed to install"

# `dumpsys package` proves the install registered, even if the launch is flaky.
adb shell pm list packages 2>/dev/null | tr -d '\r' | grep -qx "package:$PKG" \
  || fail "package $PKG is not installed after 'adb install'"

adb logcat -c 2>/dev/null || true

echo "Launching $PKG/$ACTIVITY..."
START_OUT="$(adb shell am start -W -n "$PKG/$ACTIVITY" 2>&1)"
echo "$START_OUT"
case "$START_OUT" in
  *"Error:"*|*"Exception"*) fail "am start reported an error: $START_OUT" ;;
esac

PID=""
for _ in $(seq 1 "$LAUNCH_TRIES"); do
  PID="$(adb shell pidof "$PKG" 2>/dev/null | tr -d '\r')"
  [ -n "$PID" ] && break
  sleep 1
done
[ -n "$PID" ] || fail "the app process never appeared (startup crash before the first frame)"
echo "App running with pid $PID"

# Plugin/Firebase initialisation happens just after the first frame; a crash
# there is the R8 failure mode this gate exists for.
sleep "$SETTLE_SECONDS"
PID_AFTER="$(adb shell pidof "$PKG" 2>/dev/null | tr -d '\r')"
[ -n "$PID_AFTER" ] || fail "the app process died within ${SETTLE_SECONDS}s of launch"

LOGCAT="$(adb logcat -d -v brief 2>/dev/null || true)"

# Only a crash that belongs to this app counts. The emulator's own Play
# Services processes do throw `FATAL EXCEPTION` on CI images, and failing the
# release for that would be a false alarm. The `Process:` line that follows a
# Java crash header carries the package name.
if printf '%s\n' "$LOGCAT" | grep -A5 'FATAL EXCEPTION' | grep -q "$PKG"; then
  echo "--- logcat ---"
  printf '%s\n' "$LOGCAT" | grep -A10 'FATAL EXCEPTION' | head -40
  fail "a fatal exception was logged during startup"
fi

if printf '%s\n' "$LOGCAT" | grep -qE "ANR in $PKG"; then
  echo "--- logcat ---"
  printf '%s\n' "$LOGCAT" | grep -E "ANR in $PKG" | head -20
  fail "the app ANR'd during startup"
fi

# A rendered window means the Flutter engine came up rather than dying on a
# missing plugin. The dump is intentionally not asserted for copy.
if adb shell uiautomator dump /sdcard/smoke-window.xml >/dev/null 2>&1; then
  WINDOW="$(adb shell cat /sdcard/smoke-window.xml 2>/dev/null | tr -d '\r')"
  [ -n "$WINDOW" ] || fail "uiautomator reported an empty window hierarchy"
  echo "Window rendered (uiautomator dump: $(printf '%s' "$WINDOW" | wc -c) bytes)"
  adb shell rm -f /sdcard/smoke-window.xml >/dev/null 2>&1 || true
else
  echo "WARN: uiautomator dump unavailable; relying on process liveness + logcat"
fi

echo "PASS: $PKG launched and stayed alive (pid $PID_AFTER)"
