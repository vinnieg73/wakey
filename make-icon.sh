#!/bin/bash
# Regenerates AppIcon.icns (and icon-preview-app.png) from Icons.swift.
set -euo pipefail
cd "$(dirname "$0")"
TMP=$(mktemp -d)
trap 'rm -rf AppIcon.iconset "$TMP"' EXIT   # clean up even if a step fails
cp make-icon.swift "$TMP/main.swift"
swiftc Icons.swift "$TMP/main.swift" -o "$TMP/make-icon"
"$TMP/make-icon"
iconutil -c icns AppIcon.iconset -o AppIcon.icns
echo "Wrote AppIcon.icns"
