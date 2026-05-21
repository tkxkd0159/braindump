#!/usr/bin/env bash
# Build todoosx and run it as a proper .app bundle so macOS gives it a
# Dock icon and a visible window. `swift run todoosx` alone produces a
# bare Mach-O that AppKit won't activate.

set -euo pipefail

CONFIG="${CONFIG:-debug}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$REPO_ROOT/.build/$CONFIG"
APP_DIR="$REPO_ROOT/.build/todoosx.app"

cd "$REPO_ROOT"

if [ "$CONFIG" = "release" ]; then
    swift build -c release --target todoosx
else
    swift build --target todoosx
fi

# Assemble .app bundle
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/todoosx" "$APP_DIR/Contents/MacOS/todoosx"
cp "$REPO_ROOT/scripts/Info.plist" "$APP_DIR/Contents/Info.plist"

# Sign ad-hoc so the binary launches without Gatekeeper prompts
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "Launching $APP_DIR"
open "$APP_DIR"
