# Optional time range when filtering by completion date

## Goal

In the Tasks tab, the "Filter by completion date" toggle currently always applies a `[From, To]` date range. Make that range optional: when the parent toggle is on, the default is to show *all* completed tasks; the user can opt in to a specific date range.

## Behavior

| Parent toggle | Specific-range sub-toggle | Result |
| --- | --- | --- |
| Off (default) | n/a | All non-backlog tasks (current default) |
| On | Off (default) | All completed non-backlog tasks |
| On | On | Completed tasks whose `completedAt` is in `[From, To]` |

Turning the parent toggle off hides both the sub-toggle and the date pickers. Toggling the sub-toggle on/off keeps the parent on.

## UI

`TasksScreen.dateRangeFilter`:

```
[x] Filter by completion date
    [ ] Specific date range
        From: [date picker]  To: [date picker]
```

Sub-toggle is indented to indicate hierarchy. From/To pickers only appear when the sub-toggle is on.

## Service API

Extend `TaskService.searchTasks` with a `completedOnly: Bool = false` parameter:

```swift
public func searchTasks(
    keyword: String?,
    tag: String?,
    completedOnly: Bool = false,
    completedRange: ClosedRange<Date>? = nil
) -> [TaskItem]
```

Semantics:
- `completedOnly=false, completedRange=nil` → no completion filter (existing default; existing callers/tests still compile)
- `completedOnly=true, completedRange=nil` → all completed tasks (new)
- `completedRange=range` → completed within range (existing behavior; `completedOnly` value is ignored because the range already implies completion)

Implementation: any non-nil `completedRange` filters by both completion and date. If `completedRange == nil` and `completedOnly == true`, filter by completion only (any task with at least one completed `ScheduleEntry`).

## Tests

Append `@Test` functions to `Tests/BrainDumpTests/TaskServiceTests.swift`:

1. `searchCompletedOnlyReturnsAllCompletedRegardlessOfDate` — two completed tasks on different days; `completedOnly=true, completedRange=nil` returns both.
2. `searchCompletedOnlyIgnoresUncompletedItems` — completed + uncompleted task on the same day; `completedOnly=true` returns only the completed one.
3. `searchCompletedOnlyFalseAndRangeNilReturnsAll` — existing semantics preserved (mix of completed/uncompleted returned).

Existing tests using `completedRange:` keep their meaning.

## Out of scope

- Persisting the user's filter selection across launches.
- Defaulting the parent toggle on (current default — off — is preserved).
- Any change to keyword/tag filters.
