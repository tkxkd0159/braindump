# Day View — Modal Refactor, MUI-style TimeRangePicker, Context Menus, Drag Freeze Fix

Date: 2026-05-23

## Goals

Five capabilities, agreed verbatim with the user:

1. Reimplement the time-block picker as a dual digital-clock TimeRangePicker (MUI X MultiInput style). Two scroll-snap columns at 15-minute steps, side-by-side, with a duration readout.
2. The TaskDetail edit modal becomes the canonical place to assign a brain-dump task to the schedule — not only drag-and-drop. The modal exposes an "Add to Schedule" toggle that reveals the new TimeRangePicker + color row when the task has no entry.
3. The "+" button in the Brain Dump section opens the same modal in **create mode** instead of focusing the inline add row. The inline add row stays for quick capture; the modal is the long-list-friendly entry point. (Single modal, two entry points.)
4. Secondary-click context menus: brain-dump rows show "Move to Priority"; Top3 rows show "Move to Brain Dump". Both wire to the existing escalate/deescalate service methods.
5. A press-and-release on a draggable row with **zero cursor movement** must not mutate any state and must not trigger a SwiftData save. Today, pressing-and-releasing a Top3 item fires the slot's drop destination, which calls `moveToTop3Slot(item, at: sameIndex)` → `swapAt(i, i)` → `day.top3ItemIDs = ids` → `context.save()`. The save churns SwiftUI, the relationship array re-orders, the screen freezes for a moment, and the brain-dump list appears reshuffled.

## Non-Goals

- Re-doing drag-and-drop semantics. Drag is still the primary scheduling path; the modal is additive.
- A clock-face picker. Dual scroll columns only.
- Touch / iOS adaptation. macOS 14+ only, as today.
- Persisting "Add to Schedule" toggle state across modal opens.
- Right-click on scheduled blocks. (Not in scope.)
- Visual redesign of context menus beyond the platform default.

## Architecture

The work touches three layers:

- **New view:** `TimeRangePicker` (presentational, no service access).
- **Refactored view:** `TaskDetailSheet` gains a create mode and an optional schedule sub-section gated by a toggle. `TaskDetailFocus` becomes a small enum.
- **Service:** `TaskService.moveToTop3Slot` short-circuits when the resulting ID array is unchanged. No other service signatures change.
- **Drop-handler tightening:** `Top3SlotRow.handleDrop` and `DemoteDropZone.handleDrop` early-return when nothing changes; `DemoteDropZone` additionally requires that `isDropTargeted` was *actively true* at drop time (the cursor entered the section).

## Service Surface

### `TaskService.moveToTop3Slot` — no-op short-circuit

```swift
public func moveToTop3Slot(_ item: TaskItem, at targetIndex: Int, on day: Day) {
    var ids = day.top3ItemIDs
    let original = ids
    // ...existing branching logic unchanged...
    if ids == original { return }      // <-- new
    day.top3ItemIDs = ids
    try? context.save()
}
```

This is the load-bearing fix for feature #5. Even if a future drop accidentally re-fires, no save happens unless the array actually changed.

`reorderTop3` already short-circuits on `Set` equality; no change needed there.

No other service method changes.

## New View: `TimeRangePicker`

`Sources/BrainDumpKit/Views/TimeRangePicker.swift`

```swift
public struct TimeRangePicker: View {
    @Binding var startMinute: Int
    @Binding var endMinute: Int
    let dayStartHour: Int
    let dayEndHour: Int
    let step: Int           // 15

    public var body: some View { ... }
}
```

### Layout

```
┌─ STARTS ─────────┐    ┌─ ENDS ───────────┐
│  08:30           │    │  09:30           │
│  08:45           │    │  09:45           │
│ ▶09:00◀  ←───────┼────┤▶10:00◀           │
│  09:15           │    │  10:15           │
│  09:30           │    │  10:30           │
└──────────────────┘    └──────────────────┘
         Duration: 1h 0m
```

- Each column is a `ScrollView` containing a `LazyVStack` of selectable time rows at 15-minute increments. Rows are 32 pt tall; column shows 5 rows (~160 pt) with the selected row centered.
- The selected row is highlighted (filled background, primary text). Adjacent rows fade out via opacity.
- Selection is driven by `scrollPosition(id:)` bound to the column's current minute. `scrollTargetBehavior(.viewAligned)` provides snap.
- Tap on a non-selected row scrolls (animated) to make it the selected row.
- Bounds: each column's contents span from `dayStartHour * 60` to `dayEndHour * 60 + step` (inclusive). The end column does **not** include rows ≤ current start (filtered).
- When the user moves `start` past `end`, `end` is bumped to `start + step` (preserving the invariant `end > start ≥ 15min`). When the user moves `end` ≤ `start`, `start` is bumped down accordingly.
- Duration readout below the columns: `"Duration: 1h 0m"`. Live-updates as either column scrolls.
- 15-minute minimum enforced via the bumping rule above; the parent sheet still validates on commit.

