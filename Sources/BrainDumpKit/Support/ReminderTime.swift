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
}
