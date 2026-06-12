import Foundation
import Testing
import SwiftData
@testable import BrainDumpKit

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

    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)

    #expect(entry.startMinute == 540)
    #expect(entry.durationMinutes == 60)
    #expect(entry.item?.id == item.id)
    #expect(entry.day?.date == day.date)
    #expect(day.schedule.count == 1)
}

@MainActor
@Test func scheduleMultiHourCreatesSpanningEntry() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Write spec", on: day)

    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 180)

    #expect(entry.durationMinutes == 180)
    #expect(day.schedule.count == 1)
}

@MainActor
@Test func scheduleAcceptsFractionalStart() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Quarter past", on: day)

    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60 + 15, durationMinutes: 75)

    #expect(entry.startMinute == 555)
    #expect(entry.durationMinutes == 75)
    #expect(entry.endMinute == 630)
}

@MainActor
@Test func scheduleRejectsNegativeStart() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Too early", on: day)

    #expect(throws: TodoError.scheduleOutOfRange) {
        try scheduleService.schedule(item, on: day, startMinute: -30, durationMinutes: 60)
    }
}

@MainActor
@Test func scheduleRejectsEndAfterMidnight() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Too late", on: day)

    #expect(throws: TodoError.scheduleOutOfRange) {
        try scheduleService.schedule(item, on: day, startMinute: 23 * 60, durationMinutes: 120)
    }
}

@MainActor
@Test func scheduleAllowsZeroStartMinute() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Midnight", on: day)

    let entry = try scheduleService.schedule(item, on: day, startMinute: 0, durationMinutes: 60)
    #expect(entry.startMinute == 0)
}

@MainActor
@Test func scheduleAllowsBoundaryEnd() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Last block", on: day)

    let entry = try scheduleService.schedule(item, on: day, startMinute: 23 * 60, durationMinutes: 60)
    #expect(entry.startMinute == 1380)
    #expect(entry.durationMinutes == 60)
}

@MainActor
@Test func scheduleRejectsSubFifteenDuration() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Tiny", on: day)

    #expect(throws: TodoError.scheduleOutOfRange) {
        try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 10)
    }
}

@MainActor
@Test func scheduleRejectsOverlap() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let a = taskService.addBrainDumpItem(title: "A", on: day)
    let b = taskService.addBrainDumpItem(title: "B", on: day)
    _ = try scheduleService.schedule(a, on: day, startMinute: 9 * 60, durationMinutes: 180) // 9:00-12:00

    #expect(throws: TodoError.scheduleConflict) {
        try scheduleService.schedule(b, on: day, startMinute: 10 * 60, durationMinutes: 60)
    }
    #expect(throws: TodoError.scheduleConflict) {
        try scheduleService.schedule(b, on: day, startMinute: 11 * 60, durationMinutes: 120)
    }
    #expect(throws: TodoError.scheduleConflict) {
        try scheduleService.schedule(b, on: day, startMinute: 8 * 60, durationMinutes: 120)
    }
}

@MainActor
@Test func scheduleRejectsMinuteLevelOverlap() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let a = taskService.addBrainDumpItem(title: "A", on: day)
    let b = taskService.addBrainDumpItem(title: "B", on: day)
    _ = try scheduleService.schedule(a, on: day, startMinute: 9 * 60 + 15, durationMinutes: 75) // 9:15-10:30

    #expect(throws: TodoError.scheduleConflict) {
        try scheduleService.schedule(b, on: day, startMinute: 10 * 60 + 15, durationMinutes: 60) // 10:15-11:15
    }
}

@MainActor
@Test func scheduleAllowsAdjacentBlocks() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let a = taskService.addBrainDumpItem(title: "A", on: day)
    let b = taskService.addBrainDumpItem(title: "B", on: day)
    _ = try scheduleService.schedule(a, on: day, startMinute: 9 * 60, durationMinutes: 60)
    _ = try scheduleService.schedule(b, on: day, startMinute: 10 * 60, durationMinutes: 60)

    #expect(day.schedule.count == 2)
}

@MainActor
@Test func scheduleAllowsAdjacentSubHourBlocks() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let a = taskService.addBrainDumpItem(title: "A", on: day)
    let b = taskService.addBrainDumpItem(title: "B", on: day)
    _ = try scheduleService.schedule(a, on: day, startMinute: 9 * 60, durationMinutes: 75)  // 9:00-10:15
    _ = try scheduleService.schedule(b, on: day, startMinute: 10 * 60 + 15, durationMinutes: 45) // 10:15-11:00

    #expect(day.schedule.count == 2)
}

