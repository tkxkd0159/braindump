import Foundation
import SwiftData

@Model
public final class ScheduleEntry {
    @Attribute(.unique) public var id: UUID = UUID()
    public var startMinute: Int = 0
    public var durationMinutes: Int = 60
    public var isCompleted: Bool = false
    public var completedAt: Date?
    public var colorIndex: Int = 0
    /// Arbitrary `#RRGGBB` color overriding `colorIndex` when non-nil. Lets the
    /// user pick any color beyond the curated palette. Added as an additive
    /// optional (SwiftData lightweight migration).
    public var customColorHex: String?
    /// Legacy minutes-before-start reminder lead time (schema V2). Superseded by
    /// `reminderMinuteOfDay`; retained so existing stored reminders keep firing.
    public var reminderOffsetMinutes: Int?
    /// Absolute reminder time as a minute-of-day on the entry's day; `nil` means
    /// no reminder. The custom time picker writes this.
    public var reminderMinuteOfDay: Int?
    public var item: TaskItem?
    public var day: Day?

    public init(
        startMinute: Int,
        durationMinutes: Int,
        colorIndex: Int = 0,
        customColorHex: String? = nil,
        reminderOffsetMinutes: Int? = nil,
        reminderMinuteOfDay: Int? = nil,
        item: TaskItem? = nil,
        day: Day? = nil
    ) {
        self.id = UUID()
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.isCompleted = false
        self.completedAt = nil
        self.colorIndex = colorIndex
        self.customColorHex = customColorHex
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.reminderMinuteOfDay = reminderMinuteOfDay
        self.item = item
        self.day = day
    }

    public var endMinute: Int { startMinute + durationMinutes }
}
