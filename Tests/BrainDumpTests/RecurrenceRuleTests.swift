import Foundation
import Testing
@testable import BrainDumpKit

@Test func rruleParsesWeeklyWithByDay() {
    let r = RecurrenceRule.parse("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE")
    #expect(r?.frequency == .weekly)
    #expect(r?.interval == 2)
    #expect(r?.byDay == [.mo, .we])
}

@Test func rruleParsesCount() {
    #expect(RecurrenceRule.parse("FREQ=DAILY;COUNT=5")?.count == 5)
}

@Test func rruleParsesUntil() {
    let r = RecurrenceRule.parse("FREQ=DAILY;UNTIL=20260701T000000Z")
    #expect(r?.until != nil)
}

@Test func rruleDefaultsIntervalToOne() {
    #expect(RecurrenceRule.parse("FREQ=MONTHLY")?.interval == 1)
}

@Test func rruleReturnsNilWithoutFreq() {
    #expect(RecurrenceRule.parse("INTERVAL=2") == nil)
}

@Test func icalDateParsesUTC() {
    let d = ICalDate.parse("20260522T093000Z", tzid: nil, isDateValue: false)
    var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
    #expect(utc.component(.hour, from: d!) == 9)
}

@Test func icalDateParsesDateOnly() {
    let d = ICalDate.parse("20260522", tzid: nil, isDateValue: true)
    #expect(Calendar.current.component(.hour, from: d!) == 0)
}
