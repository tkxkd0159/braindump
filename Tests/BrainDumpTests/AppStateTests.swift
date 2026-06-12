import Foundation
import Testing
import SwiftData
@testable import BrainDumpKit

@MainActor
@Test func appInitRollsOverPastDays() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let yesterday = dayService.day(for: TestDate.at(2026, 5, 21))
    _ = taskService.addBrainDumpItem(title: "Carry me", on: yesterday)

    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) })

    let today = dayService.day(for: state.selectedDate)
    #expect(today.items.count == 1)
}

@MainActor
@Test func goBackThenForwardChangesSelectedDate() throws {
    let context = try InMemoryStore.makeContext()
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) })

    state.goToPreviousDay()
    #expect(state.selectedDate == TestDate.at(2026, 5, 21))

    state.goToToday()
    #expect(state.selectedDate == TestDate.at(2026, 5, 22))
}

@MainActor
@Test func cannotGoToFutureBeyondToday() throws {
    let context = try InMemoryStore.makeContext()
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) })

    state.goToNextDay()
    #expect(state.selectedDate == TestDate.at(2026, 5, 22))
}

@MainActor
@Test func clearAllDataIncrementsDataGeneration() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) }, defaults: defaults)

    let before = state.dataGeneration
    state.clearAllData()

    #expect(state.dataGeneration == before + 1)
}

@MainActor
@Test func importBackupReplacesDataAndBumpsGeneration() throws {
    // Source data exported from one context.
    let source = try InMemoryStore.makeContext()
    let sDay = DayService(context: source).day(for: TestDate.at(2026, 5, 22))
    _ = TaskService(context: source).addBrainDumpItem(title: "Imported task", on: sDay)
    let data = try BackupService(context: source).exportData()

    // Target AppState with its own (different) data.
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) }, defaults: defaults)
    _ = TaskService(context: context).addBrainDumpItem(
        title: "OLD", on: DayService(context: context).day(for: TestDate.at(2026, 5, 22)))
    let before = state.dataGeneration

    state.selectedDestination = .backlog
    try state.importBackup(from: data)

    #expect(state.dataGeneration == before + 1)
    #expect(state.selectedDestination == .today)
    let titles = try context.fetch(FetchDescriptor<TaskItem>()).map(\.title)
    #expect(titles == ["Imported task"])
    #expect(try !state.exportBackupData().isEmpty)
}

@MainActor
@Test func isTodayReflectsSelectedDate() throws {
    let context = try InMemoryStore.makeContext()
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) })
    #expect(state.isToday)
    state.goToPreviousDay()
    #expect(!state.isToday)
}

@MainActor
@Test func defaultDayBoundsAre5To22() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) }, defaults: defaults)
    #expect(state.dayStartHour == 5)
    #expect(state.dayEndHour == 22)
    #expect(state.dayStartMinute == 300)
    #expect(state.dayEndMinute == 1320)
}

@MainActor
@Test func setDayBoundsRejectsTooShortSpan() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) }, defaults: defaults)
    #expect(state.setDayBounds(startHour: 8, endHour: 10) == false)
    #expect(state.dayStartHour == 5)
    #expect(state.dayEndHour == 22)
}

@MainActor
@Test func setDayBoundsAcceptsValidSpan() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) }, defaults: defaults)
    #expect(state.setDayBounds(startHour: 7, endHour: 19))
    #expect(state.dayStartHour == 7)
    #expect(state.dayEndHour == 19)
}

@MainActor
@Test func dayBoundsPersistAcrossInits() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    let first = AppState(context: context, now: { TestDate.at(2026, 5, 22) }, defaults: defaults)
    _ = first.setDayBounds(startHour: 6, endHour: 23)

    let second = AppState(context: context, now: { TestDate.at(2026, 5, 22) }, defaults: defaults)
    #expect(second.dayStartHour == 6)
    #expect(second.dayEndHour == 23)
}

@MainActor
@Test func clearAllDataWipesEverythingAndResetsNavigation() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let backlogService = BacklogService(context: context)
    let day = dayService.day(for: TestDate.at(2026, 5, 22))
    _ = taskService.addBrainDumpItem(title: "Sample", on: day)
    _ = backlogService.addBacklogItem(title: "Backlog item")
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) }, defaults: defaults)
    _ = state.setDayBounds(startHour: 7, endHour: 21)
    state.goToPreviousDay()
    state.selectedDestination = .backlog

    state.clearAllData()

    #expect((try context.fetch(FetchDescriptor<TaskItem>())).isEmpty)
    #expect((try context.fetch(FetchDescriptor<Day>())).isEmpty)
    #expect(state.selectedDate == state.todayDate)
    #expect(state.selectedDestination == .today)
    #expect(state.dayStartHour == 7)
    #expect(state.dayEndHour == 21)
}

