import Foundation
import Testing
@testable import BrainDumpKit

@MainActor
private func parsed(_ start: Date, _ end: Date, rrule: String?, exDates: [Date] = []) -> ParsedICalEvent {
    ParsedICalEvent(
        uid: "u", summary: "S", start: start, end: end, isAllDay: false,
        rrule: rrule.flatMap { RecurrenceRule.parse($0) }, exDates: exDates, recurrenceID: nil)
}

@MainActor
private func window(_ from: Date, days: Int) -> Range<Date> {
    from..<Calendar.current.date(byAdding: .day, value: days, to: from)!
}

@MainActor
@Test func expandsDailyWithCount() {
    let start = TestDate.at(2026, 5, 22, hour: 9)
    let e = parsed(start, TestDate.at(2026, 5, 22, hour: 10), rrule: "FREQ=DAILY;COUNT=3")
    let occ = RecurrenceExpander.occurrences(of: e, in: window(start, days: 30))
    #expect(occ.count == 3)
}

@MainActor
@Test func expandsDailyWithInterval() {
    let start = TestDate.at(2026, 5, 22, hour: 9)
    let e = parsed(start, TestDate.at(2026, 5, 22, hour: 10), rrule: "FREQ=DAILY;INTERVAL=2;COUNT=3")
    let occ = RecurrenceExpander.occurrences(of: e, in: window(start, days: 30))
    let days = occ.map { Calendar.current.component(.day, from: $0.start) }
    #expect(days == [22, 24, 26])
}

@MainActor
@Test func expandsWeeklyByDay() {
    // DTSTART Fri 2026-05-22; BYDAY=MO,FR; 2 weeks of window.
    let start = TestDate.at(2026, 5, 22, hour: 9)
    let e = parsed(start, TestDate.at(2026, 5, 22, hour: 10), rrule: "FREQ=WEEKLY;BYDAY=MO,FR")
    let occ = RecurrenceExpander.occurrences(of: e, in: window(start, days: 14))
    let days = occ.map { Calendar.current.component(.day, from: $0.start) }.sorted()
    #expect(days.contains(22) && days.contains(25) && days.contains(29))
}

@MainActor
@Test func appliesUntil() {
    let start = TestDate.at(2026, 5, 22, hour: 9)
    let e = parsed(start, TestDate.at(2026, 5, 22, hour: 10),
                   rrule: "FREQ=DAILY;UNTIL=20260524T235959Z")
    let occ = RecurrenceExpander.occurrences(of: e, in: window(start, days: 30))
    #expect(occ.count == 3) // 22, 23, 24
}

@MainActor
@Test func appliesExDate() {
    let start = TestDate.at(2026, 5, 22, hour: 9)
    let ex = TestDate.at(2026, 5, 23, hour: 9)
    let e = parsed(start, TestDate.at(2026, 5, 22, hour: 10),
                   rrule: "FREQ=DAILY;COUNT=3", exDates: [ex])
    let occ = RecurrenceExpander.occurrences(of: e, in: window(start, days: 30))
    let days = occ.map { Calendar.current.component(.day, from: $0.start) }
    #expect(days == [22, 24])
}

@MainActor
@Test func unboundedRuleTerminatesAtWindow() {
    let start = TestDate.at(2026, 5, 22, hour: 9)
    let e = parsed(start, TestDate.at(2026, 5, 22, hour: 10), rrule: "FREQ=DAILY")
    let occ = RecurrenceExpander.occurrences(of: e, in: window(start, days: 10))
    #expect(occ.count == 10)
}

@MainActor
@Test func nonRecurringReturnsSingleWhenInWindow() {
    let start = TestDate.at(2026, 5, 22, hour: 9)
    let e = parsed(start, TestDate.at(2026, 5, 22, hour: 10), rrule: nil)
    #expect(RecurrenceExpander.occurrences(of: e, in: window(start, days: 1)).count == 1)
}
