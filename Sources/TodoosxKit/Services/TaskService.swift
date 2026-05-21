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

    public func escalate(_ item: TaskItem, on day: Day) throws {
        if day.top3ItemIDs.contains(item.id) { return }
        guard day.top3ItemIDs.count < 3 else { throw TodoError.top3Full }
        day.top3ItemIDs.append(item.id)
        try? context.save()
    }

    public func deescalate(_ item: TaskItem, on day: Day) {
        day.top3ItemIDs.removeAll { $0 == item.id }
        try? context.save()
    }

    public func reorderTop3(on day: Day, ids: [UUID]) {
        let existing = Set(day.top3ItemIDs)
        let filtered = ids.filter { existing.contains($0) }
        guard Set(filtered) == existing else { return }
        day.top3ItemIDs = filtered
        try? context.save()
    }
}
