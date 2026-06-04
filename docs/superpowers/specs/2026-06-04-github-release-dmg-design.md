# Ship the macOS app as a DMG via GitHub Releases (GitHub Actions)

## Goal

On pushing a version tag (`vX.Y.Z`), a GitHub Actions workflow builds a Release
`BrainDump.app`, wraps it in a `.dmg`, and publishes a GitHub Release with the
DMG attached and first-launch instructions in the notes. No paid Apple Developer
account; the DMG is unsigned (ad-hoc), optimized for the cleanest possible
Gatekeeper override experience.

## Locked decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Signing | Unsigned / ad-hoc, **hardened runtime off** for the DMG build | Free. No Developer ID exists without the $99/yr program. Dropping hardened runtime makes the milder "Open Anyway" path (vs. "is damaged") more likely on quarantined downloads. |
| Trigger | `push` on tags `v*`; tag drives the version | One-command release; tag is the single source of version truth. |
| Test gate | `swift test` must pass before the DMG builds | Don't ship broken `BrainDumpKit` logic. |
| Build construction | Reuse + parameterize `scripts/build-dmg.sh` | One source of truth — local `./scripts/build-dmg.sh` and CI produce identical DMGs. |
| Release tool | `gh` CLI + built-in `GITHUB_TOKEN` | No third-party action; smaller supply-chain surface. |
| Release notes | Static install/first-launch block **prepended to** GitHub's auto-generated changelog | Users need the Gatekeeper steps up top; the commit/PR changelog comes free from the API. |

## Repo prep (required before the workflow can work)

### 1. Commit a shared scheme

`xcodebuild -scheme BrainDump` fails on a clean CI checkout because the scheme
lives in gitignored `xcuserdata/`. Add and commit:

```
BrainDump.xcodeproj/xcshareddata/xcschemes/BrainDump.xcscheme
```

The scheme references the existing `BrainDump` target (blueprint identifier
pulled from `project.pbxproj`), `BuildableName = BrainDump.app`, with a Release
archive/build action. Verify locally: `xcodebuild -list` must show `BrainDump`
under **Schemes** with no `xcuserdata` present.

### 2. Make `Info.plist` version-substitutable

The version is currently a literal in `BrainDump/Info.plist`, so command-line
`xcodebuild MARKETING_VERSION=...` would be silently ignored. Change two keys to
match the existing `$(PRODUCT_NAME)` substitution pattern in the same file:

```diff
   <key>CFBundleShortVersionString</key>
-  <string>0.1.0</string>
+  <string>$(MARKETING_VERSION)</string>
   <key>CFBundleVersion</key>
-  <string>1</string>
+  <string>$(CURRENT_PROJECT_VERSION)</string>
```

`MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1` already exist in
`project.pbxproj`, so local Xcode builds keep showing `0.1.0` / `1` by default;
CI overrides them per release.

### 3. Parameterize `scripts/build-dmg.sh`

The script is the unsigned-distributable path, so it always builds without
hardened runtime and as a universal binary, and accepts an optional injected
version. Defaults keep current local behavior (version falls back to project
values).

```diff
 CONFIG="${CONFIG:-Release}"
 ...
+# Optional version injection (CI passes these; local runs omit them).
+build_overrides=( ENABLE_HARDENED_RUNTIME=NO ONLY_ACTIVE_ARCH=NO )
+[[ -n "${MARKETING_VERSION:-}" ]] && build_overrides+=( "MARKETING_VERSION=$MARKETING_VERSION" )
+[[ -n "${CURRENT_PROJECT_VERSION:-}" ]] && build_overrides+=( "CURRENT_PROJECT_VERSION=$CURRENT_PROJECT_VERSION" )
+
 xcodebuild \
     -project BrainDump.xcodeproj \
     -scheme BrainDump \
     -configuration "$CONFIG" \
     -derivedDataPath "$DERIVED" \
+    "${build_overrides[@]}" \
     build >/dev/null
```

Rationale for `ENABLE_HARDENED_RUNTIME=NO` here: hardened runtime only buys
something when notarized; on an unsigned, quarantined download it raises the
chance of the dead-end "is damaged" dialog. `ONLY_ACTIVE_ARCH=NO` guarantees a
universal (arm64 + x86_64) binary even though the runner is Apple Silicon, so
Intel Macs are covered.

## Workflow: `.github/workflows/release.yml`

