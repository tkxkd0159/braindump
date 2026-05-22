#!/usr/bin/env bash
# Headless build + launch of the Brain Dump app.
# In Xcode, just Cmd+R — this script exists for CLI/CI use.

set -euo pipefail

CONFIG="${CONFIG:-Debug}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$REPO_ROOT/.build/xcode"

cd "$REPO_ROOT"

xcodebuild \
    -project BrainDump.xcodeproj \
    -scheme BrainDump \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED" \
    build >/dev/null

APP="$DERIVED/Build/Products/$CONFIG/BrainDump.app"

# Kill any prior instance so `open` foregrounds the freshly-built binary.
killall BrainDump 2>/dev/null || true

echo "Launching $APP"
open "$APP"
