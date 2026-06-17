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

// MARK: - Google-Calendar-style "N minutes/hours before" offset input

@Test func reminderUnitMinutesPerStepIsMinutesOrHours() {
    #expect(ReminderTime.Unit.minutes.minutesPerStep == 1)
    #expect(ReminderTime.Unit.hours.minutesPerStep == 60)
}

@Test func reminderOffsetMinutesMultipliesAmountByUnit() {
    #expect(ReminderTime.offsetMinutes(amount: 10, unit: .minutes) == 10)
    #expect(ReminderTime.offsetMinutes(amount: 2, unit: .hours) == 120)
    #expect(ReminderTime.offsetMinutes(amount: 0, unit: .minutes) == 0)
}

@Test func reminderOffsetMinutesClampsNegativeAmountToZero() {
    #expect(ReminderTime.offsetMinutes(amount: -5, unit: .minutes) == 0)
    #expect(ReminderTime.offsetMinutes(amount: -1, unit: .hours) == 0)
}

@Test func reminderSplitPrefersHoursOnCleanMultiples() {
    let twoHours = ReminderTime.split(offsetMinutes: 120)
    #expect(twoHours.amount == 2 && twoHours.unit == .hours)
    let oneHour = ReminderTime.split(offsetMinutes: 60)
    #expect(oneHour.amount == 1 && oneHour.unit == .hours)
}

@Test func reminderSplitUsesMinutesOtherwise() {
    let ten = ReminderTime.split(offsetMinutes: 10)
    #expect(ten.amount == 10 && ten.unit == .minutes)
    let ninety = ReminderTime.split(offsetMinutes: 90)   // not a clean hour multiple
    #expect(ninety.amount == 90 && ninety.unit == .minutes)
    let zero = ReminderTime.split(offsetMinutes: 0)      // "at start time" reads as minutes
    #expect(zero.amount == 0 && zero.unit == .minutes)
}

@Test func reminderSplitClampsNegativeOffsetToZeroMinutes() {
    // A block dragged earlier than its absolute reminder yields a negative
    // derived offset; the editor should show "0 minutes", never a negative.
    let negative = ReminderTime.split(offsetMinutes: -15)
    #expect(negative.amount == 0 && negative.unit == .minutes)
}

@Test func reminderOffsetRoundTripsThroughSplit() {
    for offset in [0, 5, 10, 15, 30, 45, 60, 90, 120, 180] {
        let s = ReminderTime.split(offsetMinutes: offset)
        #expect(ReminderTime.offsetMinutes(amount: s.amount, unit: s.unit) == offset)
    }
}
