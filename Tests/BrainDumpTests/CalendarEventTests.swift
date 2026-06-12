import Foundation
import Testing
@testable import BrainDumpKit

@MainActor
private func ev(_ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEvent {
    CalendarEvent(id: "x", feedID: UUID(), title: "T", start: start, end: end, isAllDay: allDay, colorIndex: 0)
}

@MainActor
@Test func minuteRangeForSameDayTimedEvent() {
    let e = ev(TestDate.at(2026, 5, 22, hour: 9), TestDate.at(2026, 5, 22, hour: 10, minute: 30))
    #expect(e.minuteRange(on: TestDate.at(2026, 5, 22)) == (9 * 60)..<(10 * 60 + 30))
}

@MainActor
@Test func minuteRangeNilForAllDay() {
    let e = ev(TestDate.at(2026, 5, 22), TestDate.at(2026, 5, 23), allDay: true)
    #expect(e.minuteRange(on: TestDate.at(2026, 5, 22)) == nil)
}

@MainActor
@Test func minuteRangeClampsMidnightSpanningEvent() {
    // 23:00 on the 22nd to 01:00 on the 23rd
    let e = ev(TestDate.at(2026, 5, 22, hour: 23), TestDate.at(2026, 5, 23, hour: 1))
    #expect(e.minuteRange(on: TestDate.at(2026, 5, 22)) == (23 * 60)..<1440)
    #expect(e.minuteRange(on: TestDate.at(2026, 5, 23)) == 0..<60)
}

@MainActor
@Test func intersectsMatchesOverlappingDay() {
    let e = ev(TestDate.at(2026, 5, 22, hour: 9), TestDate.at(2026, 5, 22, hour: 10))
    #expect(e.intersects(TestDate.at(2026, 5, 22)))
    #expect(!e.intersects(TestDate.at(2026, 5, 23)))
}