@MainActor
@Test func unscheduleDeletesEntryKeepsItem() throws {
    let (context, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)

    scheduleService.unschedule(entry)

    #expect(day.schedule.count == 0)
    let items = try context.fetch(FetchDescriptor<TaskItem>())
    #expect(items.count == 1)
}

@MainActor
@Test func setCompletedTogglesFlag() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)
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
    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)
    #expect(entry.colorIndex == 0)
}

@MainActor
@Test func scheduleAcceptsColorIndexArgument() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60, colorIndex: 3)
    #expect(entry.colorIndex == 3)
}

@MainActor
@Test func setColorIndexPersists() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)

    scheduleService.setColorIndex(entry, 5)
    #expect(entry.colorIndex == 5)
}

@MainActor
@Test func rescheduleMovesBlock() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)

    try scheduleService.reschedule(entry, startMinute: 14 * 60 + 30, durationMinutes: 90)
    #expect(entry.startMinute == 14 * 60 + 30)
    #expect(entry.durationMinutes == 90)
}

@MainActor
@Test func rescheduleRejectsOverlapWithOtherEntry() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let a = taskService.addBrainDumpItem(title: "A", on: day)
    let b = taskService.addBrainDumpItem(title: "B", on: day)
    let entryA = try scheduleService.schedule(a, on: day, startMinute: 9 * 60, durationMinutes: 60)
    _ = try scheduleService.schedule(b, on: day, startMinute: 11 * 60, durationMinutes: 60)

    #expect(throws: TodoError.scheduleConflict) {
        try scheduleService.reschedule(entryA, startMinute: 11 * 60, durationMinutes: 60)
    }
}

@MainActor
@Test func rescheduleAllowsKeepingOwnRange() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 120)

    try scheduleService.reschedule(entry, startMinute: 9 * 60, durationMinutes: 120)
    #expect(entry.startMinute == 9 * 60)
}

@MainActor
@Test func rescheduleRejectsOutOfRange() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)

    #expect(throws: TodoError.scheduleOutOfRange) {
        try scheduleService.reschedule(entry, startMinute: -30, durationMinutes: 60)
    }
}

@MainActor
@Test func setCompletedStampsAndClearsCompletedAt() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)
    #expect(entry.completedAt == nil)

    let before = Date()
    scheduleService.setCompleted(entry, true)
    let after = Date()
    #expect(entry.completedAt != nil)
    #expect(entry.completedAt! >= before && entry.completedAt! <= after)

    scheduleService.setCompleted(entry, false)
    #expect(entry.completedAt == nil)
}

@MainActor
@Test func scheduleStoresReminderOffset() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(
        item, on: day, startMinute: 540, durationMinutes: 60, reminderOffsetMinutes: 15)
    #expect(entry.reminderOffsetMinutes == 15)
}

@MainActor
@Test func scheduleDefaultsToNoReminderOffset() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 540, durationMinutes: 60)
    #expect(entry.reminderOffsetMinutes == nil)
}

@MainActor
@Test func rescheduleClearsReminderThatNoLongerFitsTheDay() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    // 9:00 with a 1-hour lead is fine (08:00 is within the day).
    let entry = try scheduleService.schedule(
        item, on: day, startMinute: 9 * 60, durationMinutes: 60, reminderOffsetMinutes: 60)
    #expect(entry.reminderOffsetMinutes == 60)

    // Move it to 00:30 — a 1-hour lead would fall on the previous day, so it's cleared.
    try scheduleService.reschedule(entry, startMinute: 30, durationMinutes: 60)
    #expect(entry.reminderOffsetMinutes == nil)
}

@MainActor
@Test func rescheduleKeepsReminderThatStillFits() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(
        item, on: day, startMinute: 9 * 60, durationMinutes: 60, reminderOffsetMinutes: 30)
    try scheduleService.reschedule(entry, startMinute: 8 * 60, durationMinutes: 60)
    #expect(entry.reminderOffsetMinutes == 30)
}

@MainActor
@Test func setReminderOffsetUpdatesEntry() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 540, durationMinutes: 60)

    scheduleService.setReminderOffset(entry, 30)
    #expect(entry.reminderOffsetMinutes == 30)
    scheduleService.setReminderOffset(entry, nil)
    #expect(entry.reminderOffsetMinutes == nil)
}
