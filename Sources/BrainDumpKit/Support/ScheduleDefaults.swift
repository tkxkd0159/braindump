import Foundation

/// Pure helpers for the default time a freshly-scheduled block should start at.
/// Kept SwiftData-free so the rule (round up, clamp to the window, skip
/// occupied slots) is unit-testable in isolation.
enum ScheduleDefaults {
    /// The nearest *available* `step`-minute boundary at or after
    /// `referenceMinute`, clamped into `[dayStartMinute, dayEndMinute - step]`
    /// and advanced past any minute already covered by an `occupied` range.
    ///
    /// - If the reference is before the window, the day start is used.
    /// - If the reference is past the last legal start, that last start is used.
    /// - If every slot from the reference to the window end is occupied, scans
    ///   forward from the day start for the first free slot; if the whole day
    ///   is full, returns the day start (the sheet remains editable).
    static func defaultStartMinute(
        referenceMinute: Int,
        dayStartMinute: Int,
        dayEndMinute: Int,
        occupied: [Range<Int>],
        step: Int = 15
    ) -> Int {
        let lastStart = max(dayStartMinute, dayEndMinute - step)

        func roundUp(_ minute: Int) -> Int {
            guard minute > 0 else { return 0 }
            return ((minute + step - 1) / step) * step
        }
        func isFree(_ minute: Int) -> Bool {
            !occupied.contains { $0.contains(minute) }
        }
        func firstFree(from start: Int) -> Int? {
            var candidate = start
            while candidate <= lastStart {
                if isFree(candidate) { return candidate }
                candidate += step
            }
            return nil
        }

        let clamped = min(max(dayStartMinute, roundUp(referenceMinute)), lastStart)
        return firstFree(from: clamped) ?? firstFree(from: dayStartMinute) ?? dayStartMinute
    }
}
