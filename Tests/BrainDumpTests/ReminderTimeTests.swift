import Foundation
import Testing
@testable import BrainDumpKit

@Test func reminderTimeAcceptsFutureMinuteToday() {
    let dayStart = TestDate.at(2026, 6, 17)
    let now = TestDate.at(2026, 6, 17, hour: 9) // 540
    #expect(ReminderTime.validate(minuteOfDay: 600, dayStart: dayStart, now: now) == .ok)
}

@Test func reminderTimeRejectsPastMinuteToday() {
    let dayStart = TestDate.at(2026, 6, 17)
    let now = TestDate.at(2026, 6, 17, hour: 9) // 540
    #expect(ReminderTime.validate(minuteOfDay: 480, dayStart: dayStart, now: now) == .notInFuture)
}

@Test func reminderTimeRejectsExactNow() {
    let dayStart = TestDate.at(2026, 6, 17)
    let now = TestDate.at(2026, 6, 17, hour: 9) // 540
    // "later than current time" is strict — equal to now is not in the future.
    #expect(ReminderTime.validate(minuteOfDay: 540, dayStart: dayStart, now: now) == .notInFuture)
}

@Test func reminderTimeAcceptsAnyMinuteOnFutureDay() {
    let dayStart = TestDate.at(2026, 6, 18)
    let now = TestDate.at(2026, 6, 17, hour: 23)
    #expect(ReminderTime.validate(minuteOfDay: 0, dayStart: dayStart, now: now) == .ok)
    #expect(ReminderTime.validate(minuteOfDay: 1439, dayStart: dayStart, now: now) == .ok)
}

@Test func reminderTimeRejectsPastDay() {
    let dayStart = TestDate.at(2026, 6, 16)
    let now = TestDate.at(2026, 6, 17, hour: 9)
    #expect(ReminderTime.validate(minuteOfDay: 1439, dayStart: dayStart, now: now) == .notInFuture)
}

@Test func reminderTimeRejectsMinutesOutsideTheDay() {
    let dayStart = TestDate.at(2026, 6, 18) // future so only the range gates
    let now = TestDate.at(2026, 6, 17, hour: 9)
    #expect(ReminderTime.validate(minuteOfDay: -1, dayStart: dayStart, now: now) == .outsideDay)
    #expect(ReminderTime.validate(minuteOfDay: 1440, dayStart: dayStart, now: now) == .outsideDay)
    #expect(ReminderTime.validate(minuteOfDay: 2000, dayStart: dayStart, now: now) == .outsideDay)
}

@Test func reminderTimeOutsideDayTakesPrecedenceOverPast() {
    let dayStart = TestDate.at(2026, 6, 16) // past day AND out-of-range minute
    let now = TestDate.at(2026, 6, 17, hour: 9)
    #expect(ReminderTime.validate(minuteOfDay: 1440, dayStart: dayStart, now: now) == .outsideDay)
}

@Test func reminderTimeAlertMessageMapsEachCase() {
    #expect(ReminderTime.alertMessage(for: .ok) == nil)
    #expect(ReminderTime.alertMessage(for: .notInFuture) == "Choose a reminder time later than now.")
    #expect(ReminderTime.alertMessage(for: .outsideDay) == "Choose a reminder time within the day.")
}
