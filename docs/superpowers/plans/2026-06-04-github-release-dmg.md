# DMG GitHub Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pushing a `vX.Y.Z` tag builds an unsigned universal `BrainDump.dmg` and publishes it as a GitHub Release with first-launch instructions + auto-generated changelog.

**Architecture:** A tag-triggered GitHub Actions workflow on a `macos-14` runner reuses the existing `scripts/build-dmg.sh` (parameterized to inject the version, drop hardened runtime, and force a universal binary), then `gh release create` attaches the DMG. Two repo prerequisites unblock headless CI builds: a committed shared Xcode scheme and version-substitutable `Info.plist` keys.

**Tech Stack:** GitHub Actions, `xcodebuild`, `create-dmg` (Homebrew), `gh` CLI, bash.

**Spec:** `docs/superpowers/specs/2026-06-04-github-release-dmg-design.md`

**Note on verification:** This is build/CI infrastructure — there are no Swift source changes, so no SwiftPM unit tests are added. Verification is command-based (per the spec's "Verification" section): a local end-to-end DMG build that asserts the stamped version, codesign flags, and architectures (Task 4); `actionlint` on the YAML (Task 6); and a live tag-push smoke test (Task 7). The existing `swift test` suite must stay green and is enforced as a CI gate.

---

### Task 1: Commit a shared Xcode scheme

Without a committed shared scheme, `xcodebuild -scheme BrainDump` relies on in-memory auto-generation that is unreliable on a fresh CI checkout. The native target UUID is `BD0000000000000000000050` (verified in `project.pbxproj`).

**Files:**
- Create: `BrainDump.xcodeproj/xcshareddata/xcschemes/BrainDump.xcscheme`

- [ ] **Step 1: Create the shared scheme file**

Create `BrainDump.xcodeproj/xcshareddata/xcschemes/BrainDump.xcscheme` with exactly:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "BD0000000000000000000050"
               BuildableName = "BrainDump.app"
               BlueprintName = "BrainDump"
               ReferencedContainer = "container:BrainDump.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "BD0000000000000000000050"
            BuildableName = "BrainDump.app"
            BlueprintName = "BrainDump"
            ReferencedContainer = "container:BrainDump.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "BD0000000000000000000050"
            BuildableName = "BrainDump.app"
            BlueprintName = "BrainDump"
            ReferencedContainer = "container:BrainDump.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
```

- [ ] **Step 2: Verify the scheme is valid and seen as shared**

Run: `xcodebuild -list -project BrainDump.xcodeproj`
Expected: `BrainDump` appears under **Schemes**.

Run: `xcodebuild -project BrainDump.xcodeproj -scheme BrainDump -configuration Release -showBuildSettings >/dev/null && echo OK`
Expected: prints `OK` (the scheme parses and resolves with no error).

- [ ] **Step 3: Commit**

```bash
git add BrainDump.xcodeproj/xcshareddata/xcschemes/BrainDump.xcscheme
git commit -m "build: commit shared BrainDump scheme for headless CI builds

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Make Info.plist version-substitutable

The version is currently a hardcoded literal, so a command-line `MARKETING_VERSION=...` override would be silently ignored. `GENERATE_INFOPLIST_FILE = NO` and `INFOPLIST_FILE = BrainDump/Info.plist` are set, so variable substitution is active (same as the existing `$(PRODUCT_NAME)`).

**Files:**
- Modify: `BrainDump/Info.plist:17-20`

- [ ] **Step 1: Replace the two literal version values with build-setting variables**

Change:

```xml
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
```

to:

```xml
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
```

- [ ] **Step 2: Verify the plist is still valid**

Run: `plutil -lint BrainDump/Info.plist`
Expected: `BrainDump/Info.plist: OK`

(Functional verification — that the substitution produces the right version — happens in Task 4, where we actually build.)

- [ ] **Step 3: Commit**

```bash
git add BrainDump/Info.plist
git commit -m "build: make Info.plist version keys substitutable

Lets the release build stamp CFBundleShortVersionString/CFBundleVersion
from the git tag via xcodebuild MARKETING_VERSION/CURRENT_PROJECT_VERSION
overrides. Local Xcode builds still default to the project's 0.1.0 / 1.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Parameterize `scripts/build-dmg.sh`

Make the DMG build accept an injected version and always produce a distributable artifact (hardened runtime off, universal binary). Defaults preserve current local behavior when the env vars are unset.

**Files:**
- Modify: `scripts/build-dmg.sh:25-30` (the `xcodebuild` invocation)

- [ ] **Step 1: Add build-setting overrides before the xcodebuild call**

Replace:

```bash
xcodebuild \
    -project BrainDump.xcodeproj \
    -scheme BrainDump \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED" \
    build >/dev/null
```

with:

```bash
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
```

- [ ] **Step 2: Verify the script still parses**

Run: `bash -n scripts/build-dmg.sh && echo OK`
Expected: prints `OK` (no syntax error).

- [ ] **Step 3: Commit**

```bash
git add scripts/build-dmg.sh
git commit -m "build: inject version + force unsigned universal DMG in build-dmg.sh

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Local end-to-end verification (the real test of Tasks 1-3)

This proves the shared scheme builds headlessly, the version substitution works, the binary is unsigned-without-hardened-runtime, and it's universal. No file changes — pure verification. `create-dmg 1.2.3` is already installed locally.

- [ ] **Step 1: Build the DMG with an injected sentinel version**

Run:
```bash
MARKETING_VERSION=9.9.9 CURRENT_PROJECT_VERSION=42 ./scripts/build-dmg.sh
```
Expected: ends with `Created .../build/BrainDump.dmg` and exits 0.

- [ ] **Step 2: Assert the stamped version**

Run:
```bash
APP=.build/xcode/Build/Products/Release/BrainDump.app
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist"
```
Expected: `9.9.9` then `42`.

- [ ] **Step 3: Assert hardened runtime is off but the app is still ad-hoc signed**

Run:
```bash
codesign -dvvv .build/xcode/Build/Products/Release/BrainDump.app 2>&1 | grep -E "flags|Signature"
```
Expected: `CodeDirectory ... flags=0x2(adhoc) ...` (note: **no** `runtime`) and `Signature=adhoc`.

- [ ] **Step 4: Assert the binary is universal and the DMG exists**

Run:
```bash
lipo -archs .build/xcode/Build/Products/Release/BrainDump.app/Contents/MacOS/BrainDump
ls -lh build/BrainDump.dmg
```
Expected: archs line contains both `x86_64` and `arm64`; the DMG file exists.

- [ ] **Step 5: Confirm the existing test suite is green**

Run: `swift test`
Expected: all tests pass (this is the same gate CI will enforce).

> If any assertion fails, fix the relevant task before proceeding. A version mismatch ⇒ revisit Task 2; a `runtime` flag still present ⇒ revisit Task 3; a build/scheme error ⇒ revisit Task 1.

---

### Task 5: Add the release-notes body

Static, tracked install/first-launch instructions. The Publish step (Task 6) prepends this above GitHub's auto-generated changelog.

**Files:**
- Create: `.github/release-notes.md`

- [ ] **Step 1: Create `.github/release-notes.md`**

```markdown
## Install

1. Download `BrainDump.dmg` below, open it, and drag **Brain Dump** to Applications.
2. **First launch** (the app is unsigned): double-click it once — macOS will block it.
   Open **System Settings → Privacy & Security**, scroll to the "Brain Dump was blocked"
   message, and click **Open Anyway**, then confirm.
3. If you instead see *"Brain Dump is damaged and can't be opened"*, run this once in
   Terminal, then reopen the app:

       xattr -dr com.apple.quarantine /Applications/BrainDump.app

This app is not notarized (no paid Apple Developer account), so macOS requires a
one-time manual approval. Source is public.
```

- [ ] **Step 2: Verify it renders as valid Markdown (sanity check)**

Run: `test -s .github/release-notes.md && echo OK`
Expected: prints `OK`.

- [ ] **Step 3: Commit**

```bash
git add .github/release-notes.md
git commit -m "docs: add DMG release-notes body with first-launch instructions

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Add the release workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create `.github/workflows/release.yml`**

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

> Fallback note: if `swift test` fails to load the SwiftData/`#Predicate` macros on the runner, replace that step's command with `xcodebuild test -project BrainDump.xcodeproj -scheme BrainDumpKit -destination 'platform=macOS'`. Try `swift test` first — it matches local dev.

- [ ] **Step 2: Lint the workflow**

Run:
```bash
brew install actionlint
actionlint .github/workflows/release.yml
```
Expected: no output, exit 0 (actionlint prints nothing when clean).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: publish DMG to GitHub Releases on version tag push

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Live smoke test (requires pushing to GitHub; publishes a release)

This is the only true end-to-end test of the workflow. It needs network access and creates a real (pre)release. Execute this with the user — do not run unattended. A tag may point at a feature-branch commit, so this works before merging to `main`.

- [ ] **Step 1: Push the branch and a disposable pre-release tag**

```bash
git push -u origin feat/github-release-dmg
git tag v0.1.1-rc.1
git push origin v0.1.1-rc.1
```

- [ ] **Step 2: Watch the run**

Run: `gh run watch` (or `gh run list --workflow=release.yml`)
Expected: the `Release DMG` workflow succeeds on all steps.

- [ ] **Step 3: Verify the release**

Run: `gh release view v0.1.1-rc.1`
Expected: marked **Pre-release**; has a `BrainDump.dmg` asset; body shows the Install instructions followed by a `## What's Changed` section.

Optionally download and open the DMG on a clean Mac to confirm the Gatekeeper "Open Anyway" path.

- [ ] **Step 4: Tear down the test release/tag**

```bash
gh release delete v0.1.1-rc.1 --yes --cleanup-tag
```
(`--cleanup-tag` also deletes the remote tag. If your `gh` is older, run `git push origin :refs/tags/v0.1.1-rc.1` separately.)

- [ ] **Step 5: Cut the real release**

After merging `feat/github-release-dmg` to `main` (or from the branch tip):

```bash
git tag v0.2.0
git push origin v0.2.0
```
Expected: a full (non-pre) release `v0.2.0` with the DMG attached.

---

## Spec coverage check

- Unsigned + hardened-runtime-off → Task 3 (`ENABLE_HARDENED_RUNTIME=NO`), asserted in Task 4 Step 3.
- Universal binary → Task 3 (`ONLY_ACTIVE_ARCH=NO`), asserted in Task 4 Step 4.
- Tag `v*` trigger + semver validation + prerelease detection → Task 6 (`on.push.tags`, `Derive version`).
- Tag-driven version, run-number build number → Task 2 + Task 6 (`Build DMG` env), asserted in Task 4 Step 2 / Task 6 `Verify stamped version`.
- `swift test` gate → Task 6 (`Run tests (gate)`).
- Reuse `build-dmg.sh` → Task 3 + Task 6 (`./scripts/build-dmg.sh`).
- `gh` CLI release, no third-party action → Task 6 (`Publish release`).
- Static notes prepended to auto-generated changelog → Task 5 + Task 6 (`generate-notes` API + prepend).
- Shared scheme prerequisite → Task 1.
- Info.plist substitution prerequisite → Task 2.
- Verification (local e2e, actionlint, live push) → Tasks 4, 6 Step 2, 7.
