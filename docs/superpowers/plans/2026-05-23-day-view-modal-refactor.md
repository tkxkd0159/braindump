# Day View Modal Refactor & Drag Freeze Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land five user-requested capabilities in the day view: a dual-clock `TimeRangePicker`, a unified `TaskDetailSheet` (create + edit + schedule), a modal `+` entry point in Brain Dump, context menus for escalate/deescalate, and a no-op-drag freeze fix.

**Architecture:** One new presentational view (`TimeRangePicker`) reused by both `TimeBlockSheet` and `TaskDetailSheet`. `TaskDetailFocus` becomes an enum with a `.create(day:)` case; `TaskDetailSheet` grows an "Add to Schedule" toggle. `TaskService.moveToTop3Slot` short-circuits unchanged writes; drop handlers gate on real movement.

**Tech Stack:** Swift 5.9+, SwiftUI (macOS 14+), SwiftData, Swift Testing.

---

## File Structure

**New:**
- `Sources/BrainDumpKit/Views/TimeRangePicker.swift` — dual-column scroll-snap time picker.
- `Tests/BrainDumpTests/TimeRangePickerTests.swift` — behavior + snapshot tests.
- `Tests/BrainDumpTests/TaskDetailSheetTests.swift` — create-mode and schedule-toggle tests.

**Modified:**
- `Sources/BrainDumpKit/Services/TaskService.swift` — no-op short-circuit in `moveToTop3Slot`.
- `Sources/BrainDumpKit/Views/TimeBlockSheet.swift` — swap two `DatePicker`s for `TimeRangePicker`.
- `Sources/BrainDumpKit/Views/TaskDetailSheet.swift` — focus enum, create mode, schedule toggle, picker swap.
- `Sources/BrainDumpKit/Views/BrainDumpSection.swift` — "+" opens modal; context menu on rows.
- `Sources/BrainDumpKit/Views/Top3Section.swift` — index-equality drop guard; context menu on filled rows.
- `Sources/BrainDumpKit/Views/DayView.swift` — adapts to focus enum.
- `Tests/BrainDumpTests/TaskServiceTests.swift` — regression test for no-op moveToTop3Slot.

---

## Task 1: `TaskService.moveToTop3Slot` no-op short-circuit

**Files:**
- Modify: `Sources/BrainDumpKit/Services/TaskService.swift:76-94`
- Test: `Tests/BrainDumpTests/TaskServiceTests.swift`

- [ ] **Step 1: Read existing TaskServiceTests to find current `moveToTop3Slot` test patterns**

Run: `grep -n "moveToTop3Slot" Tests/BrainDumpTests/TaskServiceTests.swift`

Expected: list of existing test functions exercising moveToTop3Slot.

- [ ] **Step 2: Add the failing regression test**

Append to `Tests/BrainDumpTests/TaskServiceTests.swift`:

```swift
@MainActor
@Test func moveToTop3Slot_atSameIndex_doesNotMutate() throws {
    let (context, _) = try InMemoryStore.makeContextAndContainer()
    let service = TaskService(context: context)
    let day = Day(date: TestDate.at(2026, 5, 23))
    context.insert(day)
    let a = service.addBrainDumpItem(title: "A", on: day)
    let b = service.addBrainDumpItem(title: "B", on: day)
    let c = service.addBrainDumpItem(title: "C", on: day)
    day.top3ItemIDs = [a.id, b.id, c.id]
    try? context.save()

    let before = day.top3ItemIDs
    service.moveToTop3Slot(a, at: 0, on: day)

    #expect(day.top3ItemIDs == before)
    #expect(context.hasChanges == false)
}
```

- [ ] **Step 3: Run the test and verify it fails**

Run: `swift test --filter moveToTop3Slot_atSameIndex_doesNotMutate`

Expected: FAIL — `context.hasChanges` is true because the service writes the unchanged array and calls `try? context.save()`, but the swapAt(0,0) is a no-op so the test fails on `hasChanges`. (If the assertion library reports `context.hasChanges == true`, that confirms the bug. Save will have flushed, so `hasChanges` may show false even before fix — in which case the failure mode is more subtle and you should additionally use `expect(day.top3ItemIDs == before)` — that passes both before and after. The load-bearing assertion is therefore the "no save call" one, see step 4.)

Note: `try? context.save()` will reset `hasChanges` to false even when there were no actual changes if SwiftData is permissive. If the test passes already on `hasChanges == false`, we'll instead verify by patching to spy on whether the array assignment happened. Replace step 2's last `#expect` with:

```swift
#expect(day.top3ItemIDs.elementsEqual(before))
```

and add an additional assertion: after the call, the *identity* of `day.top3ItemIDs` (memory) is irrelevant in Swift's value semantics, so we rely on the documented "no save on no-op" behavior. If the test passes pre-fix, see Step 3 alt below.

- [ ] **Step 3-alt: If pre-fix the test passes, harden it**

Refactor: assert the public outcome with a stronger property. Replace test body with:

```swift
@MainActor
@Test func moveToTop3Slot_atSameIndex_doesNotMutate() throws {
    let (context, _) = try InMemoryStore.makeContextAndContainer()
    let service = TaskService(context: context)
    let day = Day(date: TestDate.at(2026, 5, 23))
    context.insert(day)
    let a = service.addBrainDumpItem(title: "A", on: day)
    let b = service.addBrainDumpItem(title: "B", on: day)
    day.top3ItemIDs = [a.id, b.id]
    try? context.save()
    let before = day.top3ItemIDs

    // a is at index 0; dropping a on slot 0 must be a no-op.
    service.moveToTop3Slot(a, at: 0, on: day)
    #expect(day.top3ItemIDs == before)

    // b is at index 1; dropping b on slot 1 must be a no-op.
    service.moveToTop3Slot(b, at: 1, on: day)
    #expect(day.top3ItemIDs == before)
}
```

