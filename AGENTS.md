# AGENTS.md

This file provides guidance to AI agent when working with code in this repository.

## What this is

**Brain Dump** is a macOS To Do app modeled on the Harvard Business Review Daily Timebox planner. Each day is a single sheet with three sections — **Brain Dump**, **Top 3**, and an hour-blocked **Schedule** — and uncompleted items roll forward to the next day's brain dump automatically.

> The git repo directory is `braindump` (original codename: `todoosx`); the app and all Swift targets are `BrainDump` / `BrainDumpKit`.

UI aesthetic guidance ("Neo-Academic" — deep navy + crimson, Hanken Grotesk + Source Serif 4, thin borders, no heavy shadows) is in `docs/design-system.md`.

## Commands

Requires macOS 14+ and Xcode (full Xcode, not just Command Line Tools — see [Toolchain notes](#toolchain-notes)).

**Day-to-day development is in Xcode:**

```bash
xed BrainDump.xcodeproj           # opens the APP project; Cmd+R runs + debugs the app
```

> **To run the app you must open `BrainDump.xcodeproj`** (the app target) and select the **BrainDump** scheme — not `BrainDumpKit`.
> Opening `Package.swift` or the repo folder in Xcode loads the **SwiftPM package**, which declares only the `BrainDumpKit` library + tests and **has no app target** — so Build succeeds but Run launches nothing ("doesn't run any application"). When working in a git worktree, open *that worktree's* `BrainDump.xcodeproj`, not the main checkout's.

**Library + tests (SwiftPM) — `Package.swift` is library + tests only, no runnable app:**

```bash
swift build                       # build BrainDumpKit
swift test                        # run all tests
swift test --filter <name>        # run a single test (substring match on @Test function name)
```

**Headless launch (CLI/CI):**

```bash
./scripts/run-app.sh              # xcodebuild build + open BrainDump.app
CONFIG=Release ./scripts/run-app.sh
./scripts/build-dmg.sh            # Release .app → unsigned .dmg (needs `brew install create-dmg`)
```

## Architecture

```
Package.swift             ← library + tests only (no executable target)
BrainDump.xcodeproj/      ← macOS app target; depends on local SPM package for BrainDumpKit
BrainDump/                ← app target sources
  BrainDumpApp.swift      ← @main; bootstraps the store via PersistenceController.makeContainer()
  Info.plist              ← bundle metadata (uses $(PRODUCT_NAME) etc. for xcodebuild substitution)
  AppIcon.icns
Sources/
  BrainDumpKit/           ← library: models, persistence, services, AppState, views
    Models/               ← @Model classes (Day, TaskItem, ScheduleEntry) + TodoError + drag payload
    Persistence/          ← PersistenceController (corruption-recovering container) + versioned schema & migration plan
    Services/             ← Day / Task / Schedule / Backlog / Backup services (business logic)
    App/                  ← AppState (@Observable; owns selected date + sidebar destination)
    Views/                ← AppShell (sidebar + canvas), DayView + sections (Top3/BrainDump/Schedule), Tasks/Backlog screens, TimeBlockSheet, TaskDetailSheet, SettingsSheet, MonthCalendarView, tag/chip/row helpers
    Support/              ← Date+StartOfDay, TimeFormat, ScheduleDefaults, Theme, Fonts, WiseSayings
Tests/
  BrainDumpTests/         ← Swift Testing target (XCTest is NOT used); VisualSnapshotTests renders PNGs
    TestSupport/          ← InMemoryStore + FileBackedStore (on-disk) + TestDate helpers
```

**The shape that matters:**

- **Three SwiftData entities**: `Day`, `TaskItem`, `ScheduleEntry`. `Day` has a unique `date` (start-of-day-normalized), and owns items and schedule entries via cascade relationships. A `TaskItem` belongs to one `Day` (its brain-dump day). A `ScheduleEntry` is a **placement** — distinct from the item itself — so an item can be in brain dump *and* in the schedule without being copied.
- **Top 3 is an ordered id list on `Day`** (`top3ItemIDs: [UUID]`), not a relationship. Order matters; max 3 items.
- **Backlog is not a fourth entity** — it's `TaskItem.isBacklog == true` with `day == nil`. `BacklogService` promotes a backlog item into a day's brain dump (`promoteToBrainDump`) or sends one back (`moveToBacklog`, which also strips it from top 3 and deletes its schedule entries). Items also carry `notes` and a normalized `tags: [String]` (trimmed, lowercased, deduped); `TaskService.allTags()` is the global tag vocabulary, and `searchTasks(...)` powers the Tasks screen.
- **All business logic lives in services**, never in views. Views construct a service inline from the `ModelContext`. Tests exercise services directly against an in-memory `ModelContainer` (`TestSupport/InMemoryStore.swift`).
- **`AppState` is the only orchestrator** above the service layer. It owns `selectedDate`, runs `rollover` on init, and is created lazily by `AppShell` in `.onAppear` so it has access to the environment's `modelContext`. It also owns `selectedDestination` (`SidebarDestination`: `today`/`tasks`/`backlog` — the app is a sidebar shell, not one day view) and `dataGeneration` (bumped on every wipe/restore; see Clear Data below).
- **App-level settings** live on `AppState`: `dayStartHour`/`dayEndHour` (default 5/22, persisted to `UserDefaults`, validated to span ≥ 4 hours) and `isSidebarVisible` (in-memory only). Views read these directly; there's no separate settings object.

## Non-obvious behavior

**Rollover semantics** (see `DayService.rollover` and its tests). On launch the app sweeps every past `Day`:
- An item that has **at least one completed `ScheduleEntry`** on its day stays put — that day's record (item, all its schedule entries, top-3 reference) is preserved as history.
- Any item **without** a completed entry on its day is re-parented to today's `Day`; that item's schedule entries on the old day are deleted and its id is removed from the old day's top 3.
- The algorithm is naturally idempotent — running it twice has no extra effect because uncompleted items are no longer on past days after the first pass.

**Read-only past days.** Views accept `isReadOnly: state.isPast` and hide add/edit/delete/drag affordances. Future days are not navigable in the first pass (`goToNextDay` clamps at today).

**Schedule conflicts.** `ScheduleService.schedule(...)` operates on minutes since midnight: validates `durationMinutes >= 15`, `startMinute >= 0`, `startMinute + durationMinutes <= 1440`, and that the half-open range `[start, start+duration)` does not overlap any existing entry on the day. Adjacent blocks (e.g., 9:00-10:00 then 10:00-11:15) are allowed; overlapping throws `TodoError.scheduleConflict`. The day-window hours (`AppState.dayStartHour`/`dayEndHour`) bound what the grid *shows*, not what the service accepts.

**Drag payload.** `TaskItemDragPayload` is a tiny `Codable` + `Transferable` wrapper around the item's UUID. Brain-dump and top-3 rows are `.draggable(...)`. Empty schedule slots are `.dropDestination(for: TaskItemDragPayload.self)`. On drop, `ScheduleSection` opens a `TimeBlockSheet` (Reminders-style start/end `DatePicker`s, 15-min snap); the actual `schedule(...)` call happens after the sheet confirms.

**Never crashes on launch.** `PersistenceController.makeContainer()` opens the versioned store (`BrainDumpSchemaV1` via `BrainDumpMigrationPlan`); on failure it moves the unreadable store and its `-wal`/`-shm` sidecars aside (`BrainDump.store.corrupt-<unixstamp>`, **preserved, not deleted**) and retries fresh; last resort is an in-memory container. The outcome is a `StoreRecovery` value surfaced once as an alert in `AppShell`. Store path: `~/Library/Application Support/<dir>/BrainDump.store`, where `<dir>` is `PersistenceController.appDirectoryName` — `BrainDump` for Release and `BrainDump-debug` for Debug builds, so a dev build never migrates or clobbers the installed app's real data (the calendar cache shares the same directory). Schema changes go through a new `MigrationStage` in `BrainDumpMigrationPlan` — never an ad-hoc model edit.

**Clear Data / restore rebuild.** `clearAllData` and `importBackup` wipe content but **preserve preferences** (day bounds), snap navigation to Today, and bump `AppState.dataGeneration`. That counter is folded into `DayView`'s identity (`.id(state.dataGeneration)`) so the subtree rebuilds against fresh models instead of re-rendering against just-deleted ones — the fix for the SwiftData Clear-Data crash. Its regression test (`ClearDataCrashTests`) uses the on-disk `FileBackedStore`; `InMemoryStore` doesn't reproduce the deletion timing.

**Backup is versioned JSON.** `BackupService` encodes a `BackupSnapshot { version, days, backlogItems }` of plain DTOs (ISO-8601 dates) and restores **replace-all**. Malformed input throws `BackupError.malformed`; a version mismatch throws `.unsupportedVersion`. Reached via `AppState.exportBackupData()` / `importBackup(from:)`; UI is in `SettingsSheet`.

**Sidebar auto-collapse.** `AppShell` hides the sidebar when the window is narrower than `sidebarThreshold` (= `canvasMin + sidebarWidth` = 1248) **without** mutating the user's `isSidebarVisible` preference, so it returns when the window grows. ⌘B toggles the preference. **The window's minimum width (`WindowSizing.minWidth`) is pinned to `sidebarThreshold`** so a user can't normally resize into the auto-collapsed state — where the toggle (and the navigation + Settings the sidebar holds) would have no effect, since `effectivelyVisible = isSidebarVisible && canFit`. `WindowSizing.minWidth` is nonisolated and can't reference `@MainActor` `AppShell.sidebarThreshold` directly, so it's the literal `1248`; `WindowSizingTests.minimumWidthFitsSidebar` keeps them in sync. Auto-collapse now only fires as graceful degradation if the OS forces a sub-1248 window (a screen narrower than 1248pt).

## Conventions

- **Public surface on `BrainDumpKit`**: types referenced from the `BrainDump` app target must be `public`. Tests use `@testable import BrainDumpKit` for internal access but the app target consumes the public surface only.
- **`@MainActor` is per-`@Test` function**, not per-class. Swift Testing has no test classes here; suite grouping is implicit.
- **Test dates** are constructed via `TestDate.at(y, m, d, hour:, minute:)` so they're deterministic across machines and time zones.
- **Date normalization**: every `Date` that flows into a `Day.date` is run through `Date.startOfLocalDay()`. The unique constraint on `Day.date` depends on this; don't bypass it.
- **Tests live next to the code they exercise** (one file per service / per major concept). When extending a service, append `@Test` functions to the matching `*Tests.swift` file rather than creating a new file.
- **Visual checks are snapshot tests.** `VisualSnapshotTests` renders SwiftUI through an offscreen `NSWindow` + `NSHostingView` (not `ImageRenderer`, which collapses `ScrollView`s/`TextField`s) and writes PNGs to `/tmp/braindump-shots/`. To satisfy the "check UI with screenshot tests" rule below, add/extend a `@Test` there and inspect the PNG.
- **Adding files to the app target**: drop them in `BrainDump/` and add the reference in Xcode (or by hand in `BrainDump.xcodeproj/project.pbxproj`). Library code belongs under `Sources/BrainDumpKit/` and is picked up automatically by SwiftPM.

## Toolchain notes

The project assumes a normal Xcode install with its license accepted (`sudo xcodebuild -license accept`). If only Command Line Tools are available, `swift test` silently no-ops (no `xctest` runner) and `@Model`/`#Predicate` won't compile (missing macro plugins). The git history (commits up to and including `7886c75`) contains a workaround that used a custom test-runner executable + manual `-plugin-path` flags; that was reverted in favor of the conventional layout once Xcode was available. If you encounter the CLT-only environment again, look at that commit's parents for the pattern.


## Coding Task Completion Rules
- If the request is related to UI, check output always with screenshot tests for visual accuracy.
- All implemenations must be covered by tests. If the request is related to a bug fix, include a test that fails before the fix and passes after.
- For new features, include tests that cover the expected behavior and edge cases.