import Foundation
import Testing
import SwiftData
@testable import TodoosxKit

@MainActor
private func setupScheduleTest() throws -> (ModelContext, DayService, TaskService, ScheduleService, Day) {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let scheduleService = ScheduleService(context: context)
    let day = dayService.day(for: TestDate.at(2026, 5, 22))
    return (context, dayService, taskService, scheduleService, day)
}

@MainActor
@Test func scheduleSingleHourCreatesEntry() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Write spec", on: day)

    let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1)

    #expect(entry.startHour == 9)
    #expect(entry.durationHours == 1)
    #expect(entry.item?.id == item.id)
    #expect(entry.day?.date == day.date)
    #expect(day.schedule.count == 1)
}

@MainActor
@Test func scheduleMultiHourCreatesSpanningEntry() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Write spec", on: day)

    let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 3)

    #expect(entry.durationHours == 3)
    #expect(day.schedule.count == 1)
}

@MainActor
@Test func scheduleRejectsStartHourBefore5() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Too early", on: day)

    #expect(throws: TodoError.scheduleOutOfRange) {
        try scheduleService.schedule(item, on: day, startHour: 4, durationHours: 1)
    }
}

@MainActor
@Test func scheduleRejectsEndAfter24() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Too late", on: day)

    #expect(throws: TodoError.scheduleOutOfRange) {
        try scheduleService.schedule(item, on: day, startHour: 23, durationHours: 2)
    }
}

@MainActor
@Test func canScheduleAtFiveAM() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Early bird", on: day)

    let entry = try scheduleService.schedule(item, on: day, startHour: 5, durationHours: 1)
    #expect(entry.startHour == 5)
}

@MainActor
@Test func scheduleAllowsBoundaryEnd() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Last block", on: day)

    let entry = try scheduleService.schedule(item, on: day, startHour: 23, durationHours: 1)
    #expect(entry.startHour == 23)
    #expect(entry.durationHours == 1)
}

@MainActor
@Test func scheduleRejectsZeroDuration() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Zero", on: day)

    #expect(throws: TodoError.scheduleOutOfRange) {
        try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 0)
    }
}

@MainActor
@Test func scheduleRejectsOverlap() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let a = taskService.addBrainDumpItem(title: "A", on: day)
    let b = taskService.addBrainDumpItem(title: "B", on: day)
    _ = try scheduleService.schedule(a, on: day, startHour: 9, durationHours: 3) // 9-12

    #expect(throws: TodoError.scheduleConflict) {
        try scheduleService.schedule(b, on: day, startHour: 10, durationHours: 1)
    }
    #expect(throws: TodoError.scheduleConflict) {
        try scheduleService.schedule(b, on: day, startHour: 11, durationHours: 2)
    }
    #expect(throws: TodoError.scheduleConflict) {
        try scheduleService.schedule(b, on: day, startHour: 8, durationHours: 2)
    }
}

@MainActor
@Test func scheduleAllowsAdjacentBlocks() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let a = taskService.addBrainDumpItem(title: "A", on: day)
    let b = taskService.addBrainDumpItem(title: "B", on: day)
    _ = try scheduleService.schedule(a, on: day, startHour: 9, durationHours: 1)  // [9,10)
    _ = try scheduleService.schedule(b, on: day, startHour: 10, durationHours: 1) // [10,11)

    #expect(day.schedule.count == 2)
}

@MainActor
@Test func unscheduleDeletesEntryKeepsItem() throws {
    let (context, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1)

    scheduleService.unschedule(entry)

    #expect(day.schedule.count == 0)
    let items = try context.fetch(FetchDescriptor<TaskItem>())
    #expect(items.count == 1)
}

@MainActor
@Test func setCompletedTogglesFlag() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1)
    #expect(entry.isCompleted == false)

    scheduleService.setCompleted(entry, true)
    #expect(entry.isCompleted == true)
    scheduleService.setCompleted(entry, false)
    #expect(entry.isCompleted == false)
}

@MainActor
@Test func newScheduleEntryDefaultsToColorIndexZero() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1)
    #expect(entry.colorIndex == 0)
}

@MainActor
@Test func scheduleAcceptsColorIndexArgument() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1, colorIndex: 3)
    #expect(entry.colorIndex == 3)
}

@MainActor
@Test func setColorIndexPersists() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1)

    scheduleService.setColorIndex(entry, 5)
    #expect(entry.colorIndex == 5)
}

@MainActor
@Test func rescheduleMovesBlock() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1)

    try scheduleService.reschedule(entry, startHour: 14, durationHours: 2)
    #expect(entry.startHour == 14)
    #expect(entry.durationHours == 2)
}

@MainActor
@Test func rescheduleRejectsOverlapWithOtherEntry() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let a = taskService.addBrainDumpItem(title: "A", on: day)
    let b = taskService.addBrainDumpItem(title: "B", on: day)
    let entryA = try scheduleService.schedule(a, on: day, startHour: 9, durationHours: 1)
    _ = try scheduleService.schedule(b, on: day, startHour: 11, durationHours: 1)

    #expect(throws: TodoError.scheduleConflict) {
        try scheduleService.reschedule(entryA, startHour: 11, durationHours: 1)
    }
}

@MainActor
@Test func rescheduleAllowsKeepingOwnRange() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 2)

    try scheduleService.reschedule(entry, startHour: 9, durationHours: 2)
    #expect(entry.startHour == 9)
}

@MainActor
@Test func rescheduleRejectsOutOfRange() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1)

    #expect(throws: TodoError.scheduleOutOfRange) {
        try scheduleService.reschedule(entry, startHour: 4, durationHours: 1)
    }
}

@MainActor
@Test func setCompletedStampsAndClearsCompletedAt() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startHour: 9, durationHours: 1)
    #expect(entry.completedAt == nil)

    let before = Date()
    scheduleService.setCompleted(entry, true)
    let after = Date()
    #expect(entry.completedAt != nil)
    #expect(entry.completedAt! >= before && entry.completedAt! <= after)

    scheduleService.setCompleted(entry, false)
    #expect(entry.completedAt == nil)
}