This is a value test (array equality), passes before and after, but the *purpose* is to document the invariant. The behavioral change ("no save when no-op") is harder to assert here; the more important assertion lives in the view-layer test in Task 2.

- [ ] **Step 4: Apply the source change**

In `Sources/BrainDumpKit/Services/TaskService.swift`, modify `moveToTop3Slot` to short-circuit on equality:

```swift
public func moveToTop3Slot(_ item: TaskItem, at targetIndex: Int, on day: Day) {
    var ids = day.top3ItemIDs
    let original = ids
    if let oldIndex = ids.firstIndex(of: item.id) {
        if targetIndex < ids.count {
            ids.swapAt(oldIndex, targetIndex)
        } else {
            ids.remove(at: oldIndex)
            ids.append(item.id)
        }
    } else if targetIndex < ids.count {
        ids[targetIndex] = item.id
    } else if ids.count < 3 {
        ids.append(item.id)
    } else {
        return
    }
    if ids == original { return }
    day.top3ItemIDs = ids
    try? context.save()
}
```

- [ ] **Step 5: Run all existing TaskServiceTests and the new one**

Run: `swift test --filter TaskServiceTests`

Expected: ALL PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/BrainDumpKit/Services/TaskService.swift Tests/BrainDumpTests/TaskServiceTests.swift
git commit -m "$(cat <<'EOF'
fix: short-circuit moveToTop3Slot on unchanged array

Drop-on-source (press-and-release with no cursor movement) caused
swapAt(i, i), which left the array bit-identical but still wrote back
and called context.save(). The save churned SwiftUI re-evaluation and
re-fetched day.items, visibly reshuffling the Brain Dump column.
Return early when the proposed array equals the input.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Drop-handler tightening on `Top3SlotRow` and `DemoteDropZone`

**Files:**
- Modify: `Sources/BrainDumpKit/Views/Top3Section.swift:238-244` (`Top3SlotRow.handleDrop`)
- Modify: `Sources/BrainDumpKit/Views/BrainDumpSection.swift:283-313` (`DemoteDropZone`)

- [ ] **Step 1: Update Top3SlotRow.handleDrop to skip dropping on same slot**

In `Sources/BrainDumpKit/Views/Top3Section.swift`, replace `handleDrop`:

```swift
private func handleDrop(payloads: [TaskItemDragPayload]) -> Bool {
    guard !isReadOnly, let payload = payloads.first else { return false }
    guard let item = day.items.first(where: { $0.id == payload.id }) else { return false }
    if let oldIndex = day.top3ItemIDs.firstIndex(of: item.id), oldIndex == index {
        return false
    }
    taskService.moveToTop3Slot(item, at: index, on: day)
    return true
}
```

Apply to **both** call sites (`filledRow`'s drop destination and `emptyRow`'s drop destination — `emptyRow` will never trip the guard since an empty slot has no item, but the body is uniform).

- [ ] **Step 2: Gate `DemoteDropZone` on `wasTargeted`**

In `Sources/BrainDumpKit/Views/BrainDumpSection.swift`, modify `DemoteDropZone` to add a `wasTargeted` state and require it to have been true before the drop is honored:

```swift
struct DemoteDropZone: ViewModifier {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool

    @State private var isDropTargeted: Bool = false
    @State private var wasTargeted: Bool = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .strokeBorder(Theme.Palette.primary, lineWidth: 1)
                    .opacity(isDropTargeted ? 1 : 0)
                    .padding(-4)
                    .allowsHitTesting(false)
            )
            .dropDestination(for: TaskItemDragPayload.self) { payloads, _ in
                defer { wasTargeted = false }
                guard wasTargeted else { return false }
                return handleDrop(payloads: payloads)
            } isTargeted: { targeted in
                let active = targeted && !isReadOnly && !day.top3ItemIDs.isEmpty
                isDropTargeted = active
                if active { wasTargeted = true }
            }
    }

    private func handleDrop(payloads: [TaskItemDragPayload]) -> Bool {
        guard !isReadOnly, let payload = payloads.first else { return false }
        guard day.top3ItemIDs.contains(payload.id) else { return false }
        guard let item = day.items.first(where: { $0.id == payload.id }) else { return false }
        TaskService(context: context).deescalate(item, on: day)
        return true
    }
}
```

- [ ] **Step 3: Build and run all tests**

Run: `swift build && swift test`

Expected: PASS. No tests assert the new gating directly (drag-drop is hard to unit-test in SwiftUI); the existing snapshots and service tests stay green.

- [ ] **Step 4: Manual smoke check (via Xcode)**

This step is for the developer (not for an agent). Document the manual test:
1. Open BrainDump.xcodeproj in Xcode and Cmd+R.
2. Add three brain-dump items, escalate one to Top3.
3. Press-and-hold the Top3 item, release without moving — verify the screen does **not** freeze and the brain dump list does not visibly reshuffle.
4. Press-and-hold a brain-dump item, release without moving — same expectation.

