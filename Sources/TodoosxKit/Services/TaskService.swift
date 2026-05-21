import Foundation
import SwiftData

@MainActor
public final class TaskService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func addBrainDumpItem(title: String, on day: Day) -> TaskItem {
        let item = TaskItem(title: title)
        item.day = day
        context.insert(item)
        try? context.save()
        return item
    }

    public func rename(_ item: TaskItem, to title: String) {
        item.title = title
        try? context.save()
    }

    public func delete(_ item: TaskItem) {
        if let day = item.day {
            day.top3ItemIDs.removeAll { $0 == item.id }
        }
        context.delete(item)
        try? context.save()
    }
}
