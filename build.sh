#!/bin/zsh
# Builds a universal (arm64 + x86_64) FnLockBar.app and installs it to ~/Applications.
#   ./build.sh               build + install
#   ./build.sh --no-install  build only (used by CI); also writes build/FnLockBar.zip
# VERSION=1.2.3 ./build.sh   sets the version shown in the About panel (default: latest git tag)
# SIGN_IDENTITY="Developer ID Application" ./build.sh   signs for notarization (default: ad-hoc "-")
set -euo pipefail
cd "$(dirname "$0")"
# Defaults to the latest git tag, so local builds don't report themselves as outdated
VERSION=${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}
VERSION=${VERSION:-1.0}
APP=build/FnLockBar.app
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp media/AppIcon.icns "$APP/Contents/Resources/" # regenerate with media/make-icon.sh
for arch in arm64 x86_64; do
  swiftc -O Sources/*.swift -target "$arch-apple-macos13.0" -o "build/FnLockBar-$arch" \
    -framework AppKit -framework IOKit -framework ServiceManagement
done
lipo -create build/FnLockBar-arm64 build/FnLockBar-x86_64 -output "$APP/Contents/MacOS/FnLockBar"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>de.tobiaswust.FnLockBar</string>
  <key>CFBundleName</key><string>FnLockBar</string>
  <key>CFBundleExecutable</key><string>FnLockBar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
# Always hardened runtime (required for notarization), so local builds behave like releases.
# A secure timestamp is only possible (and only needed) with a real Developer ID.
SIGN_IDENTITY=${SIGN_IDENTITY:--}
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --options runtime --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi

if [[ "${1:-}" == "--no-install" ]]; then
  ditto -c -k --keepParent "$APP" build/FnLockBar.zip
  echo "Built $APP and build/FnLockBar.zip"
  exit 0
fi

mkdir -p ~/Applications
rm -rf ~/Applications/FnLockBar.app
cp -R "$APP" ~/Applications/
echo "Installed ~/Applications/FnLockBar.app"
