#!/bin/zsh
# Builds FnLockBar.app and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"
APP=build/FnLockBar.app
rm -rf build && mkdir -p "$APP/Contents/MacOS"
swiftc -O main.swift -o "$APP/Contents/MacOS/FnLockBar" -framework AppKit -framework IOKit -framework ServiceManagement
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>de.tobiaswust.FnLockBar</string>
  <key>CFBundleName</key><string>FnLockBar</string>
  <key>CFBundleExecutable</key><string>FnLockBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
mkdir -p ~/Applications
rm -rf ~/Applications/FnLockBar.app
cp -R "$APP" ~/Applications/
echo "Installed ~/Applications/FnLockBar.app"