@MainActor
@Test func currentMinuteOfDayReflectsInjectedClock() throws {
    let context = try InMemoryStore.makeContext()
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22, hour: 8, minute: 13) })
    #expect(state.currentMinuteOfDay == 8 * 60 + 13)
}

@MainActor
@Test func defaultScheduleStartRoundsUpFromCurrentTime() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    // 8:13 AM, default 5–22 window, nothing scheduled → 8:15 AM.
    let state = AppState(
        context: context, now: { TestDate.at(2026, 5, 22, hour: 8, minute: 13) }, defaults: defaults)
    #expect(state.defaultScheduleStartMinute(occupied: []) == 8 * 60 + 15)
}

@MainActor
@Test func defaultScheduleStartClampsToDayStartBeforeWindow() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    // 3:00 AM with a 5:00 AM day start → 5:00 AM.
    let state = AppState(
        context: context, now: { TestDate.at(2026, 5, 22, hour: 3) }, defaults: defaults)
    #expect(state.defaultScheduleStartMinute(occupied: []) == state.dayStartMinute)
}

@MainActor
@Test func defaultScheduleStartSkipsOccupiedSlot() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    // 8:00 AM but 8:00–9:00 is taken → 9:00 AM.
    let state = AppState(
        context: context, now: { TestDate.at(2026, 5, 22, hour: 8) }, defaults: defaults)
    #expect(state.defaultScheduleStartMinute(occupied: [(8 * 60)..<(9 * 60)]) == 9 * 60)
}

@MainActor
@Test func defaultScheduleStartUsesDayStartWhenViewingAnotherDay() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    let state = AppState(
        context: context, now: { TestDate.at(2026, 5, 22, hour: 8, minute: 13) }, defaults: defaults)
    state.goToPreviousDay()  // selected day is no longer today
    #expect(state.defaultScheduleStartMinute(occupied: []) == state.dayStartMinute)
}

@MainActor
@Test func schedulingAtComputedDefaultAvoidsExistingBlock() throws {
    // End-to-end promise of the "Schedule" menu: the default it computes from
    // the day's occupied ranges can be scheduled without a conflict.
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let scheduleService = ScheduleService(context: context)
    let state = AppState(
        context: context, now: { TestDate.at(2026, 5, 22, hour: 8) }, defaults: defaults)
    let day = dayService.day(for: state.selectedDate)
    let existing = taskService.addBrainDumpItem(title: "Existing", on: day)
    _ = try scheduleService.schedule(existing, on: day, startMinute: 8 * 60, durationMinutes: 60)
    let incoming = taskService.addBrainDumpItem(title: "New", on: day)

    let occupied = day.schedule.map { $0.startMinute..<$0.endMinute }
    let start = state.defaultScheduleStartMinute(occupied: occupied)
    #expect(start == 9 * 60)  // 8:00 is taken, so the default skips to 9:00

    let entry = try scheduleService.schedule(
        incoming, on: day, startMinute: start, durationMinutes: 60)
    #expect(entry.startMinute == 9 * 60)
    #expect(day.schedule.count == 2)
}

@MainActor
@Test func sidebarToggleFlipsVisibility() throws {
    let context = try InMemoryStore.makeContext()
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) })
    #expect(state.isSidebarVisible)
    state.toggleSidebar()
    #expect(!state.isSidebarVisible)
    state.toggleSidebar()
    #expect(state.isSidebarVisible)
}

// MARK: - Sidebar navigation shortcuts (⌘1/⌘2/⌘3)

@MainActor
@Test func selectSidebarItemMapsIndexToDestination() throws {
    let context = try InMemoryStore.makeContext()
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) })

    state.selectSidebarItem(at: 0)
    #expect(state.selectedDestination == .today)
    state.selectSidebarItem(at: 1)
    #expect(state.selectedDestination == .tasks)
    state.selectSidebarItem(at: 2)
    #expect(state.selectedDestination == .backlog)
}

@MainActor
@Test func selectSidebarItemIgnoresOutOfRangeIndex() throws {
    let context = try InMemoryStore.makeContext()
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) })

    state.selectSidebarItem(at: 1)  // .tasks
    state.selectSidebarItem(at: 3)  // past the last item → no change
    #expect(state.selectedDestination == .tasks)
    state.selectSidebarItem(at: -1)  // before the first item → no change
    #expect(state.selectedDestination == .tasks)
}

/// ⌘1/⌘2/⌘3 and the sidebar's top-to-bottom `NavItem`s both depend on this
/// exact order; a reorder must break a test loudly. (Guards an existing
/// invariant the shortcut mapping relies on.)
@Test func sidebarDestinationOrderBacksNumberShortcuts() {
    #expect(SidebarDestination.allCases == [.today, .tasks, .backlog])
}

