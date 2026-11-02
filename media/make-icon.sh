#!/bin/zsh
# Renders media/AppIcon.icns (used by build.sh) and media/icon.png from render-icon.swift.
set -euo pipefail
cd "$(dirname "$0")"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

swiftc -O render-icon.swift -o "$TMP/render" -framework AppKit
"$TMP/render" icon.png

ICONSET="$TMP/AppIcon.iconset"
mkdir "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o AppIcon.icns
ls -lh AppIcon.icns icon.png
