import Foundation

/// Parsed `RRULE`. Common subset only (per design): FREQ, INTERVAL, COUNT,
/// UNTIL, BYDAY. Exotic parts (BYSETPOS, BYWEEKNO, BYMONTHDAY, …) are ignored.
public struct RecurrenceRule: Equatable, Sendable {
    public enum Frequency: String, Sendable {
        case daily = "DAILY", weekly = "WEEKLY", monthly = "MONTHLY", yearly = "YEARLY"
    }

    public enum Weekday: String, Sendable, CaseIterable {
        case su = "SU", mo = "MO", tu = "TU", we = "WE", th = "TH", fr = "FR", sa = "SA"
        /// 1=Sunday … 7=Saturday, matching `Calendar.component(.weekday, …)`.
        public var calendarWeekday: Int {
            switch self {
            case .su: return 1; case .mo: return 2; case .tu: return 3; case .we: return 4
            case .th: return 5; case .fr: return 6; case .sa: return 7
            }
        }
    }

    public var frequency: Frequency
    public var interval: Int
    public var count: Int?
    public var until: Date?
    public var byDay: [Weekday]

    public init(frequency: Frequency, interval: Int = 1, count: Int? = nil,
                until: Date? = nil, byDay: [Weekday] = []) {
        self.frequency = frequency
        self.interval = interval
        self.count = count
        self.until = until
        self.byDay = byDay
    }

    /// Parse an RRULE value, e.g. `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;UNTIL=20260701T000000Z`.
    /// Returns nil if FREQ is missing/unrecognized.
    public static func parse(_ value: String) -> RecurrenceRule? {
        var parts: [String: String] = [:]
        for token in value.split(separator: ";") {
            let kv = token.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            parts[kv[0].uppercased()] = String(kv[1])
        }
        guard let freqRaw = parts["FREQ"], let freq = Frequency(rawValue: freqRaw.uppercased()) else {
            return nil
        }
        let interval = parts["INTERVAL"].flatMap { Int($0) } ?? 1
        let count = parts["COUNT"].flatMap { Int($0) }
        let until = parts["UNTIL"].flatMap { ICalDate.parse($0, tzid: nil, isDateValue: false) }
        let byDay = (parts["BYDAY"] ?? "")
            .split(separator: ",")
            .compactMap { Weekday(rawValue: String($0).uppercased()) }
        return RecurrenceRule(frequency: freq, interval: max(1, interval), count: count, until: until, byDay: byDay)
    }
}
