# todoosx Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a "pretty" macOS To Do app modeled on the Harvard Daily Timebox planner, in SwiftUI + SwiftData, with each feature landing behind a passing test and its own commit.

**Architecture:** Swift Package executable target for the app + a unit test target. Three SwiftData models (`Day`, `TaskItem`, `ScheduleEntry`) accessed through three service classes (`DayService`, `TaskService`, `ScheduleService`). SwiftUI views consume an `@Observable AppState` that owns the current date and triggers rollover. All business logic lives in services and is exercised by XCTest using an in-memory `ModelContainer`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, **Swift Testing** (not XCTest). Swift Package Manager (`Package.swift`) — no `.xcodeproj`. macOS 14+.

## Amendment (applied during Task 0)

The plan was originally written assuming an XCTest test target run by `swift test`. On a machine with Command Line Tools but no full Xcode, `swift test` silently no-ops (the `xctest` runner isn't included with CLT). To get real TDD without requiring Xcode, the structure changed to:

```
Sources/
  TodoosxKit/        ← library (models, services, AppState, views — public types)
  todoosx/           ← app executable (@main TodoosxApp)
  todoosx-test/      ← test runner executable (@main TestRunner, calls Testing.__swiftPMEntryPoint)
```

- Tests live in `Sources/todoosx-test/` (alongside `Runner.swift`), not `Tests/`.
- Tests use **Swift Testing** (`import Testing`, `@Test func ...`, `#expect(...)`, `#expect(throws: ...) { ... }`), not XCTest.
- Run tests: `swift run todoosx-test` (not `swift test`). Filter: `swift run todoosx-test --filter <name>`.
- All library types referenced by tests must be `public` (or `internal` with `@testable import TodoosxKit`).
- `@MainActor` is applied per `@Test func`, not per class (there are no test classes in Swift Testing).
- Translation key for the rest of the plan:
  - `XCTAssertEqual(a, b)` → `#expect(a == b)`
  - `XCTAssertTrue(x)` / `XCTAssertFalse(x)` → `#expect(x)` / `#expect(!x)`
  - `XCTAssertThrowsError(try f()) { XCTAssertEqual($0 as? E, .case) }` → `#expect(throws: E.case) { try f() }`
  - `XCTUnwrap(x)` → `try #require(x)`
  - Test methods drop the `test` prefix and `()` becomes the test name; mark each with `@MainActor` when SwiftData is involved.
- Spec section paths reference `todoosx/` subdir; with this amendment, "models" live under `Sources/TodoosxKit/Models/`, "services" under `Sources/TodoosxKit/Services/`, etc.

**Important conventions used throughout this plan:**
- All `Date`s in tests are constructed from explicit components in the local time zone via a helper, never `Date()`-now.
- All SwiftData calls happen on `MainActor`. `@Test` functions touching SwiftData are marked `@MainActor`.
- Every task ends with `swift run todoosx-test` passing and a commit.
- File paths are relative to repo root: `/Users/al03195220/github.com/toy/todoosx`.

---

## Task 0: Project scaffolding

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/todoosx/App/Placeholder.swift`
- Create: `Tests/todoosxTests/SmokeTest.swift`

- [ ] **Step 1: Create `.gitignore`**

```gitignore
.DS_Store
.build/
.swiftpm/
DerivedData/
*.xcodeproj
Package.resolved
```

- [ ] **Step 2: Create `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "todoosx",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "todoosx", targets: ["todoosx"]),
    ],
    targets: [
        .executableTarget(
            name: "todoosx",
            path: "Sources/todoosx"
        ),
        .testTarget(
            name: "todoosxTests",
            dependencies: ["todoosx"],
            path: "Tests/todoosxTests"
        ),
    ]
)
```

- [ ] **Step 3: Create placeholder source so the package builds**

`Sources/todoosx/App/Placeholder.swift`:

```swift
// Placeholder so SwiftPM has a source file to compile until the real app
// entry point is added in a later task.
import Foundation

enum Placeholder {
    static let marker = "todoosx"
}
```

- [ ] **Step 4: Create smoke test**

`Tests/todoosxTests/SmokeTest.swift`:

```swift
import XCTest
@testable import todoosx

final class SmokeTest: XCTestCase {
    func testPackageBuildsAndImports() {
        XCTAssertEqual(Placeholder.marker, "todoosx")
    }
}
```

- [ ] **Step 5: Verify build & test pass**

Run: `swift test`
Expected: `Test Suite 'All tests' passed`. 1 test case.

- [ ] **Step 6: Commit**

```bash
git add Package.swift .gitignore Sources Tests
git commit -m "chore: scaffold Swift package and smoke test"
```

---

## Task 1: SwiftData models

**Files:**
- Create: `Sources/todoosx/Models/Day.swift`
- Create: `Sources/todoosx/Models/TaskItem.swift`
- Create: `Sources/todoosx/Models/ScheduleEntry.swift`
- Create: `Sources/todoosx/Models/TodoError.swift`
- Create: `Sources/todoosx/Support/Date+StartOfDay.swift`
- Create: `Tests/todoosxTests/TestSupport/InMemoryStore.swift`
- Create: `Tests/todoosxTests/ModelTests.swift`
- Delete: `Sources/todoosx/App/Placeholder.swift`
- Delete: `Tests/todoosxTests/SmokeTest.swift`

- [ ] **Step 1: Write the failing test**

`Tests/todoosxTests/ModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import todoosx

@MainActor
final class ModelTests: XCTestCase {
    func testCanInsertAndFetchADay() throws {
        let context = try InMemoryStore.makeContext()
        let date = DateComponents(calendar: .current, year: 2026, month: 5, day: 22).date!
        let day = Day(date: date)
        context.insert(day)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Day>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.date, date)
    }

    func testTaskItemBelongsToDay() throws {
        let context = try InMemoryStore.makeContext()
        let date = DateComponents(calendar: .current, year: 2026, month: 5, day: 22).date!
        let day = Day(date: date)
        let item = TaskItem(title: "Write spec")
        item.day = day
        context.insert(day)
        context.insert(item)
        try context.save()

        let fetchedDay = try XCTUnwrap(context.fetch(FetchDescriptor<Day>()).first)
        XCTAssertEqual(fetchedDay.items.count, 1)
        XCTAssertEqual(fetchedDay.items.first?.title, "Write spec")
    }

    func testStartOfDayNormalization() throws {
        let cal = Calendar.current
        let mid = DateComponents(calendar: cal, year: 2026, month: 5, day: 22, hour: 14, minute: 30).date!
        let startOfDay = mid.startOfLocalDay()
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startOfDay)
        XCTAssertEqual(comps.hour, 0)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.second, 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: compile errors / missing types `Day`, `TaskItem`, `ScheduleEntry`, `InMemoryStore`, `startOfLocalDay()`.