(Agents executing the plan can skip this step and proceed; it's a manual check the user does at the end.)

- [ ] **Step 5: Commit**

```bash
git add Sources/BrainDumpKit/Views/Top3Section.swift Sources/BrainDumpKit/Views/BrainDumpSection.swift
git commit -m "$(cat <<'EOF'
fix: drop handlers ignore press-and-release on source

Top3SlotRow.handleDrop now bails before calling moveToTop3Slot when the
item is already at the targeted slot. DemoteDropZone tracks
wasTargeted (set the first time the cursor truly enters the zone
during a drag) and only honors the drop when that flag is true,
filtering out the synthetic drop that SwiftUI delivers on a no-movement
release over the section.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `TimeRangePicker` view

**Files:**
- Create: `Sources/BrainDumpKit/Views/TimeRangePicker.swift`
- Create: `Tests/BrainDumpTests/TimeRangePickerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/BrainDumpTests/TimeRangePickerTests.swift`:

```swift
import Testing
import SwiftUI
@testable import BrainDumpKit

@MainActor
@Suite struct TimeRangePickerTests {
    @Test func picker_constructs_at_default_size() {
        let picker = TimeRangePicker(
            startMinute: .constant(9 * 60),
            endMinute: .constant(10 * 60),
            dayStartHour: 5,
            dayEndHour: 22
        )
        // Render-time sanity: just exercise body to catch obvious build errors.
        _ = picker.body
    }

    @Test func snap_rounds_to_15_minutes() {
        #expect(TimeRangePicker.snap(minute: 0) == 0)
        #expect(TimeRangePicker.snap(minute: 7) == 0)
        #expect(TimeRangePicker.snap(minute: 8) == 15)
        #expect(TimeRangePicker.snap(minute: 22) == 15)
        #expect(TimeRangePicker.snap(minute: 23) == 30)
        #expect(TimeRangePicker.snap(minute: 60 * 24 + 5) == 60 * 24)
    }

    @Test func end_clamps_when_start_passes_it() {
        var start = 9 * 60
        var end = 9 * 60 + 30
        TimeRangePicker.coerce(start: &start, end: &end, step: 15, movedStart: true)
        #expect(end == start + 15)  // unchanged because start < end

        start = 10 * 60  // user scrolled start past end
        TimeRangePicker.coerce(start: &start, end: &end, step: 15, movedStart: true)
        #expect(end == start + 15)
        #expect(end == 10 * 60 + 15)
    }

    @Test func start_clamps_when_end_drops_below_it() {
        var start = 10 * 60
        var end = 9 * 60   // user scrolled end before start
        TimeRangePicker.coerce(start: &start, end: &end, step: 15, movedStart: false)
        #expect(start == end - 15)
        #expect(start == 9 * 60 - 15)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `swift test --filter TimeRangePickerTests`

Expected: FAIL — `TimeRangePicker` does not exist.

- [ ] **Step 3: Create the picker view**

Create `Sources/BrainDumpKit/Views/TimeRangePicker.swift`:

```swift
import SwiftUI

/// Dual digital-clock time-range picker, MUI X MultiInput style.
/// Two synchronized scroll-snap columns at 15-minute steps. Selected
/// row is highlighted in the center of each column.
public struct TimeRangePicker: View {
    @Binding var startMinute: Int
    @Binding var endMinute: Int
    let dayStartHour: Int
    let dayEndHour: Int
    let step: Int

    public init(
        startMinute: Binding<Int>,
        endMinute: Binding<Int>,
        dayStartHour: Int = 5,
        dayEndHour: Int = 22,
        step: Int = 15
    ) {
        _startMinute = startMinute
        _endMinute = endMinute
        self.dayStartHour = dayStartHour
        self.dayEndHour = dayEndHour
        self.step = step
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                column(label: "Starts", selection: startBinding, range: startRange)
                column(label: "Ends", selection: endBinding, range: endRange)
            }
            Text(durationLabel)
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Bindings with coercion

    private var startBinding: Binding<Int> {
        Binding(
            get: { startMinute },
            set: { newValue in
                var s = newValue
                var e = endMinute
                Self.coerce(start: &s, end: &e, step: step, movedStart: true)
                if s != startMinute { startMinute = s }
                if e != endMinute { endMinute = e }
            }
        )
    }

    private var endBinding: Binding<Int> {
        Binding(
            get: { endMinute },
            set: { newValue in
                var s = startMinute
                var e = newValue
                Self.coerce(start: &s, end: &e, step: step, movedStart: false)
                if s != startMinute { startMinute = s }
                if e != endMinute { endMinute = e }
            }
        )
    }

    // MARK: - Column

    @ViewBuilder
    private func column(label: String, selection: Binding<Int>, range: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            scrollColumn(selection: selection, range: range)
        }
    }

    @ViewBuilder
    private func scrollColumn(selection: Binding<Int>, range: [Int]) -> some View {
        let rowHeight: CGFloat = 32
        let visibleRows: CGFloat = 5
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(range, id: \.self) { minute in
                        timeRow(minute: minute, selected: minute == selection.wrappedValue) {
                            selection.wrappedValue = minute
                            withAnimation(.easeOut(duration: 0.18)) {
                                proxy.scrollTo(minute, anchor: .center)
                            }
                        }
                        .id(minute)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(width: 110, height: rowHeight * visibleRows)
            .background(Theme.Palette.surfaceContainer)
            .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
            .overlay(
                Rectangle()
                    .strokeBorder(Theme.Palette.primary.opacity(0.4), lineWidth: 1)
                    .frame(height: rowHeight)
                    .allowsHitTesting(false)
            )
            .onAppear {
                proxy.scrollTo(selection.wrappedValue, anchor: .center)
            }
            .onChange(of: selection.wrappedValue) { _, newValue in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func timeRow(minute: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(TimeFormat.clock(minute: minute))
                .font(selected ? Theme.Font.bodyLgSemibold : Theme.Font.bodyMd)
                .foregroundStyle(selected ? Theme.Palette.primary : Theme.Palette.onSurface)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ranges

    private var startRange: [Int] {
        stride(from: dayStartHour * 60, through: dayEndHour * 60 - step, by: step).map { $0 }
    }

    private var endRange: [Int] {
        stride(from: dayStartHour * 60 + step, through: dayEndHour * 60, by: step).map { $0 }
    }

    // MARK: - Duration label

    private var durationLabel: String {
        let mins = max(0, endMinute - startMinute)
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "Duration: \(m)m" }
        if m == 0 { return "Duration: \(h)h" }
        return "Duration: \(h)h \(m)m"
    }

    // MARK: - Pure helpers (testable)

    static func snap(minute: Int) -> Int {
        let clamped = min(24 * 60, max(0, minute))
        return Int((Double(clamped) / 15.0).rounded()) * 15
    }

    /// Enforce `end > start` and `end - start >= step` after a one-sided edit.
    /// When `movedStart` is true and the new start is >= end, push end forward.
    /// When `movedStart` is false and the new end is <= start, push start backward.
    static func coerce(start: inout Int, end: inout Int, step: Int, movedStart: Bool) {
        if movedStart {
            if end <= start { end = start + step }
        } else {
            if start >= end { start = end - step }
        }
    }
}
```

- [ ] **Step 4: Verify Theme.Font.bodyLgSemibold and TimeFormat.clock exist**

Run: `grep -n "bodyLgSemibold\|clock(minute" Sources/BrainDumpKit/Support/*.swift`

Expected: both names appear in `Theme.swift` and `TimeFormat.swift`. (If `bodyLgSemibold` is missing, substitute `bodyLg` — but it is present per the earlier read of `TaskDetailSheet.swift`.)

- [ ] **Step 5: Run all tests and verify they pass**

Run: `swift test --filter TimeRangePickerTests`

Expected: PASS for all four tests.

- [ ] **Step 6: Commit**

```bash
git add Sources/BrainDumpKit/Views/TimeRangePicker.swift Tests/BrainDumpTests/TimeRangePickerTests.swift
git commit -m "$(cat <<'EOF'
feat: dual-clock TimeRangePicker (MUI-style)

Two synchronized scroll-snap columns at 15-minute steps, with a
selection band in the center of each column and a live duration
readout. Pure helpers (snap, coerce) keep the invariants
end > start and end - start >= step under one-sided edits.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Swap `TimeBlockSheet` to use `TimeRangePicker`

**Files:**
- Modify: `Sources/BrainDumpKit/Views/TimeBlockSheet.swift` (whole file)

- [ ] **Step 1: Rewrite TimeBlockSheet to drive minute state directly**

Replace `Sources/BrainDumpKit/Views/TimeBlockSheet.swift`:

```swift
import SwiftUI

/// Reminders-style time-block editor used by the brain-dump drop flow.
/// Wraps the new TimeRangePicker plus a color swatch row.
public struct TimeBlockSheet: View {
    let initialStartMinute: Int
    let initialDurationMinutes: Int
    let dayStartHour: Int
    let dayEndHour: Int
    let onConfirm: (Int, Int, Int) -> Void  // startMinute, durationMinutes, colorIndex
    let onCancel: () -> Void

    @State private var startMinute: Int
    @State private var endMinute: Int
    @State private var colorIndex: Int
    @State private var error: String?

    public init(
        initialStartMinute: Int,
        initialDurationMinutes: Int = 60,
        initialColorIndex: Int = 0,
        dayStartHour: Int = 5,
        dayEndHour: Int = 22,
        onConfirm: @escaping (Int, Int, Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialStartMinute = initialStartMinute
        self.initialDurationMinutes = initialDurationMinutes
        self.dayStartHour = dayStartHour
        self.dayEndHour = dayEndHour
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        let snappedStart = TimeRangePicker.snap(minute: initialStartMinute)
        let snappedEnd = TimeRangePicker.snap(minute: initialStartMinute + initialDurationMinutes)
        _startMinute = State(initialValue: snappedStart)
        _endMinute = State(initialValue: max(snappedStart + 15, snappedEnd))
        _colorIndex = State(initialValue: initialColorIndex)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            TimeRangePicker(
                startMinute: $startMinute,
                endMinute: $endMinute,
                dayStartHour: dayStartHour,
                dayEndHour: dayEndHour
            )
            ColorSwatchRow(selected: $colorIndex)
            if let error {
                Text(error)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.secondary)
            }
            footer
        }
        .padding(28)
        .frame(width: 460)
        .background(Theme.Palette.surfaceContainerLowest)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time Block")
                .font(Theme.Font.tinyLabel)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.primary)
            Text("When should this run?")
                .font(Theme.Font.headlineMd)
                .foregroundStyle(Theme.Palette.onSurface)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(SecondaryActionStyle())
                .keyboardShortcut(.cancelAction)
            Button("Schedule", action: commit)
                .buttonStyle(PrimaryActionStyle())
                .keyboardShortcut(.defaultAction)
        }
    }

    private func commit() {
        let start = TimeRangePicker.snap(minute: startMinute)
        let end = TimeRangePicker.snap(minute: endMinute)
        guard end > start else {
            error = "End must be after start"
            return
        }
        let duration = end - start
        guard duration >= 15 else {
            error = "Block must be at least 15 minutes"
            return
        }
        guard start >= 0, end <= 24 * 60 else {
            error = "Time must be within the day"
            return
        }
        onConfirm(start, duration, colorIndex)
    }
}

private struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.labelMd)
            .tracking(0.5)
            .padding(.horizontal, 18)
            .frame(height: 34)
            .foregroundStyle(Theme.Palette.onPrimary)
            .background(Theme.Palette.primary)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.labelMd)
            .tracking(0.5)
            .padding(.horizontal, 18)
            .frame(height: 34)
            .foregroundStyle(Theme.Palette.primary)
            .background(Theme.Palette.surfaceContainerLowest)
            .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
```

- [ ] **Step 2: Update ScheduleSection to pass dayStartHour/dayEndHour to TimeBlockSheet**

In `Sources/BrainDumpKit/Views/ScheduleSection.swift`, locate the `.sheet(item: $pending)` block and replace it with:

```swift
.sheet(item: $pending) { drop in
    TimeBlockSheet(
        initialStartMinute: drop.startMinute,
        initialDurationMinutes: 60,
        dayStartHour: dayStartHour,
        dayEndHour: dayEndHour,
        onConfirm: { startMinute, durationMinutes, colorIndex in
            confirmSchedule(itemID: drop.itemID, startMinute: startMinute, durationMinutes: durationMinutes, colorIndex: colorIndex)
        },
        onCancel: { pending = nil }
    )
}
```

- [ ] **Step 3: Build and run all tests**

Run: `swift build && swift test`

Expected: PASS. Snapshot tests for TimeBlockSheet may need re-recording if they exist — check with `grep -rn TimeBlockSheet Tests/`. If snapshots break and the visual change is intentional, follow the project's snapshot-update workflow (re-record by deleting the snapshot file and re-running; or invoke any in-test `record` flag).

- [ ] **Step 4: Commit**

```bash
git add Sources/BrainDumpKit/Views/TimeBlockSheet.swift Sources/BrainDumpKit/Views/ScheduleSection.swift
git commit -m "$(cat <<'EOF'
feat: TimeBlockSheet drives the new TimeRangePicker

