import Foundation
import SwiftData

@Model
public final class TaskItem {
    @Attribute(.unique) public var id: UUID = UUID()
    public var title: String = ""
    public var createdAt: Date = Date()
    public var notes: String = ""
    public var tags: [String] = []
    public var isBacklog: Bool = false
    public var day: Day?

    public init(
        title: String,
        createdAt: Date = Date(),
        notes: String = "",
        tags: [String] = [],
        isBacklog: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.notes = notes
        self.tags = tags
        self.isBacklog = isBacklog
    }
}
