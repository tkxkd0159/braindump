import Foundation
import Testing
import SwiftData
@testable import TodoosxKit

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
    let entry = try scheduleService.schedule(done, on: yesterday, startHour: 9, durationHours: 1)
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
