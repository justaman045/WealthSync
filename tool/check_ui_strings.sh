#!/usr/bin/env bash
# UI revamp audit — run after every revamp wave.
#
# Tracks mechanical design-debt counts (raw colors, glass, gradients, backdrop
# filters) and copy-migration progress. With --strict, fails when any count
# exceeds the cap recorded in tool/revamp_baseline.env. Lower the caps after
# each wave; a regression above the cap means new debt was reintroduced.
#
# Usage:
#   tool/check_ui_strings.sh            # report only (always exits 0)
#   tool/check_ui_strings.sh --strict   # exit 1 if caps exceeded
#
# NOTE: every count below must survive grep finding ZERO matches. Under
# `set -euo pipefail` a grep with no match exits 1 and would abort the whole
# script before it prints anything — which is exactly the goal state (all debt
# removed), so each counter ends with `|| true`. Do not remove those.
set -euo pipefail
cd "$(dirname "$0")/.."

STRICT=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    -h|--help)
      sed -n '2,13p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [--strict]" >&2
      exit 2
      ;;
  esac
done

BASELINE="tool/revamp_baseline.env"
if [[ -f "$BASELINE" ]]; then
  # shellcheck disable=SC1090
  source "$BASELINE"
fi
: "${CAP_RAW_COLORS:=999999}"
: "${CAP_GLASS_FILES:=999999}"
: "${CAP_GRADIENT_FILES:=999999}"
: "${CAP_BACKDROP_SITES:=999999}"
: "${CAP_INTEG_LITERALS:=999999}"
: "${CAP_HARDCODED_SCREENS:=999999}"
: "${CAP_FONT_SIZES:=999999}"
: "${CAP_FONT_SIZE_VALUES:=999999}"
: "${CAP_RADIUS_VALUES:=999999}"

RAW_COLORS=$(grep -rEc 'Color\(0x' lib/Screens lib/Components lib/Config --include='*.dart' 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}' || true)
GLASS_FILES=$(grep -rl 'GlassContainer' lib --include='*.dart' 2>/dev/null | wc -l || true)
GRADIENT_FILES=$(grep -rl 'LinearGradient\|RadialGradient' lib/Screens lib/Components --include='*.dart' 2>/dev/null | wc -l || true)
BACKDROP=$(grep -rc 'BackdropFilter' lib --include='*.dart' 2>/dev/null | grep -v ':0$' | awk -F: '{s+=$NF} END {print s+0}' || true)
INTEG_LITERALS=$(grep -rhoE "find\.text\('[^']+'\)" integration_test 2>/dev/null | sort -u | wc -l || true)

# Unlocalized copy: literal string arguments to Text() in Screens/Components that
# are NOT sourced from AppStrings and are not obviously data (single characters,
# currency/amount formatting, pure punctuation). This is the localization debt
# counter — it must only ever go DOWN.
#
# Deliberately excludes:
#   * Text(AppStrings.x) / Text(AppLocalizations...) — already localizable
#   * literals interpolated from variables ($) — usually data, not copy
#   * anything shorter than 3 chars (units, glyphs like '₹', '•')
#
# The literal is normalized (quote char and `Text(` stripped) before dedup so
# the same word is not counted twice just because one site uses ' and another ".
# Typography / geometry drift. `fontSize:` at a call site bypasses the TextTheme,
# so the app accumulated 22 distinct sizes (8 -> 60) and 19 distinct corner radii
# (2 -> 50). A screen that uses `AppType.*` / `AppRadius.*` adds nothing to these
# counts; a new ad-hoc literal does. Both must only ever go DOWN.
FONT_SIZES=$(grep -rho 'fontSize:' lib/Screens lib/Components lib/Config --include='*.dart' 2>/dev/null | wc -l || true)
FONT_SIZE_VALUES=$(grep -rhoE 'fontSize:[[:space:]]*[0-9]+' lib/Screens lib/Components lib/Config --include='*.dart' 2>/dev/null \
  | grep -oE '[0-9]+$' | sort -u | wc -l || true)
RADIUS_VALUES=$(grep -rhoE 'BorderRadius\.circular\([0-9]+' lib/Screens lib/Components lib/Config --include='*.dart' 2>/dev/null \
  | grep -oE '[0-9]+$' | sort -u | wc -l || true)

HARDCODED_SCREENS=$(grep -rhoE "Text\(\s*'[^'\\$]{3,}'|Text\(\s*\"[^\"\\$]{3,}\"" \
  lib/Screens lib/Components --include='*.dart' 2>/dev/null \
  | grep -viE "AppStrings\.|AppLocalizations" \
  | sed -E "s/^Text\(\s*['\"]//; s/['\"]$//" \
  | sort -u | wc -l || true)

echo "── UI Revamp Audit ──────────────────────────────"
printf 'Raw Color(0x…) literals : %5d   (cap %s)\n' "${RAW_COLORS:-0}"   "$CAP_RAW_COLORS"
printf 'GlassContainer files    : %5d   (cap %s)\n' "${GLASS_FILES:-0}"  "$CAP_GLASS_FILES"
printf 'Gradient files          : %5d   (cap %s)\n' "${GRADIENT_FILES:-0}" "$CAP_GRADIENT_FILES"
printf 'BackdropFilter sites    : %5d   (cap %s)\n' "${BACKDROP:-0}"     "$CAP_BACKDROP_SITES"
printf 'Integration text literals (unique, should trend down): %d   (cap %s)\n' "${INTEG_LITERALS:-0}" "$CAP_INTEG_LITERALS"
printf 'Unlocalized UI literals (unique, should trend down)  : %d   (cap %s)\n' "${HARDCODED_SCREENS:-0}" "$CAP_HARDCODED_SCREENS"
printf 'Ad-hoc fontSize: sites  : %5d   (cap %s)\n' "${FONT_SIZES:-0}" "$CAP_FONT_SIZES"
printf 'Distinct fontSize values: %5d   (cap %s)\n' "${FONT_SIZE_VALUES:-0}" "$CAP_FONT_SIZE_VALUES"
printf 'Distinct corner radii   : %5d   (cap %s)\n' "${RADIUS_VALUES:-0}" "$CAP_RADIUS_VALUES"

rc=0
check() { # name value cap
  if [[ "$2" -gt "$3" ]]; then
    echo "FAIL: $1 ($2) exceeds cap ($3)"
    rc=1
  fi
}
check "raw color literals" "$RAW_COLORS"     "$CAP_RAW_COLORS"
check "GlassContainer usage" "$GLASS_FILES"  "$CAP_GLASS_FILES"
check "gradient files" "$GRADIENT_FILES"     "$CAP_GRADIENT_FILES"
check "BackdropFilter sites" "$BACKDROP"     "$CAP_BACKDROP_SITES"
check "integration text literals" "$INTEG_LITERALS" "$CAP_INTEG_LITERALS"
check "unlocalized UI literals" "$HARDCODED_SCREENS" "$CAP_HARDCODED_SCREENS"
check "ad-hoc fontSize sites" "$FONT_SIZES" "$CAP_FONT_SIZES"
check "distinct fontSize values" "$FONT_SIZE_VALUES" "$CAP_FONT_SIZE_VALUES"
check "distinct corner radii" "$RADIUS_VALUES" "$CAP_RADIUS_VALUES"

if [[ $rc -eq 0 ]]; then
  echo "OK: all caps respected."
elif [[ $STRICT -eq 0 ]]; then
  echo "REPORT ONLY (missing --strict): the failures above do not fail this run."
  rc=0
fi
exit $rc
