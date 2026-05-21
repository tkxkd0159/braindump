# todoosx — Design Spec

**Date:** 2026-05-22
**Status:** Approved for implementation

## Goal

A "pretty" macOS To Do app built around the Harvard Business Review Daily Timebox planner. Each day is a single sheet with three sections — Brain Dump, Top 3, and a time-blocked Schedule — and uncompleted items automatically roll over to the next day.

The app is built in Swift with SwiftUI + SwiftData. Every feature lands behind a passing test before the next feature begins.

## Concept

A user's daily flow:

1. **Brain dump** — capture every task that's on your mind for today.
2. **Top 3** — pick exactly three brain-dump items to escalate as today's priorities.
3. **Schedule** — drag any brain-dump or top-3 item into a one-hour slot on the schedule. On drop, the app asks for a duration in hours; the item then spans that many contiguous slots.
4. **Check off** completed schedule blocks during the day.
5. **Tomorrow**: anything you didn't check off is automatically pushed back into tomorrow's brain dump.

Past days are read-only history.

## Non-goals (first pass)

- iCloud / multi-device sync.
- Notifications, reminders, or background timers.
- Tags, projects, or hierarchical lists.
- UI tests; drag-and-drop is exercised manually until the data layer is solid.

## Tech stack

- Swift, SwiftUI, SwiftData. macOS 14+.
- XCTest with in-memory `ModelContainer` for unit tests.
- Xcode project (not Swift Package), single app target + test target.

## Architecture

```
+--------------------------+
| Views (SwiftUI)          |
|  AppShell                |
|   DayView                |
|    BrainDumpSection      |
|    Top3Section           |
|    ScheduleSection       |
+-----------|--------------+
            v
+--------------------------+
| Services                 |
|  DayService              |
|  TaskService             |
|  ScheduleService         |
+-----------|--------------+
            v
+--------------------------+
| SwiftData ModelContext   |
|  Day | TaskItem |        |
|  ScheduleEntry           |
+--------------------------+
```

- **Services** are plain Swift classes initialised with a `ModelContext`. All business rules live here so tests can exercise them without the UI.
- **Views** call services through an `AppState` `@Observable` that exposes the current date and convenience accessors.
- **AppState** also triggers rollover on launch and on date change.

## Data model

```swift
@Model final class Day {
    @Attribute(.unique) var date: Date          // normalized to start-of-day
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.day)
        var items: [TaskItem]
    @Relationship(deleteRule: .cascade, inverse: \ScheduleEntry.day)
        var schedule: [ScheduleEntry]
    var top3ItemIDs: [UUID]                     // ordered, up to 3
}

@Model final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var day: Day?
}

@Model final class ScheduleEntry {
    @Attribute(.unique) var id: UUID
    var startHour: Int                           // 5...23
    var durationHours: Int                       // >= 1
    var isCompleted: Bool
    var item: TaskItem?
    var day: Day?
}
```

**Key derivations (not stored):**
- An item is **scheduled today** iff some `ScheduleEntry` on today's `Day` references it.
- An item is **completed today** iff it has at least one `ScheduleEntry` on its day with `isCompleted == true`.

**Invariants:**
- `Day.date` is always the start of a calendar day in the user's local time zone.
- `top3ItemIDs.count <= 3`. Entries reference `TaskItem.id`s that belong to the same `Day`.
- For all `ScheduleEntry e` on a given `Day`, the half-open ranges `[e.startHour, e.startHour + e.durationHours)` are pairwise disjoint.
- `startHour` in `5...23`; `startHour + durationHours <= 24`.

## UI layout

```
+-----------------------------------------------------------+
|  < Friday, May 22, 2026 >                       [ today ] |
+-----------------------------------------------------------+
|  BRAIN DUMP             |  TOP 3                          |
|  o Buy groceries        |  1. Write spec       [scheduled]|
|  o Write spec [scheduled]| 2. Call mom                    |
|  o Call mom             |  3. (empty)                     |
|  o Read paper           |                                 |
|  + Add item             |                                 |
+-------------------------+---------------------------------+
|  SCHEDULE                                                 |
|   5 AM  ____________________                              |
|   6 AM  ____________________                              |
|   ...                                                     |
|   9 AM  +-- Write spec ----------------- [ x ] [ check ] -+
|  10 AM  |  (continued)                                    |
|  11 AM  +-------------------------------------------------+
|  12 PM  ____________________                              |
|   ...                                                     |
|  11 PM  ____________________                              |
+-----------------------------------------------------------+
```

