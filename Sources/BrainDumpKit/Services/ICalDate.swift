import Foundation

/// Low-level iCal date/date-time value parser. Deterministic integer slicing
/// (no DateFormatter) so it is timezone-explicit and unit-testable.
public enum ICalDate {
    /// Parse a value like `20260522T093000Z`, `20260522T093000`, or `20260522`.
    /// - `tzid`: IANA zone from a `TZID=` parameter, if present.
    /// - `isDateValue`: true when the property had `VALUE=DATE` (all-day).
    /// Resolution: trailing `Z` → UTC; else `tzid` → that zone; else local
    /// (floating). Date-only values resolve to start-of-day in the chosen zone.
    public static func parse(_ raw: String, tzid: String?, isDateValue: Bool, calendar: Calendar = .current) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        let isUTC = value.hasSuffix("Z")
        let core = isUTC ? String(value.dropLast()) : value

        let datePart: String
        let timePart: String?
        if let tIndex = core.firstIndex(of: "T") {
            datePart = String(core[core.startIndex..<tIndex])
            timePart = String(core[core.index(after: tIndex)...])
        } else {
            datePart = core
            timePart = nil
        }
        guard datePart.count == 8,
              let year = Int(datePart.prefix(4)),
              let month = Int(datePart.dropFirst(4).prefix(2)),
              let day = Int(datePart.dropFirst(6).prefix(2))
        else { return nil }

        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day

        if isDateValue || timePart == nil {
            comps.hour = 0; comps.minute = 0; comps.second = 0
        } else if let t = timePart, t.count >= 6,
                  let hh = Int(t.prefix(2)), let mm = Int(t.dropFirst(2).prefix(2)),
                  let ss = Int(t.dropFirst(4).prefix(2)) {
            comps.hour = hh; comps.minute = mm; comps.second = ss
        } else {
            return nil
        }

        var cal = calendar
        if isUTC {
            cal.timeZone = TimeZone(identifier: "UTC")!
        } else if let tzid, let zone = TimeZone(identifier: tzid) {
            cal.timeZone = zone
        }
        return cal.date(from: comps)
    }
}
