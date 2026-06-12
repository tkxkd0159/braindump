import Foundation

/// One VEVENT after parsing, with DTSTART/DTEND resolved to absolute `Date`s.
/// Recurrence is represented but not yet expanded.
public struct ParsedICalEvent: Equatable, Sendable {
    public var uid: String
    public var summary: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var rrule: RecurrenceRule?
    public var exDates: [Date]
    public var recurrenceID: Date?
}

public enum ICalParser {
    /// Parse ICS text into events. Malformed VEVENTs are skipped, never fatal.
    public static func parse(_ ics: String, calendar: Calendar = .current) -> [ParsedICalEvent] {
        let lines = unfold(ics)
        var events: [ParsedICalEvent] = []
        var inEvent = false
        var props: [(name: String, params: [String: String], value: String)] = []

        for line in lines {
            if line == "BEGIN:VEVENT" {
                inEvent = true; props = []; continue
            }
            if line == "END:VEVENT" {
                inEvent = false
                if let e = makeEvent(props, calendar: calendar) { events.append(e) }
                continue
            }
            guard inEvent, let parsed = parseProperty(line) else { continue }
            props.append(parsed)
        }
        return events
    }

    /// RFC-5545 line unfolding: a line starting with space or tab continues the
    /// previous one. Handles CRLF and LF.
    static func unfold(_ ics: String) -> [String] {
        let raw = ics.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var result: [String] = []
        for line in raw {
            if let first = line.first, first == " " || first == "\t", !result.isEmpty {
                result[result.count - 1] += line.dropFirst()
            } else {
                result.append(line)
            }
        }
        return result
    }

    /// Split `NAME;PARAM=v;PARAM2=w:VALUE` into (name, params, value).
    static func parseProperty(_ line: String) -> (name: String, params: [String: String], value: String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let lhs = String(line[line.startIndex..<colon])
        let value = String(line[line.index(after: colon)...])
        let segments = lhs.split(separator: ";").map(String.init)
        guard let name = segments.first?.uppercased() else { return nil }
        var params: [String: String] = [:]
        for seg in segments.dropFirst() {
            let kv = seg.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { params[kv[0].uppercased()] = String(kv[1]) }
        }
        return (name, params, value)
    }

    private static func makeEvent(
        _ props: [(name: String, params: [String: String], value: String)],
        calendar: Calendar
    ) -> ParsedICalEvent? {
        var uid = ""
        var summary = ""
        var start: Date?
        var startIsDate = false
        var end: Date?
        var duration: DateComponents?
        var rrule: RecurrenceRule?
        var exDates: [Date] = []
        var recurrenceID: Date?

        for p in props {
            let isDate = p.params["VALUE"]?.uppercased() == "DATE"
            switch p.name {
            case "UID": uid = p.value
            case "SUMMARY": summary = unescapeText(p.value)
            case "DTSTART":
                start = ICalDate.parse(p.value, tzid: p.params["TZID"], isDateValue: isDate, calendar: calendar)
                startIsDate = isDate
            case "DTEND":
                end = ICalDate.parse(p.value, tzid: p.params["TZID"], isDateValue: isDate, calendar: calendar)
            case "DURATION":
                duration = parseDuration(p.value)
            case "RRULE":
                rrule = RecurrenceRule.parse(p.value)
            case "EXDATE":
                for v in p.value.split(separator: ",") {
                    if let d = ICalDate.parse(String(v), tzid: p.params["TZID"], isDateValue: isDate, calendar: calendar) {
                        exDates.append(d)
                    }
                }
            case "RECURRENCE-ID":
                recurrenceID = ICalDate.parse(p.value, tzid: p.params["TZID"], isDateValue: isDate, calendar: calendar)
            default: break
            }
        }

        guard let start else { return nil }
        let resolvedEnd: Date
        if let end {
            resolvedEnd = end
        } else if let duration, let d = calendar.date(byAdding: duration, to: start) {
            resolvedEnd = d
        } else if startIsDate {
            resolvedEnd = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        } else {
            resolvedEnd = start
        }

        return ParsedICalEvent(
            uid: uid, summary: summary, start: start, end: resolvedEnd,
            isAllDay: startIsDate, rrule: rrule, exDates: exDates, recurrenceID: recurrenceID)
    }

    /// Unescape RFC-5545 TEXT: `\n`/`\N` → newline, `\,` `\;` `\\` literal.
    static func unescapeText(_ s: String) -> String {
        var out = ""
        var iter = s.makeIterator()
        while let c = iter.next() {
            if c == "\\" {
                if let n = iter.next() {
                    switch n {
                    case "n", "N": out.append("\n")
                    case ",", ";", "\\": out.append(n)
                    default: out.append(n)
                    }
                }
            } else {
                out.append(c)
            }
        }
        return out
    }

    /// Parse an ISO-8601 duration like `PT1H30M`, `P1D`, `PT45M` into components.
    static func parseDuration(_ s: String) -> DateComponents? {
        guard s.hasPrefix("P") else { return nil }
        var comps = DateComponents()
        var number = ""
        var inTime = false
        for ch in s.dropFirst() {
            if ch == "T" { inTime = true; continue }
            if ch.isNumber { number.append(ch); continue }
            let n = Int(number) ?? 0
            number = ""
            switch ch {
            case "W": comps.day = (comps.day ?? 0) + n * 7
            case "D": comps.day = (comps.day ?? 0) + n
            case "H": comps.hour = (comps.hour ?? 0) + n
            case "M": if inTime { comps.minute = (comps.minute ?? 0) + n }
            case "S": comps.second = (comps.second ?? 0) + n
            default: break
            }
        }
        return comps
    }
}
