#!/bin/bash
# Builds Wakey.app into ./build.noindex (.noindex keeps Spotlight/Launchpad from listing a second copy). Copy it to /Applications to keep it.
set -euo pipefail
cd "$(dirname "$0")"
APP="build.noindex/Wakey.app"
rm -rf build.noindex && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/"
swiftc -O -target "$(uname -m)-apple-macos13" main.swift Icons.swift -o "$APP/Contents/MacOS/Wakey"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Wakey</string>
  <key>CFBundleIdentifier</key><string>com.vinnie.wakey</string>
  <key>CFBundleExecutable</key><string>Wakey</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
