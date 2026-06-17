import Foundation

/// Validation for an absolute reminder time (a minute-of-day on the schedule
/// entry's day). A reminder must fall *within that day* and fire *later than
/// now* — the two constraints the custom time picker enforces, surfaced as an
/// alert when violated. Pure function of an injected `now`, so it's testable
/// without the clock.
public enum ReminderTime {
    public enum Validation: Equatable, Sendable {
        case ok
        case notInFuture   // the chosen time is now or already past
        case outsideDay    // the minute isn't a real time-of-day (0..<1440)
    }

    public static func validate(minuteOfDay: Int, dayStart: Date, now: Date) -> Validation {
        guard (0..<(24 * 60)).contains(minuteOfDay) else { return .outsideDay }
        let fireDate = dayStart.addingTimeInterval(TimeInterval(minuteOfDay * 60))
        guard fireDate > now else { return .notInFuture }
        return .ok
    }

    /// Human-facing alert text for a failed validation; `nil` when `.ok`.
    public static func alertMessage(for validation: Validation) -> String? {
        switch validation {
        case .ok:
            return nil
        case .notInFuture:
            return "Choose a reminder time later than now."
        case .outsideDay:
            return "Choose a reminder time within the day."
        }
    }

    // MARK: - "N minutes/hours before" offset input (Google-Calendar style)

    /// The two lead-time units the offset input offers.
    public enum Unit: String, CaseIterable, Sendable {
        case minutes
        case hours

        /// Minutes contributed by one step of this unit.
        public var minutesPerStep: Int { self == .hours ? 60 : 1 }
    }

    /// Convert an `(amount, unit)` lead time into minutes-before-start.
    /// A negative amount clamps to 0 ("at start time").
    public static func offsetMinutes(amount: Int, unit: Unit) -> Int {
        max(0, amount) * unit.minutesPerStep
    }

    /// Decompose a minutes-before-start offset into the `(amount, unit)` the
    /// editor displays: whole hours render as hours, everything else (and any
    /// negative, which a dragged block can produce) as minutes.
    public static func split(offsetMinutes: Int) -> (amount: Int, unit: Unit) {
        guard offsetMinutes > 0 else { return (0, .minutes) }
        if offsetMinutes % 60 == 0 { return (offsetMinutes / 60, .hours) }
        return (offsetMinutes, .minutes)
    }
}
