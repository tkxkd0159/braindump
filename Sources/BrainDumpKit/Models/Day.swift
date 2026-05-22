import Foundation
import SwiftData

@Model
public final class Day {
    @Attribute(.unique) public var date: Date
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.day)
    public var items: [TaskItem] = []
    @Relationship(deleteRule: .cascade, inverse: \ScheduleEntry.day)
    public var schedule: [ScheduleEntry] = []
    public var top3ItemIDs: [UUID] = []

    public init(date: Date) {
        self.date = date.startOfLocalDay()
    }
}
