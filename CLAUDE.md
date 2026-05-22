# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Brain Dump** is a macOS To Do app modeled on the Harvard Business Review Daily Timebox planner. Each day is a single sheet with three sections — **Brain Dump**, **Top 3**, and an hour-blocked **Schedule** — and uncompleted items roll forward to the next day's brain dump automatically.

> The repo directory is still named `todoosx/` (original codename); the app and all Swift targets are `BrainDump` / `BrainDumpKit`.

UI aesthetic guidance ("Neo-Academic" — deep navy + crimson, Hanken Grotesk + Source Serif 4, thin borders, no heavy shadows) is in `docs/design-system.md`.

## Commands

Requires macOS 14+ and Xcode (full Xcode, not just Command Line Tools — see [Toolchain notes](#toolchain-notes)).

**Day-to-day development is in Xcode:**

```bash
xed BrainDump.xcodeproj           # opens in Xcode; Cmd+R runs + debugs the app
```

**Library + tests (SwiftPM):**

```bash
swift build                       # build BrainDumpKit
swift test                        # run all tests
swift test --filter <name>        # run a single test (substring match on @Test function name)
```

**Headless launch (CLI/CI):**

```bash
./scripts/run-app.sh              # xcodebuild build + open BrainDump.app
CONFIG=Release ./scripts/run-app.sh
```

## Architecture

```
Package.swift             ← library + tests only (no executable target)
BrainDump.xcodeproj/      ← macOS app target; depends on local SPM package for BrainDumpKit
BrainDump/                ← app target sources
  BrainDumpApp.swift      ← @main; configures ModelContainer
  Info.plist              ← bundle metadata (uses $(PRODUCT_NAME) etc. for xcodebuild substitution)
  AppIcon.icns
Sources/
  BrainDumpKit/           ← library: models, services, AppState, views
    Models/               ← SwiftData @Model classes + TodoError + drag payload
    Services/             ← Day/Task/Schedule services (business logic)
    App/                  ← AppState (@Observable, owns selected date)
    Views/                ← SwiftUI views — AppShell + DayView, three section views (Top3/BrainDump/Schedule), TimeBlockSheet, TaskDetailSheet, SettingsSheet, MonthCalendarView, supporting chips/rows
    Support/              ← Date+StartOfDay, TimeFormat, Theme, Fonts, WiseSayings
Tests/
  BrainDumpTests/         ← Swift Testing target (XCTest is NOT used)
    TestSupport/          ← InMemoryStore + TestDate helpers
```

**The shape that matters:**

- **Three SwiftData entities**: `Day`, `TaskItem`, `ScheduleEntry`. `Day` has a unique `date` (start-of-day-normalized), and owns items and schedule entries via cascade relationships. A `TaskItem` belongs to one `Day` (its brain-dump day). A `ScheduleEntry` is a **placement** — distinct from the item itself — so an item can be in brain dump *and* in the schedule without being copied.
- **Top 3 is an ordered id list on `Day`** (`top3ItemIDs: [UUID]`), not a relationship. Order matters; max 3 items.
- **All business logic lives in services**, never in views. Views construct a service inline from the `ModelContext`. Tests exercise services directly against an in-memory `ModelContainer` (`TestSupport/InMemoryStore.swift`).
- **`AppState` is the only orchestrator** above the service layer. It owns `selectedDate`, runs `rollover` on init, and is created lazily by `AppShell` in `.onAppear` so it has access to the environment's `modelContext`.
- **App-level settings** live on `AppState`: `dayStartHour`/`dayEndHour` (default 5/22, persisted to `UserDefaults`, validated to span ≥ 4 hours) and `isSidebarVisible` (in-memory only). Views read these directly; there's no separate settings object.

## Non-obvious behavior

**Rollover semantics** (see `DayService.rollover` and its tests). On launch the app sweeps every past `Day`:
- An item that has **at least one completed `ScheduleEntry`** on its day stays put — that day's record (item, all its schedule entries, top-3 reference) is preserved as history.
- Any item **without** a completed entry on its day is re-parented to today's `Day`; that item's schedule entries on the old day are deleted and its id is removed from the old day's top 3.
- The algorithm is naturally idempotent — running it twice has no extra effect because uncompleted items are no longer on past days after the first pass.

**Read-only past days.** Views accept `isReadOnly: state.isPast` and hide add/edit/delete/drag affordances. Future days are not navigable in the first pass (`goToNextDay` clamps at today).

**Schedule conflicts.** `ScheduleService.schedule(...)` operates on minutes since midnight: validates `durationMinutes >= 15`, `startMinute >= 0`, `startMinute + durationMinutes <= 1440`, and that the half-open range `[start, start+duration)` does not overlap any existing entry on the day. Adjacent blocks (e.g., 9:00-10:00 then 10:00-11:15) are allowed; overlapping throws `TodoError.scheduleConflict`. The day-window hours (`AppState.dayStartHour`/`dayEndHour`) bound what the grid *shows*, not what the service accepts.

**Drag payload.** `TaskItemDragPayload` is a tiny `Codable` + `Transferable` wrapper around the item's UUID. Brain-dump and top-3 rows are `.draggable(...)`. Empty schedule slots are `.dropDestination(for: TaskItemDragPayload.self)`. On drop, `ScheduleSection` opens a `TimeBlockSheet` (Reminders-style start/end `DatePicker`s, 15-min snap); the actual `schedule(...)` call happens after the sheet confirms.

## Conventions

- **Public surface on `BrainDumpKit`**: types referenced from the `BrainDump` app target must be `public`. Tests use `@testable import BrainDumpKit` for internal access but the app target consumes the public surface only.
- **`@MainActor` is per-`@Test` function**, not per-class. Swift Testing has no test classes here; suite grouping is implicit.
- **Test dates** are constructed via `TestDate.at(y, m, d, hour:, minute:)` so they're deterministic across machines and time zones.
- **Date normalization**: every `Date` that flows into a `Day.date` is run through `Date.startOfLocalDay()`. The unique constraint on `Day.date` depends on this; don't bypass it.
- **Tests live next to the code they exercise** (one file per service / per major concept). When extending a service, append `@Test` functions to the matching `*Tests.swift` file rather than creating a new file.
- **Adding files to the app target**: drop them in `BrainDump/` and add the reference in Xcode (or by hand in `BrainDump.xcodeproj/project.pbxproj`). Library code belongs under `Sources/BrainDumpKit/` and is picked up automatically by SwiftPM.

## Toolchain notes

The project assumes a normal Xcode install with its license accepted (`sudo xcodebuild -license accept`). If only Command Line Tools are available, `swift test` silently no-ops (no `xctest` runner) and `@Model`/`#Predicate` won't compile (missing macro plugins). The git history (commits up to and including `7886c75`) contains a workaround that used a custom test-runner executable + manual `-plugin-path` flags; that was reverted in favor of the conventional layout once Xcode was available. If you encounter the CLT-only environment again, look at that commit's parents for the pattern.


## Coding Task Completion Rules
- If the request is related to UI, check output always with screenshot tests for visual accuracy.
- All implemenations must be covered by tests. If the request is related to a bug fix, include a test that fails before the fix and passes after.
- For new features, include tests that cover the expected behavior and edge cases.