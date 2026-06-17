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
@Test func setColorIndexPersistsAndClearsCustomColor() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)
    entry.customColorHex = "#111111"

    scheduleService.setColorIndex(entry, 5)
    #expect(entry.colorIndex == 5)
    #expect(entry.customColorHex == nil) // picking a preset retires the custom override
}

@MainActor
@Test func scheduleStoresCustomColor() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(
        item, on: day, startMinute: 9 * 60, durationMinutes: 60, customColorHex: "#112233")
    #expect(entry.customColorHex == "#112233")
}

@MainActor
@Test func setCustomColorPersists() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 9 * 60, durationMinutes: 60)

    scheduleService.setCustomColor(entry, "#ABCDEF")
    #expect(entry.customColorHex == "#ABCDEF")
    scheduleService.setCustomColor(entry, nil)
    #expect(entry.customColorHex == nil)
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
@Test func scheduleStoresAbsoluteReminder() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(
        item, on: day, startMinute: 540, durationMinutes: 60, reminderMinuteOfDay: 525)
    #expect(entry.reminderMinuteOfDay == 525)
}

@MainActor
@Test func scheduleDefaultsToNoReminder() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 540, durationMinutes: 60)
    #expect(entry.reminderMinuteOfDay == nil)
}

@MainActor
@Test func reschedulePreservesAbsoluteReminder() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    // An absolute reminder is independent of placement — moving the block,
    // even to 00:30, must not change or drop it.
    let entry = try scheduleService.schedule(
        item, on: day, startMinute: 9 * 60, durationMinutes: 60, reminderMinuteOfDay: 480)
    try scheduleService.reschedule(entry, startMinute: 30, durationMinutes: 60)
    #expect(entry.reminderMinuteOfDay == 480)
}

@MainActor
@Test func setReminderMinuteOfDayUpdatesEntry() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 540, durationMinutes: 60)

    scheduleService.setReminderMinuteOfDay(entry, 500)
    #expect(entry.reminderMinuteOfDay == 500)
    scheduleService.setReminderMinuteOfDay(entry, nil)
    #expect(entry.reminderMinuteOfDay == nil)
}

@MainActor
@Test func setReminderMinuteOfDayRetiresLegacyOffset() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "A", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 540, durationMinutes: 60)
    entry.reminderOffsetMinutes = 15 // legacy reminder

    // Clearing the reminder must also drop the legacy offset, or the AppState
    // bridge would resurrect it.
    scheduleService.setReminderMinuteOfDay(entry, nil)
    #expect(entry.reminderMinuteOfDay == nil)
    #expect(entry.reminderOffsetMinutes == nil)
}

@MainActor
@Test func scheduleRejectsOverlapWithCalendarBusyRange() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Focus", on: day)
    // Calendar meeting 10:00–11:00.
    let busy = [10 * 60 ..< 11 * 60]

    #expect(throws: TodoError.scheduleConflict) {
        try scheduleService.schedule(item, on: day, startMinute: 10 * 60 + 30,
                                     durationMinutes: 60, additionalBusyRanges: busy)
    }
}

@MainActor
@Test func scheduleAllowsAdjacentToCalendarBusyRange() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Focus", on: day)
    let busy = [10 * 60 ..< 11 * 60]
    let entry = try scheduleService.schedule(item, on: day, startMinute: 11 * 60,
                                             durationMinutes: 60, additionalBusyRanges: busy)
    #expect(entry.startMinute == 11 * 60)
}

@MainActor
@Test func rescheduleRejectsOverlapWithCalendarBusyRange() throws {
    let (_, _, taskService, scheduleService, day) = try setupScheduleTest()
    let item = taskService.addBrainDumpItem(title: "Focus", on: day)
    let entry = try scheduleService.schedule(item, on: day, startMinute: 8 * 60, durationMinutes: 60)
    let busy = [10 * 60 ..< 11 * 60]

    #expect(throws: TodoError.scheduleConflict) {
        try scheduleService.reschedule(entry, startMinute: 10 * 60, durationMinutes: 60,
                                       additionalBusyRanges: busy)
    }
}
