# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`todoosx` is a macOS To Do app modeled on the Harvard Business Review Daily Timebox planner. Each day is a single sheet with three sections — **Brain Dump**, **Top 3**, and an hour-blocked **Schedule** — and uncompleted items roll forward to the next day's brain dump automatically.

UI aesthetic guidance ("Neo-Academic" — deep navy + crimson, Hanken Grotesk + Source Serif 4, thin borders, no heavy shadows) is in `docs/design-system.md`.

## Commands

Requires macOS 14+ and Xcode (full Xcode, not just Command Line Tools — see [Toolchain notes](#toolchain-notes)).

```bash
swift build                       # build library + app
swift test                        # run all tests
swift test --filter <name>        # run a single test (substring match on @Test function name)
swift run todoosx                 # launch the SwiftUI app
swift build -c release --target todoosx   # release build of app only
                                          # (release build of full package fails because the test
                                          # target uses @testable; this is normal)
```

## Architecture

```
Sources/
  TodoosxKit/        ← library: models, services, AppState, views
    Models/          ← SwiftData @Model classes + TodoError + drag payload
    Services/        ← Day/Task/Schedule services (business logic)
    App/             ← AppState (@Observable, owns selected date)
    Views/           ← SwiftUI views — AppShell, DayView, three section views
    Support/         ← Date+StartOfDay
  todoosx/           ← app executable (@main TodoosxApp; configures ModelContainer)
Tests/
  todoosxTests/      ← Swift Testing target (XCTest is NOT used)
    TestSupport/     ← InMemoryStore + TestDate helpers
```

**The shape that matters:**

- **Three SwiftData entities**: `Day`, `TaskItem`, `ScheduleEntry`. `Day` has a unique `date` (start-of-day-normalized), and owns items and schedule entries via cascade relationships. A `TaskItem` belongs to one `Day` (its brain-dump day). A `ScheduleEntry` is a **placement** — distinct from the item itself — so an item can be in brain dump *and* in the schedule without being copied.
- **Top 3 is an ordered id list on `Day`** (`top3ItemIDs: [UUID]`), not a relationship. Order matters; max 3 items.
- **All business logic lives in services**, never in views. Views construct a service inline from the `ModelContext`. Tests exercise services directly against an in-memory `ModelContainer` (`TestSupport/InMemoryStore.swift`).
- **`AppState` is the only orchestrator** above the service layer. It owns `selectedDate`, runs `rollover` on init, and is created lazily by `AppShell` in `.onAppear` so it has access to the environment's `modelContext`.

## Non-obvious behavior

**Rollover semantics** (see `DayService.rollover` and its tests). On launch the app sweeps every past `Day`:
- An item that has **at least one completed `ScheduleEntry`** on its day stays put — that day's record (item, all its schedule entries, top-3 reference) is preserved as history.
- Any item **without** a completed entry on its day is re-parented to today's `Day`; that item's schedule entries on the old day are deleted and its id is removed from the old day's top 3.
- The algorithm is naturally idempotent — running it twice has no extra effect because uncompleted items are no longer on past days after the first pass.

**Read-only past days.** Views accept `isReadOnly: state.isPast` and hide add/edit/delete/drag affordances. Future days are not navigable in the first pass (`goToNextDay` clamps at today).

**Schedule conflicts.** `ScheduleService.schedule(...)` validates `startHour in 5..23`, `durationHours >= 1`, `startHour + durationHours <= 24`, and that the half-open range `[start, start+duration)` does not overlap any existing entry on the day. Adjacent blocks (e.g., 9-10 then 10-11) are allowed; overlapping throws `TodoError.scheduleConflict`.

**Drag payload.** `TaskItemDragPayload` is a tiny `Codable` + `Transferable` wrapper around the item's UUID. Brain-dump and top-3 rows are `.draggable(...)`. Empty schedule slots are `.dropDestination(for: TaskItemDragPayload.self)`. On drop, `ScheduleSection` opens a `DurationPromptSheet`; the actual `schedule(...)` call happens after the sheet confirms.

## Conventions

- **Public surface on `TodoosxKit`**: types referenced from the `todoosx` app target or `todoosxTests` must be `public`. Tests use `@testable import TodoosxKit` for internal access but the app target uses the public surface.
- **`@MainActor` is per-`@Test` function**, not per-class. Swift Testing has no test classes here; suite grouping is implicit.
- **Test dates** are constructed via `TestDate.at(y, m, d, hour:, minute:)` so they're deterministic across machines and time zones.
- **Date normalization**: every `Date` that flows into a `Day.date` is run through `Date.startOfLocalDay()`. The unique constraint on `Day.date` depends on this; don't bypass it.
- **Tests live next to the code they exercise** (one file per service / per major concept). When extending a service, append `@Test` functions to the matching `*Tests.swift` file rather than creating a new file.

## Toolchain notes

The project assumes a normal Xcode install with its license accepted (`sudo xcodebuild -license accept`). If only Command Line Tools are available, `swift test` silently no-ops (no `xctest` runner) and `@Model`/`#Predicate` won't compile (missing macro plugins). The git history (commits up to and including `7886c75`) contains a workaround that used a custom test-runner executable + manual `-plugin-path` flags; that was reverted in favor of the conventional layout once Xcode was available. If you encounter the CLT-only environment again, look at that commit's parents for the pattern.
