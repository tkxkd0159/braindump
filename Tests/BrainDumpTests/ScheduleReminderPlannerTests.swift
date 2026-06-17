import Foundation
import Testing
@testable import BrainDumpKit

private func reminderTestInput(
    start: Int, reminderMinuteOfDay: Int?, completed: Bool = false,
    day: Date = TestDate.at(2026, 6, 12), title: String = "Write report"
) -> ReminderInput {
    ReminderInput(
        entryID: UUID(), dayStart: day, startMinute: start,
        reminderMinuteOfDay: reminderMinuteOfDay, isCompleted: completed, title: title)
}

@Test func scheduleReminderArmsAtAbsoluteTimeWithinDay() {
    let now = TestDate.at(2026, 6, 12, hour: 8)
    let plan = ScheduleReminderPlanner.plan(
        inputs: [reminderTestInput(start: 9 * 60, reminderMinuteOfDay: 8 * 60 + 45)], now: now)
    #expect(plan.count == 1)
    #expect(plan[0].trigger == .at(TestDate.at(2026, 6, 12, hour: 8, minute: 45)))
    #expect(plan[0].title == "Write report")
    #expect(plan[0].id.hasPrefix(ScheduleReminderPlanner.idPrefix))
}

@Test func scheduleReminderSkipsNilReminderAndCompleted() {
    let now = TestDate.at(2026, 6, 12, hour: 8)
    #expect(ScheduleReminderPlanner.plan(
        inputs: [reminderTestInput(start: 9 * 60, reminderMinuteOfDay: nil)], now: now).isEmpty)
    #expect(ScheduleReminderPlanner.plan(
        inputs: [reminderTestInput(start: 9 * 60, reminderMinuteOfDay: 8 * 60 + 45, completed: true)], now: now).isEmpty)
}

@Test func scheduleReminderSkipsFireTimesInThePast() {
    let now = TestDate.at(2026, 6, 12, hour: 9, minute: 30) // already past 8:45
    #expect(ScheduleReminderPlanner.plan(
        inputs: [reminderTestInput(start: 9 * 60, reminderMinuteOfDay: 8 * 60 + 45)], now: now).isEmpty)
}

@Test func scheduleReminderSkipsRemindersOutsideTheDay() {
    let now = TestDate.at(2026, 6, 12, hour: 0)
    // A negative absolute minute (e.g. bridged from a legacy 60-min lead on a
    // 00:30 block) is not a real time-of-day, so it's skipped.
    #expect(ScheduleReminderPlanner.plan(
        inputs: [reminderTestInput(start: 30, reminderMinuteOfDay: -30)], now: now).isEmpty)
    #expect(ScheduleReminderPlanner.plan(
        inputs: [reminderTestInput(start: 30, reminderMinuteOfDay: 1440)], now: now).isEmpty)
}

@Test func scheduleReminderBodyDescribesLeadTimeBeforeStart() {
    let now = TestDate.at(2026, 6, 12, hour: 7)
    let atStart = ScheduleReminderPlanner.plan(
        inputs: [reminderTestInput(start: 9 * 60, reminderMinuteOfDay: 9 * 60)], now: now)[0]
    #expect(atStart.body.contains("now"))
    let inHour = ScheduleReminderPlanner.plan(
        inputs: [reminderTestInput(start: 9 * 60, reminderMinuteOfDay: 8 * 60)], now: now)[0]
    #expect(inHour.body.contains("1 hour"))
}

@Test func scheduleReminderBodyForTimeAfterStartReadsInProgress() {
    let now = TestDate.at(2026, 6, 12, hour: 7)
    // Reminder at 9:20 for a block starting at 9:00 — fires after the block began.
    let plan = ScheduleReminderPlanner.plan(
        inputs: [reminderTestInput(start: 9 * 60, reminderMinuteOfDay: 9 * 60 + 20)], now: now)
    #expect(plan[0].body == "In progress.")
}

@Test func scheduleReminderIDIsStablePerEntry() {
    let id = UUID()
    let input = ReminderInput(entryID: id, dayStart: TestDate.at(2026, 6, 12), startMinute: 9 * 60,
                              reminderMinuteOfDay: 9 * 60 - 10, isCompleted: false, title: "T")
    let plan = ScheduleReminderPlanner.plan(inputs: [input], now: TestDate.at(2026, 6, 12, hour: 7))
    #expect(plan[0].id == ScheduleReminderPlanner.id(for: id))
}
