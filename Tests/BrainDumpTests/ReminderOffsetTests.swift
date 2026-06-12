import Testing
@testable import BrainDumpKit

@Test func reminderOffsetLabelsCoverNilMinutesAndHours() {
    #expect(ReminderOffset.label(nil) == "None")
    #expect(ReminderOffset.label(0) == "At start time")
    #expect(ReminderOffset.label(15) == "15 minutes before")
    #expect(ReminderOffset.label(60) == "1 hour before")
    #expect(ReminderOffset.label(120) == "2 hours before")
}

@Test func reminderOffsetValidityClampsToWithinDay() {
    // 09:00 = 540 min: a 2-hour (120) lead is fine; at 00:30 = 30 it is not.
    #expect(ReminderOffset.isValid(120, startMinute: 540) == true)
    #expect(ReminderOffset.isValid(120, startMinute: 30) == false)
    #expect(ReminderOffset.isValid(nil, startMinute: 0) == true)   // None always valid
    #expect(ReminderOffset.isValid(0, startMinute: 0) == true)     // at-start at midnight ok
}

@Test func reminderOffsetValidPresetsFilterMidnightCrossers() {
    // A block 20 minutes after midnight only fits the 0/5/10/15 leads.
    #expect(ReminderOffset.validPresets(startMinute: 20) == [0, 5, 10, 15])
}

@Test func reminderOffsetLeadTimePhraseForBodies() {
    #expect(ReminderOffset.leadTimePhrase(0) == "now")
    #expect(ReminderOffset.leadTimePhrase(30) == "in 30 minutes")
    #expect(ReminderOffset.leadTimePhrase(60) == "in 1 hour")
    #expect(ReminderOffset.leadTimePhrase(120) == "in 2 hours")
}
