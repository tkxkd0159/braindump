import Foundation

/// Reminder lead-time presets for scheduled blocks. A reminder fires
/// `offsetMinutes` before the block starts; `nil` means no reminder.
/// "Within the target day" => `startMinute - offset >= 0` (never crosses
/// midnight into the previous day), matching the daily-timebox concept.
public enum ReminderOffset {
    /// Minutes-before-start presets offered in the picker (0 == at start time).
    public static let presets: [Int] = [0, 5, 10, 15, 30, 60, 120]

    public static func label(_ offset: Int?) -> String {
        guard let offset else { return "None" }
        if offset == 0 { return "At start time" }
        return "\(unit(offset)) before"
    }

    public static func isValid(_ offset: Int?, startMinute: Int) -> Bool {
        guard let offset else { return true }
        return startMinute - offset >= 0
    }

    public static func validPresets(startMinute: Int) -> [Int] {
        presets.filter { isValid($0, startMinute: startMinute) }
    }

    /// Phrase used inside a reminder body, e.g. "in 30 minutes" / "now".
    public static func leadTimePhrase(_ offset: Int) -> String {
        offset == 0 ? "now" : "in \(unit(offset))"
    }

    private static func unit(_ minutes: Int) -> String {
        if minutes % 60 == 0 {
            let h = minutes / 60
            return "\(h) hour\(h == 1 ? "" : "s")"
        }
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}
