import Foundation
import SwiftData

@Model
public final class TaskItem {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var createdAt: Date
    public var day: Day?

    public init(title: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
    }
}