```yaml
name: Release DMG

on:
  push:
    tags: ["v*"]

permissions:
  contents: write          # required to create the Release

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false  # never abort a release mid-flight

jobs:
  release:
    runs-on: macos-14        # Apple Silicon; Release build is universal
    steps:
      - uses: actions/checkout@v4

      - name: Derive version from tag
        id: ver
        run: |
          set -euo pipefail
          VERSION="${GITHUB_REF_NAME#v}"
          if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
            echo "::error::Tag '$GITHUB_REF_NAME' is not vMAJOR.MINOR.PATCH[-pre]"; exit 1
          fi
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          if [[ "$VERSION" == *-* ]]; then echo "prerelease=true"  >> "$GITHUB_OUTPUT";
          else                              echo "prerelease=false" >> "$GITHUB_OUTPUT"; fi

      - name: Run tests (gate)
        run: swift test

      - name: Install create-dmg
        run: brew install create-dmg

      - name: Build DMG
        env:
          MARKETING_VERSION: ${{ steps.ver.outputs.version }}
          CURRENT_PROJECT_VERSION: ${{ github.run_number }}
        run: ./scripts/build-dmg.sh

      - name: Verify stamped version
        run: |
          set -euo pipefail
          APP=".build/xcode/Build/Products/Release/BrainDump.app"
          GOT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
          [[ "$GOT" == "${{ steps.ver.outputs.version }}" ]] || { echo "::error::version mismatch: $GOT"; exit 1; }

      - name: Publish release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          set -euo pipefail
          # Auto-generated changelog (commits/PRs since the previous tag).
          GENERATED=$(gh api "repos/$GITHUB_REPOSITORY/releases/generate-notes" \
            -f tag_name="$GITHUB_REF_NAME" --jq .body)
          # Prepend the static install/first-launch instructions above it.
          { cat .github/release-notes.md; printf '\n\n'; printf '%s\n' "$GENERATED"; } \
            > "$RUNNER_TEMP/notes.md"
          flags=(--title "$GITHUB_REF_NAME" --notes-file "$RUNNER_TEMP/notes.md")
          [[ "${{ steps.ver.outputs.prerelease }}" == "true" ]] && flags+=(--prerelease)
          gh release create "$GITHUB_REF_NAME" build/BrainDump.dmg "${flags[@]}"
```

## Release notes body: `.github/release-notes.md`

Static, tracked, reviewable. This block is **prepended** to GitHub's
auto-generated changelog (see the Publish step), so the final release body reads:
install/first-launch instructions first, then a `## What's Changed` commit/PR
list. The first-launch instructions are the critical content — without them, an
unsigned download looks broken.

```markdown
## Install

1. Download `BrainDump.dmg` below, open it, and drag **Brain Dump** to Applications.
2. **First launch** (the app is unsigned): double-click it once — macOS will block it.
   Open **System Settings → Privacy & Security**, scroll to the "Brain Dump was blocked"
   message, and click **Open Anyway**, then confirm.
3. If you instead see *"Brain Dump is damaged and can't be opened"*, run this once in Terminal,
   then reopen the app:

       xattr -dr com.apple.quarantine /Applications/BrainDump.app

This app is not notarized (no paid Apple Developer account), so macOS requires a
one-time manual approval. Source is public.
```

## Verification

GitHub Actions YAML can't be unit-tested in this repo's harness; verification is:

1. **`swift test`** — existing suite still green.
2. **Local end-to-end of the changed build path** (the real test of prep steps 2-3):
   ```bash
   MARKETING_VERSION=9.9.9 CURRENT_PROJECT_VERSION=42 ./scripts/build-dmg.sh
   /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
     .build/xcode/Build/Products/Release/BrainDump.app/Contents/Info.plist   # → 9.9.9
   ```
   Confirms scheme resolves headlessly, Info.plist substitution works, and a DMG
   is produced.
3. **`actionlint`** on `.github/workflows/release.yml` (syntax/expression check).
4. **Live proof**: cut a real `v0.x.x` tag and watch the run produce the Release.

## Risks / gotchas

- **Gatekeeper variance.** The unsigned experience is "Open Anyway" *most* of the
  time but not guaranteed; the notes give the `xattr` fallback. This is inherent
  to the free path, not a bug.
- **`create-dmg` not preinstalled** on runners — handled by the `brew install` step
  (~tens of seconds).
- **`create-dmg` on headless CI.** It drives Finder via AppleScript to place the
  background/icons; this can occasionally hang or fail on CI. It generally works on
  GitHub-hosted macOS runners (they have a GUI session). Mitigation if it proves
  flaky: retry the step, or fall back to a plain `hdiutil`-built DMG (loses the
  custom window layout/background, not the contents).
- **Scheme correctness.** A hand-written `.xcscheme` with a wrong blueprint id
  builds nothing; the local headless build in Verification step 2 catches this.
- **macos-14 image churn.** GitHub rotates default Xcode on the image; if a future
  Xcode breaks the build, pin Xcode via `sudo xcode-select -s` or
  `maxim-lobanov/setup-xcode`. Not pinning now to stay lean.

## Out of scope

- Developer ID signing + notarization (documented as a drop-in upgrade: add a
  signing/notarize step; the rest of the pipeline is unchanged).
- Auto-incrementing `MARKETING_VERSION` in the project; the tag is authoritative.
- README install section; the release notes are the canonical install instructions.
- Universal-build matrix / separate Intel + Apple Silicon artifacts (single
  universal DMG covers both).
