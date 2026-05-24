import Foundation
import Testing
import SwiftData
@testable import BrainDumpKit

@MainActor
@Test func dayForReturnsSameDayForRepeatedCalls() throws {
    let context = try InMemoryStore.makeContext()
    let service = DayService(context: context)

    let d1 = service.day(for: TestDate.at(2026, 5, 22))
    let d2 = service.day(for: TestDate.at(2026, 5, 22))

    #expect(d1 === d2)
}

@MainActor
@Test func dayForNormalizesToStartOfDay() throws {
    let context = try InMemoryStore.makeContext()
    let service = DayService(context: context)

    let d = service.day(for: TestDate.at(2026, 5, 22, hour: 14, minute: 30))
    #expect(d.date == TestDate.at(2026, 5, 22))
}

@MainActor
@Test func dayForCreatesDistinctDaysForDistinctDates() throws {
    let context = try InMemoryStore.makeContext()
    let service = DayService(context: context)

    let a = service.day(for: TestDate.at(2026, 5, 22))
    let b = service.day(for: TestDate.at(2026, 5, 23))

    #expect(a.date != b.date)
    let all = try context.fetch(FetchDescriptor<Day>())
    #expect(all.count == 2)
}

@MainActor
@Test func rolloverMovesUncompletedItemsToToday() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let yesterday = dayService.day(for: TestDate.at(2026, 5, 21))
    let item = taskService.addBrainDumpItem(title: "Leftover", on: yesterday)

    dayService.rollover(now: TestDate.at(2026, 5, 22))

    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    #expect(today.items.count == 1)
    #expect(today.items.first?.id == item.id)
    #expect(yesterday.items.count == 0)
}

@MainActor
@Test func rolloverLeavesCompletedItemsBehind() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let scheduleService = ScheduleService(context: context)
    let yesterday = dayService.day(for: TestDate.at(2026, 5, 21))
    let done = taskService.addBrainDumpItem(title: "Done", on: yesterday)
    let entry = try scheduleService.schedule(done, on: yesterday, startMinute: 9 * 60, durationMinutes: 60)
    scheduleService.setCompleted(entry, true)

    dayService.rollover(now: TestDate.at(2026, 5, 22))

    #expect(yesterday.items.count == 1)
    #expect(yesterday.items.first?.id == done.id)
    #expect(yesterday.schedule.count == 1)
    #expect(yesterday.schedule.first?.isCompleted == true)
}

@MainActor
@Test func rolloverIsIdempotent() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let yesterday = dayService.day(for: TestDate.at(2026, 5, 21))
    _ = taskService.addBrainDumpItem(title: "Leftover", on: yesterday)

    dayService.rollover(now: TestDate.at(2026, 5, 22))
    dayService.rollover(now: TestDate.at(2026, 5, 22))

    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    #expect(today.items.count == 1)
}

@MainActor
@Test func rolloverHandlesMultiDayGap() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let day19 = dayService.day(for: TestDate.at(2026, 5, 19))
    let day20 = dayService.day(for: TestDate.at(2026, 5, 20))
    let day21 = dayService.day(for: TestDate.at(2026, 5, 21))
    let a = taskService.addBrainDumpItem(title: "From 19", on: day19)
    let b = taskService.addBrainDumpItem(title: "From 20", on: day20)
    let c = taskService.addBrainDumpItem(title: "From 21", on: day21)

    dayService.rollover(now: TestDate.at(2026, 5, 22))

    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    let ids = Set(today.items.map(\.id))
    #expect(ids == Set([a.id, b.id, c.id]))
    #expect(day19.items.isEmpty)
    #expect(day20.items.isEmpty)
    #expect(day21.items.isEmpty)
}

@MainActor
@Test func rolloverRemovesMovedItemFromYesterdayTop3() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let yesterday = dayService.day(for: TestDate.at(2026, 5, 21))
    let item = taskService.addBrainDumpItem(title: "Top", on: yesterday)
    try taskService.escalate(item, on: yesterday)
    #expect(yesterday.top3ItemIDs == [item.id])

    dayService.rollover(now: TestDate.at(2026, 5, 22))

    #expect(yesterday.top3ItemIDs.isEmpty)
}

@MainActor
@Test func incompleteCountCountsItemsWithNoCompletedEntry() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let scheduleService = ScheduleService(context: context)
    let day = dayService.day(for: TestDate.at(2026, 5, 22))
    _ = taskService.addBrainDumpItem(title: "Unscheduled", on: day)
    let item = taskService.addBrainDumpItem(title: "Scheduled but open", on: day)
    _ = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)

    #expect(dayService.incompleteItemCount(on: day) == 2)
}

@MainActor
@Test func incompleteCountIgnoresItemsWithAnyCompletedEntry() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let scheduleService = ScheduleService(context: context)
    let day = dayService.day(for: TestDate.at(2026, 5, 22))
    let done = taskService.addBrainDumpItem(title: "Done", on: day)
    let open = taskService.addBrainDumpItem(title: "Open", on: day)
    let entry = try scheduleService.schedule(done, on: day, startMinute: 9 * 60, durationMinutes: 60)
    scheduleService.setCompleted(entry, true)
    _ = try scheduleService.schedule(open, on: day, startMinute: 10 * 60, durationMinutes: 60)

    #expect(dayService.incompleteItemCount(on: day) == 1)
}

@MainActor
@Test func totalCountReturnsAllDayItems() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let day = dayService.day(for: TestDate.at(2026, 5, 22))
    _ = taskService.addBrainDumpItem(title: "A", on: day)
    _ = taskService.addBrainDumpItem(title: "B", on: day)
    _ = taskService.addBrainDumpItem(title: "C", on: day)

    #expect(dayService.totalItemCount(on: day) == 3)
}

@MainActor
@Test func clearAllDataRemovesEveryEntity() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let backlogService = BacklogService(context: context)
    let scheduleService = ScheduleService(context: context)
    let day = dayService.day(for: TestDate.at(2026, 5, 22))
    let other = dayService.day(for: TestDate.at(2026, 5, 21))
    let item = taskService.addBrainDumpItem(title: "Today", on: day)
    _ = taskService.addBrainDumpItem(title: "Yesterday", on: other)
    _ = backlogService.addBacklogItem(title: "Someday")
    _ = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)

    dayService.clearAllData()

    #expect((try context.fetch(FetchDescriptor<Day>())).isEmpty)
    #expect((try context.fetch(FetchDescriptor<TaskItem>())).isEmpty)
    #expect((try context.fetch(FetchDescriptor<ScheduleEntry>())).isEmpty)
}

@MainActor
@Test func clearAllDataIsIdempotentOnEmptyStore() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)

    dayService.clearAllData()
    dayService.clearAllData()

    #expect((try context.fetch(FetchDescriptor<Day>())).isEmpty)
}

@MainActor
@Test func rolloverKeepsTop3EntryForCompletedItem() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let scheduleService = ScheduleService(context: context)
    let yesterday = dayService.day(for: TestDate.at(2026, 5, 21))
    let done = taskService.addBrainDumpItem(title: "Top done", on: yesterday)
    try taskService.escalate(done, on: yesterday)
    let entry = try scheduleService.schedule(done, on: yesterday, startMinute: 9 * 60, durationMinutes: 60)
    scheduleService.setCompleted(entry, true)

    dayService.rollover(now: TestDate.at(2026, 5, 22))

    #expect(yesterday.top3ItemIDs == [done.id])
}
