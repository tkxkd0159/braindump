#!/usr/bin/env bash
# Build a Release .app and wrap it in an unsigned .dmg.
# No Apple Developer account needed; the result will trigger Gatekeeper
# warnings on other Macs (right-click → Open, or
# `xattr -dr com.apple.quarantine /Applications/BrainDump.app`).
#
# Requires `create-dmg` (brew install create-dmg).

set -euo pipefail

CONFIG="${CONFIG:-Release}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$REPO_ROOT/.build/xcode"
STAGING="$REPO_ROOT/build/dmg-staging"
DMG="$REPO_ROOT/build/BrainDump.dmg"
BACKGROUND="$REPO_ROOT/assets/dmg-bg.png"

cd "$REPO_ROOT"

if ! command -v create-dmg >/dev/null; then
    echo "error: create-dmg not found. Install with: brew install create-dmg" >&2
    exit 1
fi

# Build settings injected at the command line (no project.pbxproj edits):
#  - version comes from CI; falls back to the project's values when unset locally
#  - ENABLE_HARDENED_RUNTIME=NO: pointless without notarization and worsens the
#    Gatekeeper experience on unsigned, quarantined downloads ("is damaged")
#  - ONLY_ACTIVE_ARCH=NO: universal binary so the DMG runs on Apple Silicon + Intel
build_overrides=( ENABLE_HARDENED_RUNTIME=NO ONLY_ACTIVE_ARCH=NO )
[[ -n "${MARKETING_VERSION:-}" ]] && build_overrides+=( "MARKETING_VERSION=$MARKETING_VERSION" )
[[ -n "${CURRENT_PROJECT_VERSION:-}" ]] && build_overrides+=( "CURRENT_PROJECT_VERSION=$CURRENT_PROJECT_VERSION" )

xcodebuild \
    -project BrainDump.xcodeproj \
    -scheme BrainDump \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED" \
    "${build_overrides[@]}" \
    build >/dev/null

APP="$DERIVED/Build/Products/$CONFIG/BrainDump.app"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"

bg_args=()
if [[ -f "$BACKGROUND" ]]; then
    # Finder honors 144 dpi as the retina hint, scaling the image to half its
    # pixel dimensions in logical coords. Source image stays untouched.
    BG_PREPARED="$REPO_ROOT/build/dmg-bg-prepared.png"
    sips -s dpiHeight 144 -s dpiWidth 144 "$BACKGROUND" --out "$BG_PREPARED" >/dev/null
    bg_args=(--background "$BG_PREPARED")
else
    echo "warning: $BACKGROUND not found — building plain DMG without custom background" >&2
fi

create-dmg \
    --volname "Brain Dump" \
    --window-size 748 526 \
    --icon-size 128 \
    --icon "BrainDump.app" 208 265 \
    --app-drop-link 540 262 \
    --hide-extension "BrainDump.app" \
    --no-internet-enable \
    ${bg_args[@]+"${bg_args[@]}"} \
    "$DMG" \
    "$STAGING" >/dev/null

rm -rf "$STAGING"

echo "Created $DMG"