### Why a scroll-snap list instead of a wheel

`.datePickerStyle(.wheel)` on macOS is an iOS-style spinner that doesn't match the Neo-Academic aesthetic and doesn't expose enough hooks to render time options custom. A scroll list of plain SwiftUI rows gives us snap, custom typography, and consistent borders with the rest of the design system.

### Reuse

`TimeRangePicker` replaces the two `DatePicker(.field)` instances in **both** call sites:
- `TimeBlockSheet` (drag-to-schedule flow)
- `TaskDetailSheet.scheduleEditor` (edit mode for a task that already has an entry, *and* the new create/assign flow from feature #2)

Both call sites continue to own a `colorIndex` and a `ColorSwatchRow` below the picker.

## Refactored View: `TaskDetailSheet`

### Focus enum

Replace the struct with:

```swift
public enum TaskDetailFocus: Identifiable {
    case create(day: Day)
    case edit(item: TaskItem, entry: ScheduleEntry?, startInEditMode: Bool)

    public var id: UUID { ... }   // stable per opened sheet
}
```

`DayView` and any other caller switches on the case. `TaskDetailFocus(item:entry:startInEditMode:)` keeps a compatibility convenience initializer that returns `.edit(...)` so existing call sites don't need to change shape.

### Modal modes

```
┌──────────────────────────────────────┐
│  TASK                                │
│  ┌────────────────────────────────┐  │
│  │ Title…                         │  │
│  └────────────────────────────────┘  │
│  Description…                        │
│  Tags…                               │
│                                      │
│  ▢ Add to Schedule                   │
│  (when toggled on, the time picker   │
│   and color row appear below)        │
│                                      │
│  [Cancel]                  [Save]    │
└──────────────────────────────────────┘
```

State on the sheet:
- `mode: Mode` derived from focus: `.create | .edit`
- `title`, `notes`, `tags` — same as today
- `scheduleEnabled: Bool` — controls visibility of the time/color sub-section
- `startMinute`, `endMinute`, `colorIndex` — initialized from entry if present, else from defaults

Toggle behavior:
- **Create mode (`focus == .create`)**: toggle defaults to `false`. Task is saved as brain dump only by default. Flipping it on reveals the TimeRangePicker with defaults `start = nextFreeHour(day)`, `end = start + 60`.
- **Edit mode + entry present**: toggle is hidden; the time sub-section is always shown (parity with today's behavior). Removing the schedule is not a goal of this modal — there's already an "x" affordance on the schedule block itself.
- **Edit mode + no entry**: toggle defaults to `false`. Flipping on lets the user schedule an existing brain-dump task from the modal (feature #2).

Commit path:
- Compute the diff: title/notes/tags changed → call existing `TaskService` methods.
- If `mode == .create`, call `TaskService.addBrainDumpItem(...)` first to get the new `TaskItem`.
- If `scheduleEnabled`:
  - Edit mode with existing entry: `scheduleService.reschedule(entry, ...)` + `setColorIndex` if changed.
  - Otherwise: `scheduleService.schedule(item, on: day, startMinute, durationMinutes, colorIndex)`.
- On `TodoError.scheduleConflict` / `.scheduleOutOfRange`: render inline error, do not dismiss.

### Default start time helper

```swift
private static func nextFreeHour(in day: Day, dayStartHour: Int, dayEndHour: Int) -> Int
```

Returns the start of the next 30-min slot that doesn't overlap any existing entry, clamped to `[dayStartHour*60, (dayEndHour-1)*60]`. Falls back to `dayStartHour * 60` if nothing fits.

## BrainDumpSection — feature #3 wiring

- The "+" button in the section header now sets a `@State var presentingCreate: Bool` instead of `addFocus = .title`. The view binds `.sheet(item: ...)` to a focus value built lazily on press.
- The inline add row stays exactly as it is today.
- New keyboard shortcut on the "+" button: `Cmd+N` while the day view has focus (nice-to-have; only add if it doesn't require structural rework).

## Context Menus — feature #4

### Brain Dump row

```swift
.contextMenu {
    if !isReadOnly {
        Button("Move to Priority") {
            do { try taskService.escalate(item, on: day) }
            catch TodoError.top3Full {
                escalateError = "Top 3 is full"
            } catch { }
        }
    }
}
```

`escalateError` is a transient `@State String?` cleared after 2 seconds via a `Task` (or shown as a small toast under the header — picking the simpler inline-under-header approach to match the schedule section's `errorText` pattern).

### Top3 row

```swift
.contextMenu {
    if !isReadOnly, let item {
        Button("Move to Brain Dump") {
            taskService.deescalate(item, on: day)
        }
    }
}
```

The context menu lives on `Top3SlotRow.filledRow`. Empty slots don't get a menu.

## Drop-handler tightening — feature #5

### `Top3SlotRow.handleDrop`

```swift
private func handleDrop(payloads: [TaskItemDragPayload]) -> Bool {
    guard !isReadOnly, let payload = payloads.first else { return false }
    guard let item = day.items.first(where: { $0.id == payload.id }) else { return false }
    // no-op short-circuit at the view level
    if let oldIndex = day.top3ItemIDs.firstIndex(of: item.id), oldIndex == index {
        return false
    }
    taskService.moveToTop3Slot(item, at: index, on: day)
    return true
}
```

### `DemoteDropZone.handleDrop` — require active targeting

```swift
@State private var isDropTargeted: Bool = false
@State private var wasTargeted: Bool = false   // becomes true at least once before drop

// in body:
.dropDestination(...) { payloads, _ in
    guard wasTargeted else { return false }    // cursor never entered
    defer { wasTargeted = false }
    return handleDrop(payloads: payloads)
} isTargeted: { targeted in
    isDropTargeted = targeted && !isReadOnly && !day.top3ItemIDs.isEmpty
    if isDropTargeted { wasTargeted = true }
}
```

This makes the demote drop ignore "press-and-release on top of source" entirely, because in that case `isTargeted` may flicker `true→false` synthetically *only* when the section overlaps the source row's hit area. Empirically, when the user holds a Top3 item and releases without movement, the cursor is inside the Top3SlotRow — not the BrainDumpSection — so `wasTargeted` never flips true, and the drop is ignored even if the runtime forwards it.

For Top3SlotRow, the index-equality check above is sufficient; the slot is always "targeted" from its own perspective when you drop on yourself, but no save happens because the IDs don't change.

### Schedule slot

`ScheduleSlot` doesn't have a source `.draggable`, so the press-and-release-on-source case doesn't apply. No change needed.

## Tests

Test file conventions per project CLAUDE.md: Swift Testing, one file per service / concept, `TestSupport/InMemoryStore` + `TestDate`.

### New / extended tests

- `TaskServiceTests`: add a regression test `moveToTop3Slot_atSameIndex_isNoOp` — start with `top3ItemIDs = [A, B, C]`, call `moveToTop3Slot(A, at: 0, on: day)`, assert the array is unchanged AND `context.hasChanges == false` (or, since save is unconditional in some paths, snapshot `day.top3ItemIDs` and verify identity-equal contents and order).
- `Top3SlotRowTests`: extend the existing snapshot test to cover the context menu rendering. (Context menus aren't easily snapshot-able; instead, exercise the underlying service call directly — a behavioral test rather than a snapshot.)
- `BrainDumpSectionTests` (new): snapshot the create-modal flow via the underlying state (open sheet → sheet builds a `.create(day:)` focus → not a snapshot of the modal but a smoke test that the "+" button toggles the sheet flag).
- `TimeRangePickerTests` (new): a small snapshot test pinning the two-column rendering at a known size, plus behavior tests: setting `start` past `end` bumps `end`; selecting a row updates the binding to the rounded 15-min value.
- `TaskDetailSheetTests` (new): two snapshots — create mode with toggle off, edit mode with existing entry showing the new TimeRangePicker. Behavior test: toggling "Add to Schedule" on in create mode and saving results in both `addBrainDumpItem` and `schedule` being called (assert by inspecting model state after save).

### Existing tests we must not break

- `Top3SlotRowTests` — snapshot dimensions unchanged.
- `captureLeftColumn` snapshot referenced in the previous commit (`c9f6310`) — unchanged.
- `BacklogScreen`, `TasksScreen` — unrelated.

## Out-of-scope drift to flag

The previous commit (`c9f6310`) localized drop-zone state to fix a related freeze on escalate. This spec deliberately *does not* re-architect that work; it tightens the remaining no-op path. If, while implementing #5, we discover that the freeze has a deeper cause (e.g., SwiftData relationship invalidation on any save), we will stop and re-brainstorm rather than expand scope.

## Open questions

None. The user has answered:
- TimeRangePicker style → dual digital clocks.
- Schedule UX in edit modal → toggle.
- Inline add row → keep alongside modal.