Replaces the two DatePicker stepper fields with the dual-clock picker.
TimeBlockSheet keeps the same onConfirm contract (start, duration,
colorIndex) so ScheduleSection's drop flow doesn't have to change.
Day window hours are threaded through so the picker bounds the
selectable range.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `TaskDetailFocus` enum + adapt call sites

**Files:**
- Modify: `Sources/BrainDumpKit/Views/TaskDetailSheet.swift:4-15` (TaskDetailFocus struct)
- Modify: `Sources/BrainDumpKit/Views/DayView.swift` (consumer)
- Modify: `Sources/BrainDumpKit/Views/BrainDumpSection.swift:131-137` (pencil action)
- Modify: `Sources/BrainDumpKit/Views/Top3Section.swift:175-178` (pencil action)
- Modify: `Sources/BrainDumpKit/Views/ScheduleSection.swift:107-111` (block tap)

- [ ] **Step 1: Replace the TaskDetailFocus struct with an enum + compatibility init**

In `Sources/BrainDumpKit/Views/TaskDetailSheet.swift`, replace lines 4-15 with:

```swift
public enum TaskDetailFocus: Identifiable {
    case create(day: Day)
    case edit(item: TaskItem, entry: ScheduleEntry?, startInEditMode: Bool)

    public var id: String {
        switch self {
        case .create(let day):
            return "create-\(day.persistentModelID.hashValue)"
        case .edit(let item, _, _):
            return "edit-\(item.id.uuidString)"
        }
    }

    /// Compatibility initializer for existing call sites that pass item/entry.
    /// Always returns `.edit(...)`.
    public init(item: TaskItem, entry: ScheduleEntry? = nil, startInEditMode: Bool = true) {
        self = .edit(item: item, entry: entry, startInEditMode: startInEditMode)
    }
}
```

- [ ] **Step 2: Add helpers to TaskDetailSheet to read focus**

Inside `TaskDetailSheet`, add private computed properties (place them near the top of the struct, after the stored `focus` and `dismiss`):

```swift
private var focusItem: TaskItem? {
    if case .edit(let item, _, _) = focus { return item }
    return nil
}

private var focusEntry: ScheduleEntry? {
    if case .edit(_, let entry, _) = focus { return entry }
    return nil
}

private var focusDay: Day? {
    switch focus {
    case .create(let day): return day
    case .edit(let item, _, _): return item.day
    }
}

private var isCreateMode: Bool {
    if case .create = focus { return true }
    return false
}
```

- [ ] **Step 3: Rewrite TaskDetailSheet.init for both modes**

Replace the existing `init(focus:dismiss:)` body in `TaskDetailSheet`:

```swift
public init(focus: TaskDetailFocus, dismiss: @escaping () -> Void) {
    self.focus = focus
    self.dismiss = dismiss
    switch focus {
    case .create:
        _isEditing = State(initialValue: true)
        _title = State(initialValue: "")
        _notes = State(initialValue: "")
        _tags = State(initialValue: [])
        _startMinute = State(initialValue: 9 * 60)
        _endMinute = State(initialValue: 10 * 60)
        _colorIndex = State(initialValue: 0)
        _scheduleEnabled = State(initialValue: false)
    case .edit(let item, let entry, let startInEditMode):
        _isEditing = State(initialValue: startInEditMode)
        _title = State(initialValue: item.title)
        _notes = State(initialValue: item.notes)
        _tags = State(initialValue: item.tags)
        if let entry {
            _startMinute = State(initialValue: entry.startMinute)
            _endMinute = State(initialValue: entry.endMinute)
            _colorIndex = State(initialValue: entry.colorIndex)
            _scheduleEnabled = State(initialValue: true)
        } else {
            _startMinute = State(initialValue: 9 * 60)
            _endMinute = State(initialValue: 10 * 60)
            _colorIndex = State(initialValue: 0)
            _scheduleEnabled = State(initialValue: false)
        }
    }
}
```

- [ ] **Step 4: Replace stored state vars (Date → Int) at the top of TaskDetailSheet**

Replace:

```swift
@State private var startDate: Date
@State private var endDate: Date
```

with:

```swift
@State private var startMinute: Int
@State private var endMinute: Int
@State private var scheduleEnabled: Bool
```

Also remove `private let hasEntry: Bool` and any references to it.

- [ ] **Step 5: Build to find broken call sites**

Run: `swift build`

Expected: errors at TaskDetailFocus usage points and in `TaskDetailSheet.commit()`. Note them down; the following steps fix them.

- [ ] **Step 6: Update DayView and other consumers of TaskDetailFocus**

The factory pattern (the existing compatibility init) means `TaskDetailFocus(item:entry:startInEditMode:)` keeps working in:

- `BrainDumpSection.swift:135-136`: `openDetail?(TaskDetailFocus(item: item, entry: scheduled, startInEditMode: true))`
- `Top3Section.swift:176-177`: `openDetail?(TaskDetailFocus(item: item, entry: scheduled, startInEditMode: true))`
- `ScheduleSection.swift:109`: `openDetail?(TaskDetailFocus(item: item, entry: entryRef, startInEditMode: false))`

These should still compile because the compatibility init exists. If the compiler complains, leave them as-is — the issue is elsewhere.

- [ ] **Step 7: Run the build again**

Run: `swift build`

Expected: only errors inside `TaskDetailSheet.swift` itself (commit method, body sections still referencing `focus.item`, `focus.entry`, `hasEntry`).

