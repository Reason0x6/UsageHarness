#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"

swift build -c release --product UsageHarness
BIN_DIR=$(swift build -c release --show-bin-path)
BUNDLE="$PROJECT_ROOT/.build/UsageHarness.app"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN_DIR/UsageHarness" "$BUNDLE/Contents/MacOS/UsageHarness"
cp "$PROJECT_ROOT/Resources/Info.plist" "$BUNDLE/Contents/Info.plist"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$BUNDLE"
fi

echo "$BUNDLE"
