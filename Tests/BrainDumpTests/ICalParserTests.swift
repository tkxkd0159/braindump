import Foundation
import Testing
@testable import BrainDumpKit

private let timedICS = """
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:abc@x
SUMMARY:Standup
DTSTART:20260522T090000Z
DTEND:20260522T093000Z
END:VEVENT
END:VCALENDAR
"""

@Test func parsesSingleTimedEvent() {
    let e = ICalParser.parse(timedICS)
    #expect(e.count == 1)
    #expect(e.first?.summary == "Standup")
    #expect(e.first?.isAllDay == false)
}

@Test func parsesAllDayEvent() {
    let ics = """
    BEGIN:VEVENT
    UID:h
    SUMMARY:Holiday
    DTSTART;VALUE=DATE:20260704
    DTEND;VALUE=DATE:20260705
    END:VEVENT
    """
    let e = ICalParser.parse(ics)
    #expect(e.first?.isAllDay == true)
}

@Test func parsesDurationWhenNoDTEnd() {
    let ics = """
    BEGIN:VEVENT
    UID:d
    SUMMARY:Call
    DTSTART:20260522T090000Z
    DURATION:PT1H30M
    END:VEVENT
    """
    let e = ICalParser.parse(ics).first!
    #expect(e.end.timeIntervalSince(e.start) == 90 * 60)
}

@Test func unfoldsContinuationLines() {
    let ics = "BEGIN:VEVENT\nUID:u\nSUMMARY:Long tit\n le\nDTSTART:20260522T090000Z\nEND:VEVENT"
    #expect(ICalParser.parse(ics).first?.summary == "Long title")
}

@Test func parsesMultipleEventsAndSkipsMalformed() {
    let ics = """
    BEGIN:VEVENT
    UID:ok
    SUMMARY:Good
    DTSTART:20260522T090000Z
    DTEND:20260522T100000Z
    END:VEVENT
    BEGIN:VEVENT
    UID:bad
    SUMMARY:NoStart
    END:VEVENT
    """
    let e = ICalParser.parse(ics)
    #expect(e.count == 1)
    #expect(e.first?.uid == "ok")
}

@Test func capturesRRuleAndRecurrenceID() {
    let ics = """
    BEGIN:VEVENT
    UID:r
    SUMMARY:Weekly
    DTSTART:20260522T090000Z
    DTEND:20260522T093000Z
    RRULE:FREQ=WEEKLY;BYDAY=FR
    EXDATE:20260529T090000Z
    END:VEVENT
    """
    let e = ICalParser.parse(ics).first!
    #expect(e.rrule?.frequency == .weekly)
    #expect(e.exDates.count == 1)
}

@Test func unescapesSummaryText() {
    let ics = "BEGIN:VEVENT\nUID:e\nSUMMARY:Lunch\\, then walk\nDTSTART:20260522T120000Z\nEND:VEVENT"
    #expect(ICalParser.parse(ics).first?.summary == "Lunch, then walk")
}