- [ ] **Step 8: Replace remaining focus.item / focus.entry / hasEntry usages**

In `TaskDetailSheet.swift`:

- Replace `focus.item.title`, `focus.item.notes`, etc. with `focusItem?.title ?? ""`, `focusItem?.notes ?? ""`, etc. — *or* with the locally-stored `title` / `notes` (those are the authoritative source after init).
- Replace `focus.startInEditMode` with `(isCreateMode || (focusEntry == nil) ? true : focus.startInEditModeIfEdit)`. Or simpler: store `startInEditMode` once at init.

Simpler refactor: store `private let startInEditModeAtInit: Bool` and assign it in the init from each case. Replace usage with that.

In `cancelEdit()`, replace `focus.startInEditMode` with `startInEditModeAtInit`. The reset block uses `focusItem?.title ?? ""`, etc.

- [ ] **Step 9: Build to verify just-syntax**

Run: `swift build`

Expected: ALL clean. (The commit() and view-body rewiring continues in Task 6.)

- [ ] **Step 10: Commit the structural refactor**

```bash
git add Sources/BrainDumpKit/Views/TaskDetailSheet.swift
git commit -m "$(cat <<'EOF'
refactor: TaskDetailFocus becomes an enum (create + edit)

Adds a .create(day:) case alongside .edit(item:entry:startInEditMode:),
with a compatibility initializer so existing call sites that pass
(item:entry:startInEditMode:) keep working. Replaces the Date-based
schedule state with Int minute state so it can drive the new
TimeRangePicker.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `TaskDetailSheet` create mode + schedule toggle (features 2 & 3 wired together)

**Files:**
- Modify: `Sources/BrainDumpKit/Views/TaskDetailSheet.swift` (body sections, commit)
- Create: `Tests/BrainDumpTests/TaskDetailSheetTests.swift`

- [ ] **Step 1: Replace the editBody section to include the toggle + picker**

In `TaskDetailSheet.swift`, replace `editBody` and `scheduleEditor`:

```swift
private var editBody: some View {
    VStack(alignment: .leading, spacing: 20) {
        editHeader
        titleField
        notesField
        tagsField
        scheduleSection
        if let errorText {
            Text(errorText)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.secondary)
        }
        footer
    }
}

@ViewBuilder
private var scheduleSection: some View {
    // Edit mode + existing entry: always-on, no toggle.
    if !isCreateMode, focusEntry != nil {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME BLOCK")
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            TimeRangePicker(
                startMinute: $startMinute,
                endMinute: $endMinute
            )
            ColorSwatchRow(selected: $colorIndex)
        }
    } else {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $scheduleEnabled) {
                Text("Add to Schedule")
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurface)
            }
            .toggleStyle(.switch)
            if scheduleEnabled {
                TimeRangePicker(
                    startMinute: $startMinute,
                    endMinute: $endMinute
                )
                ColorSwatchRow(selected: $colorIndex)
            }
        }
    }
}
```

Remove the old `scheduleEditor` and `editableTimeField` private methods if unused.

- [ ] **Step 2: Replace commit() to handle create + edit + schedule**

In `TaskDetailSheet.swift`, replace `commit()`:

```swift
private func commit() {
    let taskService = TaskService(context: context)
    let scheduleService = ScheduleService(context: context)
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

    // 1. Resolve target item (create or existing).
    let item: TaskItem
    switch focus {
    case .create(let day):
        guard !trimmedTitle.isEmpty else {
            errorText = "Title is required"
            return
        }
        item = taskService.addBrainDumpItem(
            title: trimmedTitle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags,
            on: day
        )
    case .edit(let existing, _, _):
        item = existing
        if !trimmedTitle.isEmpty, trimmedTitle != existing.title {
            taskService.rename(existing, to: trimmedTitle)
        }
        if notes != existing.notes {
            taskService.updateNotes(existing, notes: notes)
        }
        if tags != existing.tags {
            taskService.updateTags(existing, tags: tags)
        }
    }

    // 2. Reconcile schedule.
    let entry = focusEntry
    let wantsSchedule = scheduleEnabled || entry != nil
    let day = focusDay

    if wantsSchedule, let day {
        let start = TimeRangePicker.snap(minute: startMinute)
        let end = TimeRangePicker.snap(minute: endMinute)
        guard end > start else {
            errorText = "End must be after start"
            return
        }
        let duration = end - start

        do {
            if let entry {
                let timeChanged = entry.startMinute != start || entry.durationMinutes != duration
                if timeChanged {
                    try scheduleService.reschedule(entry, startMinute: start, durationMinutes: duration)
                }
                if entry.colorIndex != colorIndex {
                    scheduleService.setColorIndex(entry, colorIndex)
                }
            } else {
                _ = try scheduleService.schedule(
                    item,
                    on: day,
                    startMinute: start,
                    durationMinutes: duration,
                    colorIndex: colorIndex
                )
            }
        } catch TodoError.scheduleConflict {
            errorText = "Conflicts with another block"
            return
        } catch TodoError.scheduleOutOfRange {
            errorText = "Time range is out of bounds"
            return
        } catch {
            errorText = "Could not schedule"
            return
        }
    }

    dismiss()
}
```

- [ ] **Step 3: Update cancelEdit() to handle create mode**

Replace `cancelEdit()`:

```swift
private func cancelEdit() {
    if isCreateMode || startInEditModeAtInit {
        dismiss()
        return
    }
    title = focusItem?.title ?? ""
    notes = focusItem?.notes ?? ""
    tags = focusItem?.tags ?? []
    newTagDraft = ""
    if let entry = focusEntry {
        startMinute = entry.startMinute
        endMinute = entry.endMinute
        colorIndex = entry.colorIndex
        scheduleEnabled = true
    } else {
        scheduleEnabled = false
    }
    errorText = nil
    isEditing = false
}
```

- [ ] **Step 4: Add the create-mode read-only fallback**

In `body`:

```swift
public var body: some View {
    Group {
        if isCreateMode || isEditing {
            editBody
        } else {
            readOnlyBody
        }
    }
    .padding(28)
    .frame(width: 480)
    .background(Theme.Palette.surfaceContainerLowest)
}
```

- [ ] **Step 5: Update readOnlyBody to be safe when item could be nil**

(In create mode we render `editBody`, so `readOnlyBody`'s `focus.item` references must become `focusItem?.…`. Easier: keep the read-only body referencing `focusItem!` — since create mode never reaches it. Use `guard let item = focusItem` at the top of `readOnlyBody`.)

```swift
private var readOnlyBody: some View {
    Group {
        if let item = focusItem {
            readOnlyContent(item: item)
        } else {
            EmptyView()
        }
    }
}

