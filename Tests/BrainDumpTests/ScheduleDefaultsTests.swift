import Testing

@testable import BrainDumpKit

/// `ScheduleDefaults.defaultStartMinute` computes the default start time the
/// "Schedule" context menu pre-fills: the nearest available 15-minute boundary
/// at or after the reference time, clamped into the day window, skipping
/// minutes already occupied by existing blocks.
struct ScheduleDefaultsTests {
    private let dayStart = 5 * 60   // 5:00 AM
    private let dayEnd = 22 * 60    // 10:00 PM

    @Test
    func roundsUpToNextFifteenMinuteStep() {
        // 8:13 AM → 8:15 AM
        let start = ScheduleDefaults.defaultStartMinute(
            referenceMinute: 8 * 60 + 13,
            dayStartMinute: dayStart,
            dayEndMinute: dayEnd,
            occupied: []
        )
        #expect(start == 8 * 60 + 15)
    }

    @Test
    func keepsAReferenceAlreadyOnABoundary() {
        #expect(
            ScheduleDefaults.defaultStartMinute(
                referenceMinute: 8 * 60 + 15, dayStartMinute: dayStart, dayEndMinute: dayEnd,
                occupied: []) == 8 * 60 + 15)
        #expect(
            ScheduleDefaults.defaultStartMinute(
                referenceMinute: 8 * 60, dayStartMinute: dayStart, dayEndMinute: dayEnd,
                occupied: []) == 8 * 60)
    }

    @Test
    func clampsUpToDayStartWhenReferenceIsBeforeTheWindow() {
        // 3:00 AM with a 5:00 AM day start → 5:00 AM
        let start = ScheduleDefaults.defaultStartMinute(
            referenceMinute: 3 * 60,
            dayStartMinute: dayStart,
            dayEndMinute: dayEnd,
            occupied: []
        )
        #expect(start == dayStart)
    }

    @Test
    func skipsAnOccupiedStartToTheNextFreeBoundary() {
        // 8:00 AM but 8:00–9:00 is taken → 9:00 AM
        let start = ScheduleDefaults.defaultStartMinute(
            referenceMinute: 8 * 60,
            dayStartMinute: dayStart,
            dayEndMinute: dayEnd,
            occupied: [(8 * 60)..<(9 * 60)]
        )
        #expect(start == 9 * 60)
    }

    @Test
    func skipsAcrossMultipleAdjacentOccupiedBlocks() {
        // 8:00 occupied through 10:30 across two blocks → 10:30 AM
        let start = ScheduleDefaults.defaultStartMinute(
            referenceMinute: 8 * 60,
            dayStartMinute: dayStart,
            dayEndMinute: dayEnd,
            occupied: [(8 * 60)..<(9 * 60), (9 * 60)..<(10 * 60 + 30)]
        )
        #expect(start == 10 * 60 + 30)
    }

    @Test
    func clampsToLastLegalStartWhenReferenceIsPastTheWindowEnd() {
        // 11:30 PM with a 10:00 PM day end → last legal start = 9:45 PM
        let start = ScheduleDefaults.defaultStartMinute(
            referenceMinute: 23 * 60 + 30,
            dayStartMinute: dayStart,
            dayEndMinute: dayEnd,
            occupied: []
        )
        #expect(start == dayEnd - 15)
    }

    @Test
    func wrapsToFirstFreeBoundaryFromDayStartWhenTailIsOccupied() {
        // Reference 9:45 PM (last slot) is occupied; the only free slot is at
        // the very start of the day → falls back to 5:00 AM.
        let start = ScheduleDefaults.defaultStartMinute(
            referenceMinute: dayEnd - 15,
            dayStartMinute: dayStart,
            dayEndMinute: dayEnd,
            occupied: [(dayEnd - 15)..<dayEnd]
        )
        #expect(start == dayStart)
    }
}
