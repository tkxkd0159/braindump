import Testing

@testable import BrainDumpKit

/// `TimeFormat.range` is now the time-range label rendered on brain-dump cards
/// (and dropped from Schedule blocks). These lock its exact output — including
/// the spaced em-dash separator and the midnight/noon boundary cases — so the
/// card label can't silently drift.
struct TimeFormatTests {
    @Test func rangeFormatsWholeHour() {
        #expect(TimeFormat.range(startMinute: 9 * 60, durationMinutes: 60) == "9:00 AM — 10:00 AM")
    }

    @Test func rangeFormatsFractionalHour() {
        #expect(TimeFormat.range(startMinute: 9 * 60, durationMinutes: 90) == "9:00 AM — 10:30 AM")
    }

    @Test func rangeCrossesNoon() {
        #expect(
            TimeFormat.range(startMinute: 11 * 60 + 30, durationMinutes: 60) == "11:30 AM — 12:30 PM")
    }

    @Test func rangeEndsAtMidnight() {
        // 11:00 PM + 60 min == 24:00, which reads as 12:00 AM rather than 0:00.
        #expect(TimeFormat.range(startMinute: 23 * 60, durationMinutes: 60) == "11:00 PM — 12:00 AM")
    }

    @Test func clockHandlesNoonAndMidnight() {
        #expect(TimeFormat.clock(minute: 0) == "12:00 AM")
        #expect(TimeFormat.clock(minute: 12 * 60) == "12:00 PM")
    }
}