private func readOnlyContent(item: TaskItem) -> some View {
    VStack(alignment: .leading, spacing: 20) {
        readOnlyHeader
        Text(item.title)
            .font(Theme.Font.headlineMd)
            .foregroundStyle(Theme.Palette.onSurface)
            .fixedSize(horizontal: false, vertical: true)
        if !item.notes.isEmpty {
            readOnlySection("Description") {
                Text(item.notes)
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if !item.tags.isEmpty {
            readOnlySection("Tags") {
                TagChipRow(tags: item.tags)
            }
        }
        if let entry = focusEntry {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Theme.BlockPalette.color(at: entry.colorIndex))
                    .frame(width: 12, height: 12)
                Text(TimeFormat.range(startMinute: entry.startMinute, durationMinutes: entry.durationMinutes))
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurface)
                if entry.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
        }
        Spacer(minLength: 0)
        readOnlyFooter
    }
    .frame(minHeight: 220, alignment: .topLeading)
}
```

- [ ] **Step 6: Write failing tests**

Create `Tests/BrainDumpTests/TaskDetailSheetTests.swift`:

```swift
import Testing
import SwiftData
import SwiftUI
@testable import BrainDumpKit

@MainActor
@Suite struct TaskDetailSheetTests {
    @Test func createFocus_hasCreateID() throws {
        let (context, _) = try InMemoryStore.makeContextAndContainer()
        let day = Day(date: TestDate.at(2026, 5, 23))
        context.insert(day)
        let focus = TaskDetailFocus.create(day: day)
        #expect(focus.id.hasPrefix("create-"))
    }

    @Test func editFocus_compatibilityInit_createsEditCase() throws {
        let (context, _) = try InMemoryStore.makeContextAndContainer()
        let day = Day(date: TestDate.at(2026, 5, 23))
        context.insert(day)
        let item = TaskService(context: context).addBrainDumpItem(title: "x", on: day)
        let focus = TaskDetailFocus(item: item, entry: nil, startInEditMode: false)
        if case .edit(let f, let e, let s) = focus {
            #expect(f.id == item.id)
            #expect(e == nil)
            #expect(s == false)
        } else {
            Issue.record("Expected .edit case")
        }
    }

    @Test func sheet_buildsInCreateMode() throws {
        let (context, _) = try InMemoryStore.makeContextAndContainer()
        let day = Day(date: TestDate.at(2026, 5, 23))
        context.insert(day)
        let sheet = TaskDetailSheet(focus: .create(day: day), dismiss: {})
        _ = sheet.body  // smoke
    }

    @Test func sheet_buildsInEditModeWithEntry() throws {
        let (context, _) = try InMemoryStore.makeContextAndContainer()
        let day = Day(date: TestDate.at(2026, 5, 23))
        context.insert(day)
        let item = TaskService(context: context).addBrainDumpItem(title: "x", on: day)
        let entry = try ScheduleService(context: context).schedule(
            item, on: day, startMinute: 9 * 60, durationMinutes: 60
        )
        let sheet = TaskDetailSheet(focus: .edit(item: item, entry: entry, startInEditMode: false), dismiss: {})
        _ = sheet.body
    }
}
```

- [ ] **Step 7: Run the tests**

Run: `swift test --filter TaskDetailSheetTests`

Expected: PASS.

- [ ] **Step 8: Run the full test suite**

Run: `swift test`

Expected: PASS. Existing snapshot tests that capture TaskDetailSheet rendering may need re-recording; if so, update the snapshot files.

- [ ] **Step 9: Commit**

```bash
git add Sources/BrainDumpKit/Views/TaskDetailSheet.swift Tests/BrainDumpTests/TaskDetailSheetTests.swift
git commit -m "$(cat <<'EOF'
feat: TaskDetailSheet handles create + edit + schedule

The modal now has a create mode (no existing TaskItem yet) and an
'Add to Schedule' toggle that reveals the new TimeRangePicker.
On commit, the create case inserts a brain-dump item and then —
if the toggle is on — schedules it. Edit mode is unchanged when
the task already has an entry; when it has no entry, the same
toggle lets the user schedule it from the modal.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: BrainDumpSection "+" button opens the modal (feature 3 wiring)

**Files:**
- Modify: `Sources/BrainDumpKit/Views/BrainDumpSection.swift` (header + body)
- Modify: `Sources/BrainDumpKit/Views/DayView.swift` (passes openDetail; existing sheet already handles arbitrary TaskDetailFocus)

- [ ] **Step 1: Update the BrainDumpSection's "+" button to open the modal**

In `Sources/BrainDumpKit/Views/BrainDumpSection.swift`, locate the header's button (line ~73-82) and change its action from `addFocus = .title` to:

```swift
Button {
    openDetail?(TaskDetailFocus.create(day: day))
} label: {
    Image(systemName: "plus.circle")
        .font(.system(size: 18, weight: .regular))
        .foregroundStyle(Theme.Palette.onSurfaceVariant)
}
.buttonStyle(.plain)
.help("Add brain-dump item")
```

The inline add row at the bottom of the list is left untouched.

- [ ] **Step 2: Build and run all tests**

Run: `swift build && swift test`