- Top half: brain dump on the left, top 3 on the right.
- Bottom half: schedule spanning the full width, 18 rows (5 AM – 11 PM), scrollable if the window is short.
- Scheduled-today items in brain dump and top 3 show a subtle tinted background; completed items also show strikethrough.
- Schedule blocks render as a single visual element spanning `durationHours` rows.
- A small "x" deletes the schedule entry (item stays in brain dump). A checkbox toggles completion.

### Date navigation

- Header shows the current day with prev/next arrows and a "today" button.
- Today's view is fully interactive.
- Days where `date < startOfToday` are rendered read-only: no add/edit/check, no drag targets, no delete buttons.
- Future days (`date > startOfToday`) are not selectable in the first pass.

## Interactions

### Add brain-dump item
Inline "+ Add item" field at the bottom of the brain-dump list. Submit creates a `TaskItem` on today's `Day` with `createdAt = now`.

### Escalate to Top 3
- Star button on each brain-dump row.
- Adds the item's id to `Day.top3ItemIDs` if there's room (`count < 3`). If full, the star action is disabled and a tooltip explains why.
- A second click on a top-3 item de-escalates (removes from `top3ItemIDs`).
- Top 3 entries can be reordered by drag within the Top 3 section.

### Schedule an item
1. User drags an item from Brain Dump or Top 3 onto a schedule slot at hour `h`.
2. A small sheet appears: `How many hours? [1] [2] [3] [4] [custom: __]`.
3. On confirm with duration `d`:
   - If `h + d > 24`, reject with an inline error.
   - If any existing entry on today's `Day` overlaps `[h, h+d)`, reject with an inline error.
   - Otherwise create a `ScheduleEntry { startHour: h, durationHours: d, item, day, isCompleted: false }`.
4. The source item stays where it was; its background reflects "scheduled today".

### Complete a scheduled block
Click the checkbox on the schedule block to flip `ScheduleEntry.isCompleted`. The corresponding item row in brain dump / top 3 redraws with strikethrough.

### Remove from schedule
Click the small "x" on the schedule block. The `ScheduleEntry` is deleted. The item remains in its brain-dump / top-3 source.

### Edit / delete brain-dump item
- Double-click an item to rename inline.
- A delete button on hover removes the item. Cascading: any schedule entries pointing at it are deleted too. Removed from `top3ItemIDs` if present.

### Rollover

Triggered by `AppState` on launch and whenever the observed "today" changes (e.g., the app sat open through midnight).

**Design intent:** past days should preserve a true record of what happened — *what completed*, *when*. So rollover only **moves uncompleted items forward**; everything else stays put.

Algorithm:

1. Compute `today = startOfToday()`.
2. Call `dayService.day(for: today)` so today exists.
3. Fetch all `Day` records where `date < today`.
4. For each such `Day d`:
   - For each `TaskItem t` in `d.items`:
     - **If `t` has at least one `ScheduleEntry` on `d` with `isCompleted == true`**: leave `t` on `d`. Its schedule entries (completed and not) stay too — they are the record.
     - **Else**: re-parent `t` to today (`t.day = today`). Delete any `ScheduleEntry` on `d` that references `t`. Remove `t.id` from `d.top3ItemIDs` if present.

That's it. We don't track a "rolled over" flag — the algorithm is naturally idempotent:

- Running it twice on the same day moves nothing the second time, because uncompleted items are no longer on past days.
- Multi-day gaps just mean more `Day d` records to iterate; same logic applies.

**Edge cases:**
- An old `Day` whose items all completed: stays as-is (a "perfect day" record).
- An old `Day` whose items all rolled forward: ends up with no items and no schedule entries. We keep it as a `Day` record but it'll render as an empty sheet in history. That's accurate — nothing was completed that day.
- An item that had a completed entry **and** an uncompleted entry on the same day (e.g., "write report" 9-10 completed, "write report" 14-15 not completed — same item scheduled twice): treated as completed for rollover purposes, stays on `d`. Both schedule entries remain.

## Service contracts

Each service is constructed with a `ModelContext`. All methods are synchronous.

```swift
final class DayService {
    init(context: ModelContext)
    func day(for date: Date) -> Day             // get-or-create, date normalized
    func rollover(now: Date)                    // idempotent
}

final class TaskService {
    init(context: ModelContext)
    func addBrainDumpItem(title: String, on day: Day) -> TaskItem
    func rename(_ item: TaskItem, to title: String)
    func delete(_ item: TaskItem)
    func escalate(_ item: TaskItem, on day: Day) throws
    func deescalate(_ item: TaskItem, on day: Day)
    func reorderTop3(on day: Day, ids: [UUID])
}

final class ScheduleService {
    init(context: ModelContext)
    func schedule(_ item: TaskItem, on day: Day, startHour: Int, durationHours: Int) throws -> ScheduleEntry
    func unschedule(_ entry: ScheduleEntry)
    func setCompleted(_ entry: ScheduleEntry, _ completed: Bool)
}
```