- [ ] **Step 3: Implement `Day`**

`Sources/todoosx/Models/Day.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Day {
    @Attribute(.unique) var date: Date
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.day)
    var items: [TaskItem] = []
    @Relationship(deleteRule: .cascade, inverse: \ScheduleEntry.day)
    var schedule: [ScheduleEntry] = []
    var top3ItemIDs: [UUID] = []

    init(date: Date) {
        self.date = date.startOfLocalDay()
    }
}
```

- [ ] **Step 4: Implement `TaskItem`**

`Sources/todoosx/Models/TaskItem.swift`:

```swift
import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var day: Day?

    init(title: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 5: Implement `ScheduleEntry`**

`Sources/todoosx/Models/ScheduleEntry.swift`:

```swift
import Foundation
import SwiftData

@Model
final class ScheduleEntry {
    @Attribute(.unique) var id: UUID
    var startHour: Int
    var durationHours: Int
    var isCompleted: Bool
    var item: TaskItem?
    var day: Day?

    init(startHour: Int, durationHours: Int, item: TaskItem? = nil, day: Day? = nil) {
        self.id = UUID()
        self.startHour = startHour
        self.durationHours = durationHours
        self.isCompleted = false
        self.item = item
        self.day = day
    }
}
```

- [ ] **Step 6: Implement `TodoError`**

`Sources/todoosx/Models/TodoError.swift`:

```swift
import Foundation

enum TodoError: Error, Equatable {
    case top3Full
    case scheduleConflict
    case scheduleOutOfRange
}
```

- [ ] **Step 7: Implement `Date.startOfLocalDay()`**

`Sources/todoosx/Support/Date+StartOfDay.swift`:

```swift
import Foundation

extension Date {
    func startOfLocalDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}
```

- [ ] **Step 8: Implement `InMemoryStore` helper**

`Tests/todoosxTests/TestSupport/InMemoryStore.swift`:

```swift
import Foundation
import SwiftData
@testable import todoosx

@MainActor
enum InMemoryStore {
    static func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Day.self, TaskItem.self, ScheduleEntry.self,
            configurations: config
        )
        return ModelContext(container)
    }
}
```

- [ ] **Step 9: Delete placeholder and smoke test**

```bash
rm Sources/todoosx/App/Placeholder.swift
rm Tests/todoosxTests/SmokeTest.swift
```

- [ ] **Step 10: Run tests to verify they pass**

Run: `swift test`
Expected: 3 tests pass.

- [ ] **Step 11: Commit**

```bash
git add Sources Tests
git commit -m "feat: add SwiftData models for Day, TaskItem, ScheduleEntry"
```

---

## Task 2: `DayService.day(for:)`

**Files:**
- Create: `Sources/todoosx/Services/DayService.swift`
- Create: `Tests/todoosxTests/DayServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/todoosxTests/DayServiceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import todoosx

