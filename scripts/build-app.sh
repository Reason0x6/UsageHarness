#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"

if ! command -v xcrun >/dev/null 2>&1; then
    echo "Usage Harness must be built on macOS with the Xcode command-line tools installed." >&2
    exit 1
fi

SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
ARCH=$(uname -m)
case "$ARCH" in
    arm64|x86_64) ;;
    *)
        echo "Unsupported Mac architecture: $ARCH" >&2
        exit 1
        ;;
esac

BUILD_DIR="$PROJECT_ROOT/.build/native-release"
BINARY="$BUILD_DIR/UsageHarness"
BUNDLE="$PROJECT_ROOT/.build/UsageHarness.app"
SOURCE_FILES=("$PROJECT_ROOT"/Sources/UsageHarness/*.swift)

mkdir -p "$BUILD_DIR"

echo "Building Usage Harness for ${ARCH}..."
xcrun --sdk macosx swiftc \
    -sdk "$SDK_PATH" \
    -target "${ARCH}-apple-macosx13.0" \
    -parse-as-library \
    -O \
    -whole-module-optimization \
    -module-name UsageHarness \
    -framework AppKit \
    -framework Combine \
    -framework Foundation \
    -framework ServiceManagement \
    -framework SwiftUI \
    "${SOURCE_FILES[@]}" \
    -o "$BINARY"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BINARY" "$BUNDLE/Contents/MacOS/UsageHarness"
cp "$PROJECT_ROOT/Resources/Info.plist" "$BUNDLE/Contents/Info.plist"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$BUNDLE"
fi

echo "Built $BUNDLE"
