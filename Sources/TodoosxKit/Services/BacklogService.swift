import Foundation
import SwiftData

@MainActor
public final class BacklogService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func addBacklogItem(title: String) -> TaskItem {
        let item = TaskItem(title: title, isBacklog: true)
        context.insert(item)
        try? context.save()
        return item
    }

    public func listBacklog() -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>()
        guard let items = try? context.fetch(descriptor) else { return [] }
        return items
            .filter { $0.isBacklog }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func promoteToBrainDump(_ item: TaskItem, on day: Day) {
        item.isBacklog = false
        item.day = day
        try? context.save()
    }

    public func delete(_ item: TaskItem) {
        context.delete(item)
        try? context.save()
    }
}
