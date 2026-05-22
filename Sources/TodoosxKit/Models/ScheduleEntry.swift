import Foundation
import SwiftData

@Model
public final class ScheduleEntry {
    @Attribute(.unique) public var id: UUID = UUID()
    public var startHour: Int = 0
    public var durationHours: Int = 1
    public var isCompleted: Bool = false
    public var completedAt: Date?
    public var colorIndex: Int = 0
    public var item: TaskItem?
    public var day: Day?

    public init(
        startHour: Int,
        durationHours: Int,
        colorIndex: Int = 0,
        item: TaskItem? = nil,
        day: Day? = nil
    ) {
        self.id = UUID()
        self.startHour = startHour
        self.durationHours = durationHours
        self.isCompleted = false
        self.completedAt = nil
        self.colorIndex = colorIndex
        self.item = item
        self.day = day
    }
}