@MainActor
@Test func appStateExposesInjectedCalendarService() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "test.appstate.cal.\(UUID().uuidString)")!
    let store = CalendarFeedStore(defaults: defaults)
    store.save([CalendarFeed(name: "Work", urlString: "https://x/a.ics")])
    let calendar = CalendarService(
        store: store,
        fetcher: URLSessionICalFeedFetcher(),
        cache: CalendarCache(url: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("as-\(UUID().uuidString).json")),
        now: { TestDate.at(2026, 5, 22) })
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) },
                         defaults: defaults, calendarService: calendar)
    #expect(state.calendar.feeds.map(\.name) == ["Work"])
}

// MARK: - Automatic date refresh (clock crosses into a new local day)

@MainActor
@Test func refreshAdvancesToNewDayWhenViewingToday() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    // App opened just before midnight on the 21st.
    var clock = TestDate.at(2026, 5, 21, hour: 23, minute: 59)
    let state = AppState(context: context, now: { clock }, defaults: defaults)
    #expect(state.todayDate == TestDate.at(2026, 5, 21))
    #expect(state.selectedDate == TestDate.at(2026, 5, 21))
    #expect(state.isToday)
    let genBefore = state.dataGeneration

    // Clock crosses midnight into the 22nd while the app is still open.
    clock = TestDate.at(2026, 5, 22, hour: 0, minute: 1)
    let changed = state.refreshCurrentDate()

    #expect(changed)
    #expect(state.todayDate == TestDate.at(2026, 5, 22))
    // User was viewing "today", so the selection follows forward to the new day.
    #expect(state.selectedDate == TestDate.at(2026, 5, 22))
    #expect(state.isToday)
    #expect(state.dataGeneration == genBefore + 1)
}

@MainActor
@Test func refreshRollsOverUncompletedItemsToNewDay() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let yesterday = dayService.day(for: TestDate.at(2026, 5, 21))
    _ = taskService.addBrainDumpItem(title: "Carry me forward", on: yesterday)

    var clock = TestDate.at(2026, 5, 21, hour: 22)
    let state = AppState(context: context, now: { clock }, defaults: defaults)
    #expect(dayService.day(for: TestDate.at(2026, 5, 21)).items.count == 1)

    clock = TestDate.at(2026, 5, 22, hour: 6)
    #expect(state.refreshCurrentDate())

    // The uncompleted item is re-parented to the new today; the old day is empty.
    let newToday = dayService.day(for: TestDate.at(2026, 5, 22))
    #expect(newToday.items.map(\.title) == ["Carry me forward"])
    #expect(dayService.day(for: TestDate.at(2026, 5, 21)).items.isEmpty)
}

@MainActor
@Test func refreshIsNoOpWhenDayUnchanged() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    var clock = TestDate.at(2026, 5, 22, hour: 9)
    let state = AppState(context: context, now: { clock }, defaults: defaults)
    let genBefore = state.dataGeneration

    // Time advances within the same calendar day.
    clock = TestDate.at(2026, 5, 22, hour: 17, minute: 45)
    let changed = state.refreshCurrentDate()

    #expect(!changed)
    #expect(state.todayDate == TestDate.at(2026, 5, 22))
    #expect(state.dataGeneration == genBefore)
}

@MainActor
@Test func refreshKeepsSelectionOnPastDayButAdvancesToday() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    var clock = TestDate.at(2026, 5, 22, hour: 9)
    let state = AppState(context: context, now: { clock }, defaults: defaults)
    state.goToPreviousDay()  // browsing the 21st while today is the 22nd
    #expect(state.selectedDate == TestDate.at(2026, 5, 21))
    let genBefore = state.dataGeneration

    clock = TestDate.at(2026, 5, 23, hour: 1)
    let changed = state.refreshCurrentDate()

    #expect(changed)
    #expect(state.todayDate == TestDate.at(2026, 5, 23))
    // Not viewing today, so the selection stays put on the past day.
    #expect(state.selectedDate == TestDate.at(2026, 5, 21))
    #expect(state.isPast)
    #expect(state.dataGeneration == genBefore + 1)
}

@MainActor
@Test func refreshIsIdempotentWhenCalledTwice() throws {
    let context = try InMemoryStore.makeContext()
    let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
    var clock = TestDate.at(2026, 5, 21, hour: 23)
    let state = AppState(context: context, now: { clock }, defaults: defaults)
    let genBefore = state.dataGeneration

    clock = TestDate.at(2026, 5, 22, hour: 0, minute: 30)
    #expect(state.refreshCurrentDate())
    let genAfterFirst = state.dataGeneration
    #expect(genAfterFirst == genBefore + 1)

    // A second call with the clock unchanged is a no-op (no extra rebuild).
    #expect(!state.refreshCurrentDate())
    #expect(state.dataGeneration == genAfterFirst)
    #expect(state.todayDate == TestDate.at(2026, 5, 22))
}
