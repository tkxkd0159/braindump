# Stage 5 — Inline Task Details, Minute Scheduling, Sidebar Toggle

Date: 2026-05-22

## Goals

Five capabilities, agreed verbatim with the user:

1. Task cards reveal their contents in place (description, tags) instead of jumping to the edit modal on tap. An explicit edit button sits between the remove button and the complete check. The schedule section's two-icon header (download, ellipsis) is dropped; day-time-range customization moves to a Settings sheet reachable from the existing Settings sidebar item.
2. Tags render under task titles (chips, Reminders style). The "add new task" row gains optional description + tag inputs.
3. Scheduled blocks support any time range with 15-minute precision via a Reminders-style time picker (`DatePicker` w/ `.hourAndMinute`, 15-min step).
4. The window's minimum width is constrained so the schedule section can't be hidden by resizing.
5. A toggle button shows/hides the sidebar.

## Non-Goals

- Migration of existing local data. The store is wiped on first launch with the new schema (acceptable: app is a stage-by-stage prototype).
- Sub-15-minute precision.
- Per-day time-range overrides (the day window is app-wide).
- Persisting the sidebar-visible flag across launches (in-memory `AppState` only, like the rest of session UI state).

## Data Model

### `ScheduleEntry` (changed)

Replace the two integer hour fields with minute fields:

```swift
public var startMinute: Int = 0       // minutes since 00:00
public var durationMinutes: Int = 60
```

Other fields (`isCompleted`, `completedAt`, `colorIndex`, relationships) are unchanged.

### `TaskItem`

Unchanged. `notes` (`String`) and `tags` (`[String]`) already exist.

### `Day`

Unchanged.

### App settings

Two new values on `AppState`, persisted to `UserDefaults` via `@AppStorage`-style backing:

- `dayStartHour: Int` (default 5)
- `dayEndHour: Int` (default 22)

Invariants enforced when assigning: `0 ≤ dayStartHour`, `dayEndHour ≤ 24`, `dayEndHour - dayStartHour ≥ 4`.

A third UI flag lives in memory only:
- `isSidebarVisible: Bool` (default true)

## Service Surface

### `ScheduleService`

```swift
@discardableResult
func schedule(_ item: TaskItem, on day: Day,
              startMinute: Int, durationMinutes: Int,
              colorIndex: Int = 0) throws -> ScheduleEntry

func reschedule(_ entry: ScheduleEntry,
                startMinute: Int, durationMinutes: Int) throws
```

- Range guard: `durationMinutes ≥ 15`, `startMinute ≥ 0`, `startMinute + durationMinutes ≤ 24*60`. The grid bounds (`dayStartHour`/`dayEndHour`) are a presentation concern — the service uses absolute minute-of-day bounds so changing the day window doesn't invalidate stored entries.
- Conflict detection: half-open minute ranges, identical to the existing hour algorithm but at minute resolution.

`unschedule`, `setCompleted`, `setColorIndex` unchanged.

### `TaskService`

Add an overload that accepts description and tags up front:

```swift
@discardableResult
func addBrainDumpItem(title: String, notes: String = "",
                      tags: [String] = [], on day: Day) -> TaskItem
```

`updateTags`/`updateNotes` already exist and are reused for in-place edits.

## Views

### `BrainDumpSection` / `Top3Section`

**Row layout** (collapsed):

```
[ ☐ ]  Title text
       #tag1  #tag2          [X] [✎] [↑ or ↓ or nothing] [✓ implicit via ☐]
```

