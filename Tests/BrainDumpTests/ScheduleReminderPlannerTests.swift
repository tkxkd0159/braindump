import Foundation
import Testing
@testable import BrainDumpKit

private func reminderTestInput(
    start: Int, offset: Int?, completed: Bool = false,
    day: Date = TestDate.at(2026, 6, 12), title: String = "Write report"
) -> ReminderInput {
    ReminderInput(
        entryID: UUID(), dayStart: day, startMinute: start,
        offsetMinutes: offset, isCompleted: completed, title: title)
}

@Test func scheduleReminderArmsBeforeStartWithinDay() {
    let now = TestDate.at(2026, 6, 12, hour: 8)
    let plan = ScheduleReminderPlanner.plan(inputs: [reminderTestInput(start: 9 * 60, offset: 15)], now: now)
    #expect(plan.count == 1)
    #expect(plan[0].trigger == .at(TestDate.at(2026, 6, 12, hour: 8, minute: 45)))
    #expect(plan[0].title == "Write report")
    #expect(plan[0].id.hasPrefix(ScheduleReminderPlanner.idPrefix))
}

@Test func scheduleReminderSkipsNilOffsetAndCompleted() {
    let now = TestDate.at(2026, 6, 12, hour: 8)
    #expect(ScheduleReminderPlanner.plan(inputs: [reminderTestInput(start: 9 * 60, offset: nil)], now: now).isEmpty)
    #expect(ScheduleReminderPlanner.plan(inputs: [reminderTestInput(start: 9 * 60, offset: 15, completed: true)], now: now).isEmpty)
}

@Test func scheduleReminderSkipsFireTimesInThePast() {
    let now = TestDate.at(2026, 6, 12, hour: 9, minute: 30) // already past 8:45
    #expect(ScheduleReminderPlanner.plan(inputs: [reminderTestInput(start: 9 * 60, offset: 15)], now: now).isEmpty)
}

@Test func scheduleReminderSkipsOffsetsThatCrossMidnight() {
    let now = TestDate.at(2026, 6, 12, hour: 0)
    // block at 00:30 with a 60-min lead would fire at 23:30 the previous day.
    #expect(ScheduleReminderPlanner.plan(inputs: [reminderTestInput(start: 30, offset: 60)], now: now).isEmpty)
}

@Test func scheduleReminderBodyDescribesLeadTime() {
    let now = TestDate.at(2026, 6, 12, hour: 7)
    let atStart = ScheduleReminderPlanner.plan(inputs: [reminderTestInput(start: 9 * 60, offset: 0)], now: now)[0]
    #expect(atStart.body.contains("now"))
    let inHour = ScheduleReminderPlanner.plan(inputs: [reminderTestInput(start: 9 * 60, offset: 60)], now: now)[0]
    #expect(inHour.body.contains("1 hour"))
}

@Test func scheduleReminderIDIsStablePerEntry() {
    let id = UUID()
    let input = ReminderInput(entryID: id, dayStart: TestDate.at(2026, 6, 12), startMinute: 9 * 60,
                              offsetMinutes: 10, isCompleted: false, title: "T")
    let plan = ScheduleReminderPlanner.plan(inputs: [input], now: TestDate.at(2026, 6, 12, hour: 7))
    #expect(plan[0].id == ScheduleReminderPlanner.id(for: id))
}
