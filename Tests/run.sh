#!/bin/zsh
# Compiles the pure-logic sources together with LogicTests.swift and runs them.
set -euo pipefail
cd "$(dirname "$0")/.."
BIN=$(mktemp -d)/tests
trap 'rm -rf "$(dirname "$BIN")"' EXIT
# LogicTests.swift must be named main.swift for top-level code alongside other files
cp Tests/LogicTests.swift "$(dirname "$BIN")/main.swift"
swiftc Sources/AppRules.swift Sources/UpdateChecker.swift "$(dirname "$BIN")/main.swift" -o "$BIN"
"$BIN"