- The leading checkbox stays where it is (it's both the visual completion state and the toggle for scheduled items).
- Trailing actions on hover, left → right:
  - Brain dump: `xmark` (delete) → `pencil` (edit) → `arrow.up.to.line` (promote).
  - Top 3: `xmark` (delete) is NOT shown today; this stays — `pencil` (edit) → `arrow.down.to.line` (demote).
- Tap on card body toggles an `isExpanded` flag (per-row local `@State`). When expanded:
  - Show `notes` text (`bodyMd`, with line wrap) below the title.
  - Tags continue to show.
  - Visual cue: subtle background tint to indicate expansion.
- Edit button opens the existing `TaskDetailSheet` via the `openDetail` callback.

**Tag chips** (new shared helper): small pill (`surfaceContainerHigh` bg, `bodyMd` 11pt, `onSurfaceVariant`) with `#` prefix. Reuses `FlowLayout` from `TaskDetailSheet`. Promote `FlowLayout` to its own file.

**Add row** in `BrainDumpSection`:
- Title `TextField` always visible.
- When `addFieldFocused == true` OR there's draft text in any field, reveal:
  - `TextField("Description (optional)")` — single line.
  - `TextField("Tags (comma or return separated)")` — chips render above as the user types.
- Pressing Return on the title commits the full record. Pressing Return inside the tag field adds the current draft to a `[String]` and commits-on-title.

### `ScheduleSection`

- Header: drop the `square.and.arrow.down` and `ellipsis` buttons. Just "SCHEDULE" + optional error text.
- `startHour` and `endHour` are no longer static; they come from `AppState`. The hour-row loop, label rendering, and drop-target math all reference the current bounds.
- Block positioning becomes fractional:
  - offset in pixels from grid top = `(entry.startMinute - dayStartHour*60) / 60.0 * hourHeight`
  - height = `entry.durationMinutes / 60.0 * hourHeight`
- Drop on a half-hour slot defaults the block's start to that half-hour but opens the time-block sheet so the user can fine-tune both ends to any 15-min increment.
- "Plan activity inline" (`onSubmit`) still creates a 1-hour block at the slot's hour boundary.

### `TimeBlockSheet` (renames `DurationPromptSheet`)

- Two `DatePicker`s, both `.hourAndMinute` `compact`, snapped to 15 minutes via a custom value transformer (`Date → snap to nearest 15-min`).
- Start picker default = drop target time. End picker default = start + 1 hour.
- Color swatch row preserved.
- Confirm produces `(startMinute, durationMinutes, colorIndex)`.

### `TaskDetailSheet`

- Schedule editor: replace the two `Stepper`s with the same start/end pickers from `TimeBlockSheet`. Validation: end > start.
- Otherwise unchanged.

### Settings

- Wire the existing Settings sidebar item to present a sheet (no destination change — clicking opens modal via local `@State`).
- `SettingsSheet`: two hour `Picker`s ("Day starts at", "Day ends at"), with the existing AM/PM formatter. "Done" persists to `AppState`. Validation messaging if span < 4h.

### `AppShell`

- Hide the sidebar entirely when `!state.isSidebarVisible`.
- Sidebar toggle button: 28×28 ghost button containing `sidebar.left` SF symbol, placed at the top-left of the `MainCanvas`, just above `DateHeader`.

### Window resizability

- App-side `.frame(minWidth:, minHeight:)` computed from the current `isSidebarVisible`:
  - sidebar visible → 1248
  - sidebar hidden → 992
- `.windowResizability(.contentSize)` (already configured) propagates this to the window.

## Testing Strategy

### Unit (Swift Testing)

- `ScheduleServiceTests` rewritten to the minute API:
  - `scheduleSingleBlockCreatesEntry`
  - `scheduleRejectsBeforeMidnight` (negative start)
  - `scheduleRejectsAfterMidnight` (end > 1440)
  - `scheduleRejectsSubFifteenDuration`
  - `scheduleRejectsOverlap` — minute granularity (9:15-10:30 vs 10:15-11:00)
  - `scheduleAllowsAdjacentBlocks` — 9:00-10:00 then 10:00-11:00
  - `rescheduleMovesBlock`, `rescheduleRejectsOverlap`, `rescheduleAllowsKeepingOwnRange`, `rescheduleRejectsOutOfRange`
- `TaskServiceTests` add `addBrainDumpItem(title:notes:tags:on:)`.
- `AppStateTests` add coverage for day-bounds setters and validation.

### Manual / screenshot

- Default day view (sidebar shown), with a scheduled 9:15-10:30 block.
- Same day with the sidebar hidden via the new toggle.
- Settings sheet open, showing the two hour pickers.
- A brain-dump row expanded inline, showing description + tags.
- The add row expanded, with description + tags drafted.
- Window resized to the new minimum — schedule section still visible.

## Risk and tradeoffs

- **Renaming `startHour → startMinute`** is a breaking schema change. Mitigated by wiping local data (intentional).
- **Fractional schedule block positioning** introduces sub-pixel rounding; we cap to integer pixels and rely on overlay borders.
- **Persisting `dayStartHour`/`dayEndHour` to UserDefaults** rather than per-Day means historical days re-render under the current window. Acceptable because past days are read-only and the schedule grid is a presentation envelope, not data.