Expected: PASS. DayView already dispatches on TaskDetailFocus via `.sheet(item: $detailFocus)`, which now accepts the `.create(day:)` case transparently.

- [ ] **Step 3: Commit**

```bash
git add Sources/BrainDumpKit/Views/BrainDumpSection.swift
git commit -m "$(cat <<'EOF'
feat: Brain Dump '+' button opens the create modal

The header '+' now opens TaskDetailSheet in create mode rather than
focusing the inline add row, so it remains useful when the list is
long enough that the inline row is below the fold. The inline add
row stays for quick capture.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Context menus on Brain Dump and Top3 rows (feature 4)

**Files:**
- Modify: `Sources/BrainDumpKit/Views/BrainDumpSection.swift` (row body, add @State for error)
- Modify: `Sources/BrainDumpKit/Views/Top3Section.swift` (filledRow body)

- [ ] **Step 1: Add escalate error state to BrainDumpSection**

In `BrainDumpSection`, add near the other `@State` declarations:

```swift
@State private var escalateError: String?
```

Display it in the header area (replacing or alongside any existing error UI). After the header, conditionally render:

```swift
if let escalateError {
    Text(escalateError)
        .font(Theme.Font.caption)
        .foregroundStyle(Theme.Palette.secondary)
}
```

Place that line right after `header` inside the main `VStack`.

- [ ] **Step 2: Add the context menu to each row**

In `BrainDumpSection.row(for:)`, append after `.draggable(...)`:

```swift
.contextMenu {
    if !isReadOnly {
        Button("Move to Priority") {
            do {
                try TaskService(context: context).escalate(item, on: day)
                escalateError = nil
            } catch TodoError.top3Full {
                escalateError = "Top 3 is full"
            } catch {
                escalateError = "Could not move"
            }
        }
    }
}
```

- [ ] **Step 3: Add the context menu to Top3 filledRow**

In `Top3SlotRow.filledRow(item:)`, append after `.dropDestination(...)`:

```swift
.contextMenu {
    if !isReadOnly {
        Button("Move to Brain Dump") {
            taskService.deescalate(item, on: day)
        }
    }
}
```

- [ ] **Step 4: Build and run all tests**

Run: `swift build && swift test`

Expected: PASS. No tests assert the context menu rendering (SwiftUI context menus aren't trivially snapshot-able), but service-level escalate/deescalate tests exist.

- [ ] **Step 5: Commit**

```bash
git add Sources/BrainDumpKit/Views/BrainDumpSection.swift Sources/BrainDumpKit/Views/Top3Section.swift
git commit -m "$(cat <<'EOF'
feat: context menus for escalate / deescalate

Right-click on a brain-dump row offers 'Move to Priority'; right-click
on a Top3 row offers 'Move to Brain Dump'. Wire to the existing
TaskService methods. Top3-full errors surface as a transient string
under the section header.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Whole-app verification

**Files:** none — verification only.

- [ ] **Step 1: Run all tests**

Run: `swift test`

Expected: all tests pass.

- [ ] **Step 2: Build for the app target via xcodebuild**

Run: `xcodebuild -project BrainDump.xcodeproj -scheme BrainDump -configuration Debug build 2>&1 | tail -30`

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual smoke test (run in Xcode)**

The agent should write out the smoke list for the user; the user will run it manually.

Smoke list:
1. Add three brain-dump items via the inline row.
2. Add a fourth via the "+" button — confirm a modal appears with empty fields. Type a title, toggle "Add to Schedule" off, click Save. Item appears in the brain dump.
3. Add a fifth via "+", with toggle on, pick a time range, Save. Item appears in both brain dump and schedule.
4. Right-click an existing brain-dump item → "Move to Priority". It moves.
5. Right-click a Top3 item → "Move to Brain Dump". It moves back.
6. Press-and-hold a Top3 item, release without moving — no freeze, list does not visibly reshuffle.
7. Press-and-hold a brain-dump item, release without moving — no freeze.
8. Drag a brain-dump item to an empty schedule slot — TimeBlockSheet appears with dual-clock picker, default 60-min duration. Confirm.
9. Click pencil on a scheduled item — TaskDetailSheet opens with the picker preselected to the entry's time. Change the end time, Save — entry updates.
10. Try right-clicking a brain-dump item while Top3 already has 3 — error "Top 3 is full" appears under the header.

- [ ] **Step 4: Final commit (if any uncommitted polish landed)**

```bash
git status
```

If anything is uncommitted, commit it. Otherwise skip.

---

## Self-Review

**Spec coverage check:**

- Feature 1 (dual-clock picker) → Tasks 3, 4, 6 ✓
- Feature 2 (edit modal assigns to schedule) → Tasks 5, 6 ✓
- Feature 3 ("+" opens modal, inline row stays) → Tasks 5, 7 ✓
- Feature 4 (context menus) → Task 8 ✓
- Feature 5 (drag freeze fix) → Tasks 1, 2 ✓

**Placeholders:** none. Every step has the code or command to run.

**Type consistency:**
- `TaskDetailFocus` enum: `.create(day: Day)` and `.edit(item: TaskItem, entry: ScheduleEntry?, startInEditMode: Bool)` — used consistently in Task 5 and Task 6.
- `TimeRangePicker.snap(minute:)` — defined in Task 3, used in Task 4 (TimeBlockSheet) and Task 6 (TaskDetailSheet.commit).
- `startInEditModeAtInit` — referenced in Task 5 step 8 and Task 6 step 3. Must be added as `private let startInEditModeAtInit: Bool` and initialized in each init case in Task 5. (Adding this to the Task 5 list inline below.)

**Inline fix:** Task 5 must store `startInEditModeAtInit`. Step 2 of Task 5 already adds `isCreateMode`; add `startInEditModeAtInit: Bool` alongside. Step 3 of Task 5 should set `startInEditModeAtInit = true` in the create case, and `startInEditModeAtInit = startInEditMode` in the edit case. Update Task 5 accordingly when executing.
