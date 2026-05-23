import Testing
import SwiftUI
@testable import BrainDumpKit

@MainActor
@Test func timeRangePicker_buildsBody() {
    let picker = TimeRangePicker(
        startMinute: .constant(9 * 60),
        endMinute: .constant(10 * 60),
        dayStartHour: 5,
        dayEndHour: 22
    )
    _ = picker.body
}

@Test func timeRangePicker_snap_rounds_to_15_minutes() {
    #expect(TimeRangePicker.snap(minute: 0) == 0)
    #expect(TimeRangePicker.snap(minute: 7) == 0)
    #expect(TimeRangePicker.snap(minute: 8) == 15)
    #expect(TimeRangePicker.snap(minute: 22) == 15)
    #expect(TimeRangePicker.snap(minute: 23) == 30)
    #expect(TimeRangePicker.snap(minute: 24 * 60 + 5) == 24 * 60)
}

@Test func timeRangePicker_endIsBumped_whenStartCrossesIt() {
    var start = 10 * 60
    var end = 9 * 60 + 30  // start now past end
    TimeRangePicker.coerce(start: &start, end: &end, step: 15, movedStart: true)
    #expect(end == start + 15)
    #expect(end == 10 * 60 + 15)
}

@Test func timeRangePicker_startIsBumped_whenEndDropsBelowIt() {
    var start = 10 * 60
    var end = 9 * 60  // user pushed end below start
    TimeRangePicker.coerce(start: &start, end: &end, step: 15, movedStart: false)
    #expect(start == end - 15)
    #expect(start == 9 * 60 - 15)
}

@Test func timeRangePicker_noCoercion_whenInvariantHolds() {
    var start = 9 * 60
    var end = 10 * 60
    TimeRangePicker.coerce(start: &start, end: &end, step: 15, movedStart: true)
    #expect(start == 9 * 60)
    #expect(end == 10 * 60)
}
