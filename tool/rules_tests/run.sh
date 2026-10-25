#!/usr/bin/env bash
# Boots the Firestore + Storage emulators with the repo's rules and runs the
# rules tests in tool/rules_tests/run.js against them.
#
# This is CI's only real rules compiler: deploying with `--dry-run` needs live
# credentials, which CI does not have, but loading rules into the emulator
# compiles them and then exercises the paths that must stay locked down.
#
# Usage: bash tool/rules_tests/run.sh
# Requirements: Node 20+ and a JDK (the Firestore emulator is a JVM process).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if [ ! -d tool/rules_tests/node_modules ]; then
  echo "Installing rules-test dependencies (npm ci)..."
  (cd tool/rules_tests && npm ci --no-audit --no-fund)
fi

exec tool/rules_tests/node_modules/.bin/firebase emulators:exec \
  --only firestore,storage \
  --project demo-wealthsync \
  --config firebase.json \
  "node tool/rules_tests/run.js"