**Errors:**

```swift
enum TodoError: Error {
    case top3Full
    case scheduleConflict
    case scheduleOutOfRange
}
```

## Testing strategy

Tests use an in-memory `ModelContainer`:

```swift
func makeInMemoryContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Day.self, TaskItem.self, ScheduleEntry.self,
        configurations: config
    )
    return ModelContext(container)
}
```

### Coverage per service

**DayServiceTests**
- `day(for:)` returns the same `Day` for two calls with the same date.
- `day(for:)` normalizes any `Date` to start-of-day in the local time zone.
- `day(for:)` creates a new `Day` for a new date.
- `rollover` moves uncompleted items from yesterday to today's brain dump.
- `rollover` leaves completed items on the day they were completed (item, schedule entries, and top 3 reference all preserved).
- `rollover` deletes only the schedule entries that reference moved items; completed items' entries are kept.
- `rollover` removes only moved items' ids from yesterday's `top3ItemIDs`; ids of completed items stay.
- `rollover` is idempotent: running twice has the same effect as running once.
- `rollover` handles multi-day gaps (today opens after 3 days away). All uncompleted items from any past day land in today's brain dump.
- `rollover` leaves the "perfect day" case untouched (a `Day` whose items all completed has no fields modified).

**TaskServiceTests**
- Add appends to `Day.items`.
- Rename updates the title.
- Delete removes the item and cascades schedule entries.
- Delete removes the id from `top3ItemIDs` if present.
- Escalate appends to `top3ItemIDs`.
- Escalate throws `top3Full` when 3 items already escalated.
- De-escalate removes from `top3ItemIDs`.
- Reorder updates `top3ItemIDs`.

**ScheduleServiceTests**
- Schedule a 1-hour item creates an entry at that slot.
- Schedule a 3-hour item creates one entry that spans 3 slots conceptually (single record with `durationHours == 3`).
- Schedule throws `scheduleOutOfRange` for `startHour + durationHours > 24` or `startHour < 5`.
- Schedule throws `scheduleConflict` when overlapping an existing entry (boundary case: `[9, 10)` and `[10, 11)` do not conflict).
- Unschedule deletes the entry; item still exists.
- `setCompleted(true)` flips the flag; `setCompleted(false)` flips back.

## Project structure

```
todoosx/
  todoosx.xcodeproj
  todoosx/
    App/
      todoosxApp.swift
      AppState.swift
    Models/
      Day.swift
      TaskItem.swift
      ScheduleEntry.swift
      TodoError.swift
    Services/
      DayService.swift
      TaskService.swift
      ScheduleService.swift
    Views/
      AppShell.swift
      DayView.swift
      BrainDumpSection.swift
      Top3Section.swift
      ScheduleSection.swift
      ScheduleBlockView.swift
      DurationPromptSheet.swift
    Support/
      Date+StartOfDay.swift
  todoosxTests/
    DayServiceTests.swift
    TaskServiceTests.swift
    ScheduleServiceTests.swift
    TestSupport/InMemoryStore.swift
  docs/superpowers/specs/
    2026-05-22-todoosx-design.md
```

## Implementation order

Each step lands behind a passing test before the next begins; each step gets its own commit. UI work is exercised manually at the end.

1. **Scaffolding**: Xcode project, target, test target, in-memory store helper.
2. **Models**: `Day`, `TaskItem`, `ScheduleEntry`, `TodoError`.
3. **DayService — `day(for:)`** with normalization tests.
4. **TaskService — brain dump CRUD**.
5. **TaskService — top 3 escalate / de-escalate / reorder**.
6. **ScheduleService — schedule + conflict + range tests**.
7. **ScheduleService — unschedule + complete**.
8. **DayService — `rollover`** including idempotency and multi-day gap.
9. **AppState** wiring + launch-time rollover.
10. **Views**: AppShell + DayView shell with date navigation.
11. **Views**: BrainDumpSection with inline add/edit/delete.
12. **Views**: Top3Section with star toggle and reorder.
13. **Views**: ScheduleSection with drag drop and duration prompt.
14. **Visual polish**: tinted backgrounds for "scheduled today", strikethrough for completed, read-only past days.

## Open questions

None at design-spec time. Any new questions will be folded into the implementation plan.
