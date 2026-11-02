#!/bin/zsh
# Renders media/app-rules.png from the real App Rules view (see render-app-rules.swift).
set -euo pipefail
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# The renderer has its own top-level code, so leave out the app's main.swift
cp media/render-app-rules.swift "$TMP/main.swift"
swiftc -O ${(f)"$(ls Sources/*.swift | grep -v '/main.swift$')"} "$TMP/main.swift" -o "$TMP/render"
"$TMP/render" media/app-rules.png
