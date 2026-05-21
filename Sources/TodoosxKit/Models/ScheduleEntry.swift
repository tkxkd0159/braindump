import Foundation
import SwiftData

@Model
public final class ScheduleEntry {
    @Attribute(.unique) public var id: UUID
    public var startHour: Int
    public var durationHours: Int
    public var isCompleted: Bool
    public var item: TaskItem?
    public var day: Day?

    public init(startHour: Int, durationHours: Int, item: TaskItem? = nil, day: Day? = nil) {
        self.id = UUID()
        self.startHour = startHour
        self.durationHours = durationHours
        self.isCompleted = false
        self.item = item
        self.day = day
    }
}
