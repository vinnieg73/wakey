#!/bin/bash
# Builds and runs the logic tests (Logic.swift only, no AppKit, no app launch). Works on the Mac and on Linux.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc -parse-as-library Logic.swift tests/LogicTests.swift -o "$TMP/logic-tests"
"$TMP/logic-tests"