@MainActor
final class DayServiceTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0, minute: Int = 0) -> Date {
        DateComponents(calendar: .current, year: y, month: m, day: d, hour: hour, minute: minute).date!
    }

    func testDayForReturnsSameDayForRepeatedCalls() throws {
        let context = try InMemoryStore.makeContext()
        let service = DayService(context: context)

        let d1 = service.day(for: date(2026, 5, 22))
        let d2 = service.day(for: date(2026, 5, 22))

        XCTAssertTrue(d1 === d2)
    }

    func testDayForNormalizesToStartOfDay() throws {
        let context = try InMemoryStore.makeContext()
        let service = DayService(context: context)

        let d = service.day(for: date(2026, 5, 22, hour: 14, minute: 30))
        XCTAssertEqual(d.date, date(2026, 5, 22))
    }

    func testDayForCreatesDistinctDaysForDistinctDates() throws {
        let context = try InMemoryStore.makeContext()
        let service = DayService(context: context)

        let a = service.day(for: date(2026, 5, 22))
        let b = service.day(for: date(2026, 5, 23))

        XCTAssertNotEqual(a.date, b.date)
        let all = try context.fetch(FetchDescriptor<Day>())
        XCTAssertEqual(all.count, 2)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter DayServiceTests`
Expected: compile error — `DayService` not defined.

- [ ] **Step 3: Implement `DayService.day(for:)`**

`Sources/todoosx/Services/DayService.swift`:

```swift
import Foundation
import SwiftData

@MainActor
final class DayService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func day(for date: Date) -> Day {
        let target = date.startOfLocalDay()
        let predicate = #Predicate<Day> { $0.date == target }
        let descriptor = FetchDescriptor<Day>(predicate: predicate)
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let day = Day(date: target)
        context.insert(day)
        try? context.save()
        return day
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DayServiceTests`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/todoosx/Services/DayService.swift Tests/todoosxTests/DayServiceTests.swift
git commit -m "feat: DayService.day(for:) with start-of-day normalization"
```

---

## Task 3: `TaskService` — add / rename / delete brain-dump items

**Files:**
- Create: `Sources/todoosx/Services/TaskService.swift`
- Create: `Tests/todoosxTests/TaskServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/todoosxTests/TaskServiceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import todoosx

@MainActor
final class TaskServiceTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: .current, year: y, month: m, day: d).date!
    }

    func testAddBrainDumpItemAppendsToDay() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let today = dayService.day(for: date(2026, 5, 22))

        let item = taskService.addBrainDumpItem(title: "Buy groceries", on: today)

        XCTAssertEqual(today.items.count, 1)
        XCTAssertEqual(today.items.first?.id, item.id)
        XCTAssertEqual(item.title, "Buy groceries")
    }

    func testRenameUpdatesTitle() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let today = dayService.day(for: date(2026, 5, 22))

        let item = taskService.addBrainDumpItem(title: "Old", on: today)
        taskService.rename(item, to: "New")

        XCTAssertEqual(item.title, "New")
    }

    func testDeleteRemovesItem() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let today = dayService.day(for: date(2026, 5, 22))

        let item = taskService.addBrainDumpItem(title: "Doomed", on: today)
        taskService.delete(item)

        XCTAssertTrue(today.items.isEmpty)
        let remaining = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(remaining.count, 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TaskServiceTests`
Expected: compile error — `TaskService` not defined.

- [ ] **Step 3: Implement `TaskService` (CRUD only)**

`Sources/todoosx/Services/TaskService.swift`:

```swift
import Foundation
import SwiftData

@MainActor
final class TaskService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func addBrainDumpItem(title: String, on day: Day) -> TaskItem {
        let item = TaskItem(title: title)
        item.day = day
        context.insert(item)
        try? context.save()
        return item
    }

    func rename(_ item: TaskItem, to title: String) {
        item.title = title
        try? context.save()
    }

    func delete(_ item: TaskItem) {
        if let day = item.day {
            day.top3ItemIDs.removeAll { $0 == item.id }
        }
        context.delete(item)
        try? context.save()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TaskServiceTests`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/todoosx/Services/TaskService.swift Tests/todoosxTests/TaskServiceTests.swift
git commit -m "feat: TaskService brain-dump CRUD"
```

---

## Task 4: `TaskService` — Top 3 escalate / de-escalate

**Files:**
- Modify: `Sources/todoosx/Services/TaskService.swift`
- Modify: `Tests/todoosxTests/TaskServiceTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `TaskServiceTests`:

```swift
    func testEscalateAddsToTop3() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let today = dayService.day(for: date(2026, 5, 22))

        let item = taskService.addBrainDumpItem(title: "A", on: today)
        try taskService.escalate(item, on: today)

        XCTAssertEqual(today.top3ItemIDs, [item.id])
    }

    func testEscalateIsIdempotent() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let today = dayService.day(for: date(2026, 5, 22))

        let item = taskService.addBrainDumpItem(title: "A", on: today)
        try taskService.escalate(item, on: today)
        try taskService.escalate(item, on: today)

        XCTAssertEqual(today.top3ItemIDs, [item.id])
    }

    func testEscalateThrowsWhenTop3Full() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let today = dayService.day(for: date(2026, 5, 22))

        let a = taskService.addBrainDumpItem(title: "A", on: today)
        let b = taskService.addBrainDumpItem(title: "B", on: today)
        let c = taskService.addBrainDumpItem(title: "C", on: today)
        let d = taskService.addBrainDumpItem(title: "D", on: today)
        try taskService.escalate(a, on: today)
        try taskService.escalate(b, on: today)
        try taskService.escalate(c, on: today)

        XCTAssertThrowsError(try taskService.escalate(d, on: today)) { error in
            XCTAssertEqual(error as? TodoError, .top3Full)
        }
    }

    func testDeescalateRemoves() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let today = dayService.day(for: date(2026, 5, 22))

        let a = taskService.addBrainDumpItem(title: "A", on: today)
        let b = taskService.addBrainDumpItem(title: "B", on: today)
        try taskService.escalate(a, on: today)
        try taskService.escalate(b, on: today)
        taskService.deescalate(a, on: today)

        XCTAssertEqual(today.top3ItemIDs, [b.id])
    }

    func testReorderTop3() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let today = dayService.day(for: date(2026, 5, 22))

        let a = taskService.addBrainDumpItem(title: "A", on: today)
        let b = taskService.addBrainDumpItem(title: "B", on: today)
        let c = taskService.addBrainDumpItem(title: "C", on: today)
        try taskService.escalate(a, on: today)
        try taskService.escalate(b, on: today)
        try taskService.escalate(c, on: today)

        taskService.reorderTop3(on: today, ids: [c.id, a.id, b.id])
        XCTAssertEqual(today.top3ItemIDs, [c.id, a.id, b.id])
    }

    func testDeleteRemovesFromTop3() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let today = dayService.day(for: date(2026, 5, 22))

        let a = taskService.addBrainDumpItem(title: "A", on: today)
        try taskService.escalate(a, on: today)
        taskService.delete(a)

        XCTAssertTrue(today.top3ItemIDs.isEmpty)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TaskServiceTests`
Expected: compile error — `escalate`, `deescalate`, `reorderTop3` not defined.

- [ ] **Step 3: Extend `TaskService`**

Append to `TaskService`:

```swift
    func escalate(_ item: TaskItem, on day: Day) throws {
        if day.top3ItemIDs.contains(item.id) { return }
        guard day.top3ItemIDs.count < 3 else { throw TodoError.top3Full }
        day.top3ItemIDs.append(item.id)
        try? context.save()
    }

    func deescalate(_ item: TaskItem, on day: Day) {
        day.top3ItemIDs.removeAll { $0 == item.id }
        try? context.save()
    }

    func reorderTop3(on day: Day, ids: [UUID]) {
        let existing = Set(day.top3ItemIDs)
        let filtered = ids.filter { existing.contains($0) }
        guard Set(filtered) == existing else { return }
        day.top3ItemIDs = filtered
        try? context.save()
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TaskServiceTests`
Expected: 9 tests pass (3 from Task 3 + 6 new).

- [ ] **Step 5: Commit**

```bash
git add Sources/todoosx/Services/TaskService.swift Tests/todoosxTests/TaskServiceTests.swift
git commit -m "feat: TaskService top-3 escalate, de-escalate, reorder"
```

---

## Task 5: `ScheduleService` — schedule with range & conflict checks

**Files:**
- Create: `Sources/todoosx/Services/ScheduleService.swift`
- Create: `Tests/todoosxTests/ScheduleServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/todoosxTests/ScheduleServiceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import todoosx

@MainActor
final class ScheduleServiceTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: .current, year: y, month: m, day: d).date!
    }

    private func setup() throws -> (ModelContext, DayService, TaskService, ScheduleService, Day) {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let day = dayService.day(for: date(2026, 5, 22))
        return (context, dayService, taskService, scheduleService, day)
    }

    func testScheduleSingleHourCreatesEntry() throws {
        let (_, _, taskService, scheduleService, day) = try setup()
        let item = taskService.addBrainDumpItem(title: "Write spec", on: day)

        let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1)

        XCTAssertEqual(entry.startHour, 9)
        XCTAssertEqual(entry.durationHours, 1)
        XCTAssertEqual(entry.item?.id, item.id)
        XCTAssertEqual(entry.day?.date, day.date)
        XCTAssertEqual(day.schedule.count, 1)
    }

    func testScheduleMultiHourCreatesSpanningEntry() throws {
        let (_, _, taskService, scheduleService, day) = try setup()
        let item = taskService.addBrainDumpItem(title: "Write spec", on: day)

        let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 3)

        XCTAssertEqual(entry.durationHours, 3)
        XCTAssertEqual(day.schedule.count, 1)
    }

    func testScheduleRejectsStartHourBefore5() throws {
        let (_, _, taskService, scheduleService, day) = try setup()
        let item = taskService.addBrainDumpItem(title: "Too early", on: day)

        XCTAssertThrowsError(try scheduleService.schedule(item, on: day, startHour: 4, durationHours: 1)) {
            XCTAssertEqual($0 as? TodoError, .scheduleOutOfRange)
        }
    }

    func testScheduleRejectsEndAfter24() throws {
        let (_, _, taskService, scheduleService, day) = try setup()
        let item = taskService.addBrainDumpItem(title: "Too late", on: day)

        XCTAssertThrowsError(try scheduleService.schedule(item, on: day, startHour: 23, durationHours: 2)) {
            XCTAssertEqual($0 as? TodoError, .scheduleOutOfRange)
        }
    }

    func testScheduleAllowsBoundaryEnd() throws {
        let (_, _, taskService, scheduleService, day) = try setup()
        let item = taskService.addBrainDumpItem(title: "Last block", on: day)

        let entry = try scheduleService.schedule(item, on: day, startHour: 23, durationHours: 1)
        XCTAssertEqual(entry.startHour, 23)
        XCTAssertEqual(entry.durationHours, 1)
    }

    func testScheduleRejectsZeroOrNegativeDuration() throws {
        let (_, _, taskService, scheduleService, day) = try setup()
        let item = taskService.addBrainDumpItem(title: "Zero", on: day)

        XCTAssertThrowsError(try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 0)) {
            XCTAssertEqual($0 as? TodoError, .scheduleOutOfRange)
        }
    }

    func testScheduleRejectsOverlap() throws {
        let (_, _, taskService, scheduleService, day) = try setup()
        let a = taskService.addBrainDumpItem(title: "A", on: day)
        let b = taskService.addBrainDumpItem(title: "B", on: day)
        _ = try scheduleService.schedule(a, on: day, startHour: 9, durationHours: 3) // 9-12

        XCTAssertThrowsError(try scheduleService.schedule(b, on: day, startHour: 10, durationHours: 1)) {
            XCTAssertEqual($0 as? TodoError, .scheduleConflict)
        }
        XCTAssertThrowsError(try scheduleService.schedule(b, on: day, startHour: 11, durationHours: 2)) {
            XCTAssertEqual($0 as? TodoError, .scheduleConflict)
        }
        XCTAssertThrowsError(try scheduleService.schedule(b, on: day, startHour: 8, durationHours: 2)) {
            XCTAssertEqual($0 as? TodoError, .scheduleConflict)
        }
    }

    func testScheduleAllowsAdjacentBlocks() throws {
        let (_, _, taskService, scheduleService, day) = try setup()
        let a = taskService.addBrainDumpItem(title: "A", on: day)
        let b = taskService.addBrainDumpItem(title: "B", on: day)
        _ = try scheduleService.schedule(a, on: day, startHour: 9, durationHours: 1)  // [9,10)
        _ = try scheduleService.schedule(b, on: day, startHour: 10, durationHours: 1) // [10,11)

        XCTAssertEqual(day.schedule.count, 2)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ScheduleServiceTests`
Expected: compile error — `ScheduleService` not defined.

- [ ] **Step 3: Implement `ScheduleService.schedule`**

`Sources/todoosx/Services/ScheduleService.swift`:

```swift
import Foundation
import SwiftData

@MainActor
final class ScheduleService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func schedule(_ item: TaskItem, on day: Day, startHour: Int, durationHours: Int) throws -> ScheduleEntry {
        guard durationHours >= 1, startHour >= 5, startHour + durationHours <= 24 else {
            throw TodoError.scheduleOutOfRange
        }
        let newRange = startHour..<(startHour + durationHours)
        for existing in day.schedule {
            let existingRange = existing.startHour..<(existing.startHour + existing.durationHours)
            if newRange.overlaps(existingRange) {
                throw TodoError.scheduleConflict
            }
        }
        let entry = ScheduleEntry(startHour: startHour, durationHours: durationHours, item: item, day: day)
        context.insert(entry)
        try? context.save()
        return entry
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ScheduleServiceTests`
Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/todoosx/Services/ScheduleService.swift Tests/todoosxTests/ScheduleServiceTests.swift
git commit -m "feat: ScheduleService.schedule with range and conflict checks"
```

---

## Task 6: `ScheduleService` — unschedule & toggle completion

**Files:**
- Modify: `Sources/todoosx/Services/ScheduleService.swift`
- Modify: `Tests/todoosxTests/ScheduleServiceTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `ScheduleServiceTests`:

```swift
    func testUnscheduleDeletesEntryKeepsItem() throws {
        let (context, _, taskService, scheduleService, day) = try setup()
        let item = taskService.addBrainDumpItem(title: "A", on: day)
        let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1)

        scheduleService.unschedule(entry)

        XCTAssertEqual(day.schedule.count, 0)
        let items = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(items.count, 1)
    }

    func testSetCompletedTogglesFlag() throws {
        let (_, _, taskService, scheduleService, day) = try setup()
        let item = taskService.addBrainDumpItem(title: "A", on: day)
        let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1)
        XCTAssertFalse(entry.isCompleted)

        scheduleService.setCompleted(entry, true)
        XCTAssertTrue(entry.isCompleted)
        scheduleService.setCompleted(entry, false)
        XCTAssertFalse(entry.isCompleted)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ScheduleServiceTests`
Expected: compile error — `unschedule`, `setCompleted` not defined.

- [ ] **Step 3: Extend `ScheduleService`**

Append to `ScheduleService`:

```swift
    func unschedule(_ entry: ScheduleEntry) {
        context.delete(entry)
        try? context.save()
    }

    func setCompleted(_ entry: ScheduleEntry, _ completed: Bool) {
        entry.isCompleted = completed
        try? context.save()
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ScheduleServiceTests`
Expected: 10 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/todoosx/Services/ScheduleService.swift Tests/todoosxTests/ScheduleServiceTests.swift
git commit -m "feat: ScheduleService unschedule and setCompleted"
```

---

## Task 7: `DayService.rollover` — basic case

**Files:**
- Modify: `Sources/todoosx/Services/DayService.swift`
- Modify: `Tests/todoosxTests/DayServiceTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `DayServiceTests`:

```swift
    func testRolloverMovesUncompletedItemsToToday() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let yesterday = dayService.day(for: date(2026, 5, 21))
        let item = taskService.addBrainDumpItem(title: "Leftover", on: yesterday)

        dayService.rollover(now: date(2026, 5, 22))

        let today = dayService.day(for: date(2026, 5, 22))
        XCTAssertEqual(today.items.count, 1)
        XCTAssertEqual(today.items.first?.id, item.id)
        XCTAssertEqual(yesterday.items.count, 0)
    }

    func testRolloverLeavesCompletedItemsBehind() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let yesterday = dayService.day(for: date(2026, 5, 21))
        let done = taskService.addBrainDumpItem(title: "Done", on: yesterday)
        let entry = try scheduleService.schedule(done, on: yesterday, startHour: 9, durationHours: 1)
        scheduleService.setCompleted(entry, true)

        dayService.rollover(now: date(2026, 5, 22))

        XCTAssertEqual(yesterday.items.count, 1)
        XCTAssertEqual(yesterday.items.first?.id, done.id)
        XCTAssertEqual(yesterday.schedule.count, 1)
        XCTAssertTrue(yesterday.schedule.first?.isCompleted ?? false)
    }

    func testRolloverIsIdempotent() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let yesterday = dayService.day(for: date(2026, 5, 21))
        taskService.addBrainDumpItem(title: "Leftover", on: yesterday)

        dayService.rollover(now: date(2026, 5, 22))
        dayService.rollover(now: date(2026, 5, 22))

        let today = dayService.day(for: date(2026, 5, 22))
        XCTAssertEqual(today.items.count, 1)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter DayServiceTests`
Expected: compile error — `rollover` not defined.

- [ ] **Step 3: Implement `DayService.rollover`**

Append to `DayService`:

```swift
    func rollover(now: Date) {
        let today = now.startOfLocalDay()
        let todayDay = day(for: today)

        let pastDescriptor = FetchDescriptor<Day>(
            predicate: #Predicate<Day> { $0.date < today }
        )
        guard let pastDays = try? context.fetch(pastDescriptor) else { return }

        for past in pastDays {
            // Snapshot current items to avoid mutation while iterating.
            let itemsSnapshot = past.items
            for item in itemsSnapshot {
                let completedHere = past.schedule.contains { $0.item?.id == item.id && $0.isCompleted }
                if completedHere { continue }

                // Remove any of this item's schedule entries on `past`.
                let toRemove = past.schedule.filter { $0.item?.id == item.id }
                for e in toRemove { context.delete(e) }

                // Remove from top 3 if present.
                past.top3ItemIDs.removeAll { $0 == item.id }

                // Move item to today.
                item.day = todayDay
            }
        }
        try? context.save()
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DayServiceTests`
Expected: 6 tests pass (3 from Task 2 + 3 new).

- [ ] **Step 5: Commit**

```bash
git add Sources/todoosx/Services/DayService.swift Tests/todoosxTests/DayServiceTests.swift
git commit -m "feat: DayService.rollover moves uncompleted items forward"
```

---

## Task 8: `DayService.rollover` — multi-day gap & top-3 hygiene

**Files:**
- Modify: `Tests/todoosxTests/DayServiceTests.swift`

(No source changes — the algorithm already handles these cases; the tests pin them down.)

- [ ] **Step 1: Add failing tests (which should actually pass — write them anyway as regression guards)**

Append to `DayServiceTests`:

```swift
    func testRolloverHandlesMultiDayGap() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let day19 = dayService.day(for: date(2026, 5, 19))
        let day20 = dayService.day(for: date(2026, 5, 20))
        let day21 = dayService.day(for: date(2026, 5, 21))
        let a = taskService.addBrainDumpItem(title: "From 19", on: day19)
        let b = taskService.addBrainDumpItem(title: "From 20", on: day20)
        let c = taskService.addBrainDumpItem(title: "From 21", on: day21)

        dayService.rollover(now: date(2026, 5, 22))

        let today = dayService.day(for: date(2026, 5, 22))
        let ids = Set(today.items.map(\.id))
        XCTAssertEqual(ids, Set([a.id, b.id, c.id]))
        XCTAssertTrue(day19.items.isEmpty)
        XCTAssertTrue(day20.items.isEmpty)
        XCTAssertTrue(day21.items.isEmpty)
    }

    func testRolloverRemovesMovedItemFromYesterdayTop3() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let yesterday = dayService.day(for: date(2026, 5, 21))
        let item = taskService.addBrainDumpItem(title: "Top", on: yesterday)
        try taskService.escalate(item, on: yesterday)
        XCTAssertEqual(yesterday.top3ItemIDs, [item.id])

        dayService.rollover(now: date(2026, 5, 22))

        XCTAssertTrue(yesterday.top3ItemIDs.isEmpty)
    }

    func testRolloverKeepsTop3EntryForCompletedItem() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let yesterday = dayService.day(for: date(2026, 5, 21))
        let done = taskService.addBrainDumpItem(title: "Top done", on: yesterday)
        try taskService.escalate(done, on: yesterday)
        let entry = try scheduleService.schedule(done, on: yesterday, startHour: 9, durationHours: 1)
        scheduleService.setCompleted(entry, true)

        dayService.rollover(now: date(2026, 5, 22))

        XCTAssertEqual(yesterday.top3ItemIDs, [done.id])
    }
```

- [ ] **Step 2: Run tests**

Run: `swift test --filter DayServiceTests`
Expected: 9 tests pass. (If any new test fails, fix `rollover` and re-run.)

- [ ] **Step 3: Commit**

```bash
git add Tests/todoosxTests/DayServiceTests.swift
git commit -m "test: pin down rollover multi-day and top-3 behavior"
```

---

## Task 9: `AppState` — current date + launch rollover

**Files:**
- Create: `Sources/todoosx/App/AppState.swift`
- Create: `Tests/todoosxTests/AppStateTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/todoosxTests/AppStateTests.swift`:

```swift
import XCTest
import SwiftData
@testable import todoosx

@MainActor
final class AppStateTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: .current, year: y, month: m, day: d).date!
    }

    func testInitRollsOverPastDays() throws {
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let yesterday = dayService.day(for: date(2026, 5, 21))
        taskService.addBrainDumpItem(title: "Carry me", on: yesterday)

        let state = AppState(context: context, now: { self.date(2026, 5, 22) })

        let today = dayService.day(for: state.selectedDate)
        XCTAssertEqual(today.items.count, 1)
    }

    func testGoBackThenForwardChangesSelectedDate() throws {
        let context = try InMemoryStore.makeContext()
        let state = AppState(context: context, now: { self.date(2026, 5, 22) })

        state.goToPreviousDay()
        XCTAssertEqual(state.selectedDate, date(2026, 5, 21))

        state.goToToday()
        XCTAssertEqual(state.selectedDate, date(2026, 5, 22))
    }

    func testCannotGoToFutureBeyondToday() throws {
        let context = try InMemoryStore.makeContext()
        let state = AppState(context: context, now: { self.date(2026, 5, 22) })

        state.goToNextDay()
        XCTAssertEqual(state.selectedDate, date(2026, 5, 22),
            "Next from today should clamp at today (no future days in first pass).")
    }

    func testIsTodayReflectsSelectedDate() throws {
        let context = try InMemoryStore.makeContext()
        let state = AppState(context: context, now: { self.date(2026, 5, 22) })
        XCTAssertTrue(state.isToday)
        state.goToPreviousDay()
        XCTAssertFalse(state.isToday)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AppStateTests`
Expected: compile error — `AppState` not defined.

- [ ] **Step 3: Implement `AppState`**

`Sources/todoosx/App/AppState.swift`:

```swift
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class AppState {
    private let context: ModelContext
    private let now: () -> Date
    private let dayService: DayService

    private(set) var todayDate: Date
    var selectedDate: Date

    init(context: ModelContext, now: @escaping () -> Date = { Date() }) {
        self.context = context
        self.now = now
        self.dayService = DayService(context: context)
        let today = now().startOfLocalDay()
        self.todayDate = today
        self.selectedDate = today
        self.dayService.rollover(now: today)
    }

    var isToday: Bool { selectedDate == todayDate }
    var isPast: Bool { selectedDate < todayDate }

    func goToPreviousDay() {
        let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        selectedDate = prev.startOfLocalDay()
    }

    func goToNextDay() {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!.startOfLocalDay()
        if next > todayDate { return }
        selectedDate = next
    }

    func goToToday() {
        selectedDate = todayDate
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter AppStateTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/todoosx/App/AppState.swift Tests/todoosxTests/AppStateTests.swift
git commit -m "feat: AppState owns selected date and triggers launch rollover"
```

---

## Task 10: App entry point & AppShell view

**Files:**
- Create: `Sources/todoosx/App/TodoosxApp.swift`
- Create: `Sources/todoosx/Views/AppShell.swift`
- Create: `Sources/todoosx/Views/DayView.swift`

(No tests for views in this first pass — exercised manually via `swift run`.)

- [ ] **Step 1: Implement the app entry point**

`Sources/todoosx/App/TodoosxApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct TodoosxApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Day.self, TaskItem.self, ScheduleEntry.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("todoosx") {
            AppShell()
                .frame(minWidth: 900, minHeight: 700)
        }
        .modelContainer(container)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}
```

- [ ] **Step 2: Implement `AppShell` (header + DayView)**

`Sources/todoosx/Views/AppShell.swift`:

```swift
import SwiftUI
import SwiftData

struct AppShell: View {
    @Environment(\.modelContext) private var context
    @State private var state: AppState?

    var body: some View {
        Group {
            if let state {
                VStack(spacing: 0) {
                    DateHeader(state: state)
                    Divider()
                    DayView(state: state)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if state == nil { state = AppState(context: context) }
        }
    }
}

private struct DateHeader: View {
    @Bindable var state: AppState

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .full
        return f.string(from: state.selectedDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: state.goToPreviousDay) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Text(formattedDate)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity)

            Button(action: state.goToNextDay) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(state.isToday)

            Button("Today", action: state.goToToday)
                .disabled(state.isToday)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}
```

- [ ] **Step 3: Implement `DayView` (empty shell — sections come in later tasks)**

`Sources/todoosx/Views/DayView.swift`:

```swift
import SwiftUI
import SwiftData

struct DayView: View {
    @Environment(\.modelContext) private var context
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                placeholderSection("Brain Dump")
                Divider()
                placeholderSection("Top 3")
            }
            .frame(maxHeight: .infinity)
            Divider()
            placeholderSection("Schedule")
                .frame(maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func placeholderSection(_ title: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 4: Run tests (no test changes; confirm nothing broke)**

Run: `swift test`
Expected: all prior tests still pass.

- [ ] **Step 5: Build the executable to confirm it compiles**

Run: `swift build`
Expected: build succeeds, no errors.

- [ ] **Step 6: Commit**

```bash
git add Sources/todoosx/App/TodoosxApp.swift Sources/todoosx/Views/AppShell.swift Sources/todoosx/Views/DayView.swift
git commit -m "feat: app entry, AppShell, DayView shell with date navigation"
```

---

## Task 11: `BrainDumpSection` view

**Files:**
- Create: `Sources/todoosx/Views/BrainDumpSection.swift`
- Modify: `Sources/todoosx/Views/DayView.swift`

(View-only task — manual visual verification at the end.)

- [ ] **Step 1: Implement `BrainDumpSection`**

`Sources/todoosx/Views/BrainDumpSection.swift`:

```swift
import SwiftUI
import SwiftData

struct BrainDumpSection: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool

    @State private var newTitle: String = ""
    @State private var editingID: UUID?
    @State private var editingDraft: String = ""

    private var taskService: TaskService { TaskService(context: context) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Brain Dump")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 4)

            ForEach(day.items, id: \.id) { item in
                row(for: item)
            }

            if !isReadOnly {
                HStack {
                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                    TextField("Add to brain dump", text: $newTitle)
                        .textFieldStyle(.plain)
                        .onSubmit(submitNew)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(for item: TaskItem) -> some View {
        HStack {
            Circle()
                .stroke(Color.secondary, lineWidth: 1)
                .frame(width: 12, height: 12)
            if editingID == item.id {
                TextField("Title", text: $editingDraft)
                    .textFieldStyle(.plain)
                    .onSubmit { commitEdit(item) }
            } else {
                Text(item.title)
                    .onTapGesture(count: 2) {
                        if !isReadOnly {
                            editingID = item.id
                            editingDraft = item.title
                        }
                    }
            }
            Spacer()
            if !isReadOnly {
                Button {
                    taskService.delete(item)
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .opacity(0.6)
            }
        }
        .padding(.vertical, 4)
    }

    private func submitNew() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        taskService.addBrainDumpItem(title: trimmed, on: day)
        newTitle = ""
    }

    private func commitEdit(_ item: TaskItem) {
        let trimmed = editingDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { taskService.rename(item, to: trimmed) }
        editingID = nil
    }
}
```

- [ ] **Step 2: Wire `BrainDumpSection` into `DayView`**

Replace `DayView.body` with:

```swift
    var body: some View {
        let dayService = DayService(context: context)
        let day = dayService.day(for: state.selectedDate)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                BrainDumpSection(day: day, isReadOnly: state.isPast)
                Divider()
                placeholderSection("Top 3")
            }
            .frame(maxHeight: .infinity)
            Divider()
            placeholderSection("Schedule")
                .frame(maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
```

- [ ] **Step 3: Run tests + build**

Run: `swift test && swift build`
Expected: all tests pass, build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/todoosx/Views/BrainDumpSection.swift Sources/todoosx/Views/DayView.swift
git commit -m "feat: BrainDumpSection with add/edit/delete"
```

---

## Task 12: `Top3Section` view

**Files:**
- Create: `Sources/todoosx/Views/Top3Section.swift`
- Modify: `Sources/todoosx/Views/DayView.swift`

- [ ] **Step 1: Implement `Top3Section`**

`Sources/todoosx/Views/Top3Section.swift`:

```swift
import SwiftUI
import SwiftData

struct Top3Section: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool

    private var taskService: TaskService { TaskService(context: context) }

    private var top3Items: [TaskItem?] {
        var slots: [TaskItem?] = [nil, nil, nil]
        for (i, id) in day.top3ItemIDs.prefix(3).enumerated() {
            slots[i] = day.items.first { $0.id == id }
        }
        return slots
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top 3")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 4)

            ForEach(Array(top3Items.enumerated()), id: \.offset) { idx, item in
                slotRow(index: idx, item: item)
            }

            if !isReadOnly {
                Text("Tip: tap the star next to a brain-dump item to escalate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func slotRow(index: Int, item: TaskItem?) -> some View {
        HStack {
            Text("\(index + 1).")
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .leading)
            if let item {
                Text(item.title)
                Spacer()
                if !isReadOnly {
                    Button {
                        taskService.deescalate(item, on: day)
                    } label: {
                        Image(systemName: "star.slash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("(empty)")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 2: Add an escalate button to `BrainDumpSection`**

In `BrainDumpSection.row(for:)`, between the title `Text` / `TextField` and the delete `Button`, insert (when `!isReadOnly`):

```swift
            if !isReadOnly {
                Button {
                    try? taskService.escalate(item, on: day)
                } label: {
                    Image(systemName: day.top3ItemIDs.contains(item.id) ? "star.fill" : "star")
                        .foregroundStyle(day.top3ItemIDs.contains(item.id) ? Color.yellow : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(!day.top3ItemIDs.contains(item.id) && day.top3ItemIDs.count >= 3)
            }
```

(Place it after the title and before the delete button, both wrapped in `if !isReadOnly`. The delete button keeps its own `if !isReadOnly` block; consider folding both into one. Either is fine.)

- [ ] **Step 3: Wire `Top3Section` into `DayView`**

Replace `placeholderSection("Top 3")` with:

```swift
                Top3Section(day: day, isReadOnly: state.isPast)
```

- [ ] **Step 4: Run tests + build**

Run: `swift test && swift build`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/todoosx/Views/Top3Section.swift Sources/todoosx/Views/BrainDumpSection.swift Sources/todoosx/Views/DayView.swift
git commit -m "feat: Top3Section + escalate toggle in brain dump"
```

---

## Task 13: `ScheduleSection` with drag-to-schedule and duration prompt

**Files:**
- Create: `Sources/todoosx/Views/ScheduleSection.swift`
- Create: `Sources/todoosx/Views/ScheduleBlockView.swift`
- Create: `Sources/todoosx/Views/DurationPromptSheet.swift`
- Modify: `Sources/todoosx/Views/DayView.swift`
- Modify: `Sources/todoosx/Views/BrainDumpSection.swift`
- Modify: `Sources/todoosx/Views/Top3Section.swift`

- [ ] **Step 1: Make `TaskItem` transferable for drag**

`Sources/todoosx/Models/TaskItem.swift` — append (outside the class):

```swift
import CoreTransferable

struct TaskItemDragPayload: Codable, Transferable {
    let id: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}
```

- [ ] **Step 2: Implement `DurationPromptSheet`**

`Sources/todoosx/Views/DurationPromptSheet.swift`:

```swift
import SwiftUI

struct DurationPromptSheet: View {
    let startHour: Int
    let maxDuration: Int
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void

    @State private var duration: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How long for this task?")
                .font(.headline)
            Text("Starting at \(formattedHour(startHour))")
                .foregroundStyle(.secondary)

            HStack {
                ForEach(1...min(4, maxDuration), id: \.self) { value in
                    Button("\(value)h") { duration = value }
                        .buttonStyle(.bordered)
                        .tint(duration == value ? .accentColor : .secondary)
                }
                Stepper(value: $duration, in: 1...maxDuration) {
                    Text("\(duration) hour\(duration == 1 ? "" : "s")")
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Schedule") { onConfirm(duration) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func formattedHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h) \(suffix)"
    }
}
```

- [ ] **Step 3: Implement `ScheduleBlockView`**

`Sources/todoosx/Views/ScheduleBlockView.swift`:

```swift
import SwiftUI

struct ScheduleBlockView: View {
    let entry: ScheduleEntry
    let isReadOnly: Bool
    let onToggleComplete: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggleComplete) {
                Image(systemName: entry.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(entry.isCompleted ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .disabled(isReadOnly)

            Text(entry.item?.title ?? "(deleted)")
                .strikethrough(entry.isCompleted)
                .foregroundStyle(entry.isCompleted ? .secondary : .primary)

            Spacer()

            if !isReadOnly {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(entry.isCompleted ? 0.10 : 0.18))
        )
    }
}
```

- [ ] **Step 4: Implement `ScheduleSection`**

`Sources/todoosx/Views/ScheduleSection.swift`:

```swift
import SwiftUI
import SwiftData

struct ScheduleSection: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool

    private let hours = Array(5...23)
    private let rowHeight: CGFloat = 44

    @State private var pending: (hour: Int, itemID: UUID)?
    @State private var errorText: String?

    private var scheduleService: ScheduleService { ScheduleService(context: context) }

    private func entry(at hour: Int) -> ScheduleEntry? {
        day.schedule.first { $0.startHour <= hour && hour < $0.startHour + $0.durationHours }
    }

    private func startsAt(_ hour: Int) -> ScheduleEntry? {
        day.schedule.first { $0.startHour == hour }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Schedule")
                    .font(.title3.weight(.semibold))
                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.leading, 8)
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { hour in
                        hourRow(hour: hour)
                    }
                }
            }
        }
        .padding(16)
        .sheet(isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            if let pending {
                DurationPromptSheet(
                    startHour: pending.hour,
                    maxDuration: 24 - pending.hour,
                    onConfirm: { duration in
                        confirmSchedule(itemID: pending.itemID, hour: pending.hour, duration: duration)
                    },
                    onCancel: { self.pending = nil }
                )
            }
        }
    }

    private func hourRow(hour: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label(for: hour))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)

            if let starting = startsAt(hour) {
                ScheduleBlockView(
                    entry: starting,
                    isReadOnly: isReadOnly,
                    onToggleComplete: { scheduleService.setCompleted(starting, !starting.isCompleted) },
                    onRemove: { scheduleService.unschedule(starting) }
                )
                .frame(height: rowHeight * CGFloat(starting.durationHours) - 6)
            } else if entry(at: hour) != nil {
                Color.clear.frame(height: rowHeight - 6)
            } else {
                emptySlot(hour: hour)
            }
        }
        .frame(minHeight: rowHeight, alignment: .top)
    }

    private func emptySlot(hour: Int) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3,3]))
            .frame(height: rowHeight - 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .dropDestination(for: TaskItemDragPayload.self) { payloads, _ in
                guard !isReadOnly, let p = payloads.first else { return false }
                pending = (hour: hour, itemID: p.id)
                return true
            }
    }

    private func confirmSchedule(itemID: UUID, hour: Int, duration: Int) {
        defer { pending = nil }
        guard let item = day.items.first(where: { $0.id == itemID }) else {
            errorText = "Item not on this day"
            return
        }
        do {
            _ = try scheduleService.schedule(item, on: day, startHour: hour, durationHours: duration)
            errorText = nil
        } catch TodoError.scheduleConflict {
            errorText = "Conflicts with another block"
        } catch TodoError.scheduleOutOfRange {
            errorText = "Out of range"
        } catch {
            errorText = "Could not schedule"
        }
    }

    private func label(for hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h) \(hour < 12 ? "AM" : "PM")"
    }
}
```

- [ ] **Step 5: Make brain-dump and top-3 rows draggable**

In `BrainDumpSection.row(for:)`, wrap the row body with `.draggable(TaskItemDragPayload(id: item.id))` when `!isReadOnly`.

Concretely, at the end of `row(for:)`, append (where the modifier chain currently ends with `.padding(.vertical, 4)`):

```swift
        .draggable(TaskItemDragPayload(id: item.id))
```

(`.draggable` requires the row to be a `some View`; place it after `.padding`.)

In `Top3Section.slotRow(index:item:)`, do the same when `item != nil` and `!isReadOnly`:

```swift
        .if(item != nil && !isReadOnly) { $0.draggable(TaskItemDragPayload(id: item!.id)) }
```

If you don't want to add a `.if` view extension, just gate the entire row inline:

```swift
        Group {
            if let item, !isReadOnly {
                rowBody.draggable(TaskItemDragPayload(id: item.id))
            } else {
                rowBody
            }
        }
```

Pick whichever is least invasive given current code shape.

- [ ] **Step 6: Wire `ScheduleSection` into `DayView`**

Replace `placeholderSection("Schedule")` with:

```swift
                ScheduleSection(day: day, isReadOnly: state.isPast)
```

- [ ] **Step 7: Run tests + build**

Run: `swift test && swift build`
Expected: pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/todoosx/Views/ScheduleSection.swift Sources/todoosx/Views/ScheduleBlockView.swift Sources/todoosx/Views/DurationPromptSheet.swift Sources/todoosx/Views/BrainDumpSection.swift Sources/todoosx/Views/Top3Section.swift Sources/todoosx/Views/DayView.swift Sources/todoosx/Models/TaskItem.swift
git commit -m "feat: ScheduleSection with drag-to-schedule and duration prompt"
```

---

## Task 14: Visual polish — scheduled tint, completed strikethrough, read-only past

**Files:**
- Modify: `Sources/todoosx/Views/BrainDumpSection.swift`
- Modify: `Sources/todoosx/Views/Top3Section.swift`

- [ ] **Step 1: Add `isScheduledToday(_:)` and `isCompletedToday(_:)` helpers**

In `BrainDumpSection`, add private methods:

```swift
    private func isScheduled(_ item: TaskItem) -> Bool {
        day.schedule.contains { $0.item?.id == item.id }
    }

    private func isCompleted(_ item: TaskItem) -> Bool {
        day.schedule.contains { $0.item?.id == item.id && $0.isCompleted }
    }
```

- [ ] **Step 2: Apply tinted background and strikethrough**

In `BrainDumpSection.row(for:)`, change the row's `Text(item.title)` (and the read-only branch in editing flow) to:

```swift
                Text(item.title)
                    .strikethrough(isCompleted(item))
                    .foregroundStyle(isCompleted(item) ? .secondary : .primary)
                    .onTapGesture(count: 2) { /* unchanged */ }
```

And wrap the whole row's `.padding(.vertical, 4)` with a tint when scheduled:

```swift
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            isScheduled(item)
                ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.08))
                : RoundedRectangle(cornerRadius: 6).fill(Color.clear)
        )
```

(Adjust to fit the existing modifier chain — the rule is: when `isScheduled`, the row has a faint accent tint; when `isCompleted`, the title is struck through and gray.)

- [ ] **Step 3: Do the same in `Top3Section.slotRow`**

Mirror the changes (helpers + strikethrough + tint background) for the top-3 row when an item is present.

- [ ] **Step 4: Run tests + build**

Run: `swift test && swift build`
Expected: pass.

- [ ] **Step 5: Manual visual check**

Run: `swift run todoosx`
Expected: window opens. Add 3 brain-dump items, escalate one to top 3, drag one onto a schedule slot, confirm duration. Verify:
- Scheduled item has tinted background in both brain dump and top 3.
- Checking the schedule block strikes through both the brain-dump row and the top-3 row.
- Navigating back a day shows no add/edit/delete UI and no drag handles.

If any UI doesn't behave as expected, fix and re-test before committing.

- [ ] **Step 6: Commit**

```bash
git add Sources/todoosx/Views/BrainDumpSection.swift Sources/todoosx/Views/Top3Section.swift
git commit -m "feat: visual polish — scheduled tint, completed strikethrough, read-only past"
```

---

## After all tasks

Final verification:

```bash
swift test            # all tests pass
swift build           # builds without warnings
swift run todoosx     # app launches; smoke-test the full flow:
                      # add → escalate → drag → schedule → complete → next-day rollover
                      # (simulate next-day by relaunching after midnight, or temporarily
                      #  injecting a custom `now` in TodoosxApp during local testing)
```

If everything passes and looks right, the goal is met. No further task list at this point.
