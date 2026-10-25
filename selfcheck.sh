#!/bin/bash
# Wakey self-check: the one command to run before every commit (on the Mac).
#   ./selfcheck.sh          (from any folder)
# 1. tests/run.sh: builds and runs the logic tests (Logic.swift + tests/LogicTests.swift; no AppKit, no app launch).
# 2. ./build.sh: compiles the app into build.noindex/Wakey.app (compile only, never launches it; a failed compile
#    leaves the existing build.noindex/ and /Applications/Wakey.app untouched).
# Both need swiftc, so this is a Mac check. Without swiftc it prints "needs a Mac" and exits 2, so nobody mistakes
# it for a pass. Prints "ok - ..." / "FAIL - ..." lines and a final PASS or FAIL (n). Exit 0 = pass, 1 = fail.
set -uo pipefail
SRC="$0"   # work from the script's real folder, even when run through a symlink (as build.sh does)
while [ -L "$SRC" ]; do
  LINK="$(readlink "$SRC")"
  case "$LINK" in /*) SRC="$LINK" ;; *) SRC="$(dirname "$SRC")/$LINK" ;; esac
done
cd "$(dirname "$SRC")" || exit 1

if ! command -v swiftc >/dev/null 2>&1; then
  echo "skip - logic tests and app build: no swiftc on this machine"
  echo "NOT RUN - needs a Mac (Xcode or the Command Line Tools); exit 2, not a pass"
  exit 2
fi

fails=0
ok()   { echo "ok - $*"; }
fail() { echo "FAIL - $*"; fails=$((fails + 1)); }

# ---- 1. logic tests ----
out=$(tests/run.sh 2>&1); rc=$?
res=$(printf '%s\n' "$out" | grep -E '^[0-9]+ passed, [0-9]+ failed$' | tail -1)
if [ $rc -eq 0 ] && [ -n "$res" ] && [ "${res##*, }" = "0 failed" ]; then ok "logic tests (tests/run.sh): $res"
else
  printf '%s\n' "$out" | grep -E '^FAIL: |error:' | head -15 | sed 's/^/    /'
  [ -z "$res" ] && printf '%s\n' "$out" | tail -8 | sed 's/^/    /'
  fail "logic tests (tests/run.sh): ${res:-did not compile or run} (exit $rc)"
fi

# ---- 2. app build (macOS only: AppKit, a macOS target and codesign) ----
if [ "$(uname -s)" != "Darwin" ]; then
  echo "skip - app build (build.sh): needs a Mac"
  if [ "$fails" -gt 0 ]; then echo "FAIL ($fails)"; exit 1; fi
  echo "NOT COMPLETE - logic tests passed, but the app build needs a Mac (exit 2, not a pass)"; exit 2
fi
out=$(./build.sh 2>&1); rc=$?
if [ $rc -eq 0 ] && printf '%s\n' "$out" | grep -q '^Built build.noindex/Wakey.app'; then ok "app build (build.sh): Built build.noindex/Wakey.app (not launched)"
else
  errs=$(printf '%s\n' "$out" | grep -E 'error:' | head -15)
  if [ -n "$errs" ]; then printf '%s\n' "$errs"; else printf '%s\n' "$out" | tail -5; fi | sed 's/^/    /'
  fail "app build (build.sh) failed (exit $rc)"
fi

if [ "$fails" -gt 0 ]; then echo "FAIL ($fails)"; exit 1; fi
echo "PASS"; exit 0
