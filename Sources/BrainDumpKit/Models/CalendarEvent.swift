import Foundation

/// A concrete calendar occurrence rendered in the Schedule grid. In-memory +
/// disk-cached only (never SwiftData). `id` is stable across refreshes so
/// SwiftUI diffing is well-behaved.
public struct CalendarEvent: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var feedID: UUID
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var colorIndex: Int
    /// Arbitrary `#RRGGBB` color (mirrors the feed's custom color) overriding
    /// `colorIndex` when non-nil. Optional so older disk caches decode to nil.
    public var customColorHex: String?

    public init(
        id: String,
        feedID: UUID,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        colorIndex: Int,
        customColorHex: String? = nil
    ) {
        self.id = id
        self.feedID = feedID
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.colorIndex = colorIndex
        self.customColorHex = customColorHex
    }

    /// True if `[start, end)` overlaps the local calendar day containing `date`.
    public func intersects(_ date: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        return start < dayEnd && end > dayStart
    }

    /// Minutes-since-midnight range on the day containing `date`, clamped to
    /// `[0, 1440]`. Returns nil for all-day events or when there is no overlap.
    public func minuteRange(on date: Date, calendar: Calendar = .current) -> Range<Int>? {
        guard !isAllDay else { return nil }
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        let lo = max(start, dayStart)
        let hi = min(end, dayEnd)
        guard lo < hi else { return nil }
        let startMin = max(0, min(1440, Int(lo.timeIntervalSince(dayStart) / 60)))
        let endMin = max(0, min(1440, Int(hi.timeIntervalSince(dayStart) / 60)))
        guard startMin < endMin else { return nil }
        return startMin..<endMin
    }
}
