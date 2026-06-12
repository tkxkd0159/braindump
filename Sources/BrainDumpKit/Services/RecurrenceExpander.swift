import Foundation

/// Expands a `ParsedICalEvent` into concrete `(start, end)` occurrences within a
/// bounded window. Applies EXDATE. Does NOT apply RECURRENCE-ID overrides — the
/// CalendarService grafts those on. Common subset only.
public enum RecurrenceExpander {
    /// Safety cap so an unbounded rule (no COUNT/UNTIL) always terminates.
    static let maxIterations = 1000

    public static func occurrences(
        of event: ParsedICalEvent,
        in window: Range<Date>,
        calendar: Calendar = .current
    ) -> [(start: Date, end: Date)] {
        let duration = event.end.timeIntervalSince(event.start)

        guard let rule = event.rrule else {
            // Single event: include if it overlaps the window.
            if event.start < window.upperBound && event.end > window.lowerBound {
                return [(event.start, event.end)]
            }
            return []
        }

        let exSet = Set(event.exDates.map { $0.timeIntervalSinceReferenceDate.rounded() })
        var results: [(start: Date, end: Date)] = []
        var emitted = 0
        var iterations = 0

        func consider(_ start: Date) -> Bool {
            // Returns false when generation should stop (count/until exceeded).
            if let count = rule.count, emitted >= count { return false }
            if let until = rule.until, start > until { return false }
            emitted += 1
            let isExcluded = exSet.contains(start.timeIntervalSinceReferenceDate.rounded())
            if !isExcluded, start < window.upperBound, start >= window.lowerBound {
                results.append((start, start.addingTimeInterval(duration)))
            }
            return true
        }

        switch rule.frequency {
        case .weekly where !rule.byDay.isEmpty:
            // Walk week by week; within each active week emit each BYDAY weekday.
            let targetWeekdays = Set(rule.byDay.map { $0.calendarWeekday })
            var weekAnchor = startOfWeek(event.start, calendar: calendar)
            outer: while iterations < Self.maxIterations {
                iterations += 1
                for offset in 0..<7 {
                    guard let day = calendar.date(byAdding: .day, value: offset, to: weekAnchor) else { continue }
                    let occ = combine(day: day, timeFrom: event.start, calendar: calendar)
                    guard occ >= event.start else { continue }
                    guard targetWeekdays.contains(calendar.component(.weekday, from: occ)) else { continue }
                    if !consider(occ) { break outer }
                }
                guard let next = calendar.date(byAdding: .weekOfYear, value: rule.interval, to: weekAnchor) else { break }
                weekAnchor = next
                if next >= window.upperBound { break }
            }
        default:
            let component: Calendar.Component = {
                switch rule.frequency {
                case .daily: return .day
                case .weekly: return .weekOfYear
                case .monthly: return .month
                case .yearly: return .year
                }
            }()
            var current = event.start
            while iterations < Self.maxIterations {
                iterations += 1
                if !consider(current) { break }
                guard let next = calendar.date(byAdding: component, value: rule.interval, to: current) else { break }
                current = next
                if current >= window.upperBound { break }
            }
        }
        return results
    }

    private static func startOfWeek(_ date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    /// Combine the calendar day of `day` with the hour/minute/second of `timeFrom`.
    private static func combine(day: Date, timeFrom: Date, calendar: Calendar) -> Date {
        let t = calendar.dateComponents([.hour, .minute, .second], from: timeFrom)
        var d = calendar.dateComponents([.year, .month, .day], from: day)
        d.hour = t.hour; d.minute = t.minute; d.second = t.second
        return calendar.date(from: d) ?? day
    }
}
