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
    public var item: TaskItem?
    public var day: Day?

    public init(
        startMinute: Int,
        durationMinutes: Int,
        colorIndex: Int = 0,
        item: TaskItem? = nil,
        day: Day? = nil
    ) {
        self.id = UUID()
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.isCompleted = false
        self.completedAt = nil
        self.colorIndex = colorIndex
        self.item = item
        self.day = day
    }

    public var endMinute: Int { startMinute + durationMinutes }
}
