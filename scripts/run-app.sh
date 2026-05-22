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

# Copy SPM resource bundles into Resources/ so Bundle.module resolves at runtime.
# Bundle.module searches Bundle.main.resourceURL first, which is Contents/Resources/.
for bundle in "$BIN_DIR"/*.bundle; do
    [ -e "$bundle" ] || continue
    dest="$APP_DIR/Contents/Resources/$(basename "$bundle")"
    cp -R "$bundle" "$dest"
    # SPM resource bundles ship as bare folders; codesign refuses them unless
    # they look like a real bundle, so stamp a minimal Info.plist.
    if [ ! -f "$dest/Info.plist" ]; then
        cat > "$dest/Info.plist" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.todoosx.app.$(basename "$dest" .bundle)</string>
    <key>CFBundleName</key>
    <string>$(basename "$dest" .bundle)</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
PLIST_EOF
    fi
done

# Sign ad-hoc so the binary launches without Gatekeeper prompts.
codesign --force --deep --sign - "$APP_DIR" >/dev/null

# Kill any prior instance so `open` actually launches the freshly-built binary
# instead of just foregrounding the stale one already on screen.
killall todoosx 2>/dev/null || true

echo "Launching $APP_DIR"
open "$APP_DIR"
