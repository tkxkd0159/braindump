import Foundation
import SwiftData

@MainActor
public final class BacklogService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func addBacklogItem(
        title: String,
        notes: String = "",
        tags: [String] = []
    ) -> TaskItem {
        let item = TaskItem(
            title: title,
            notes: notes,
            tags: Self.normalize(tags: tags),
            isBacklog: true
        )
        context.insert(item)
        try? context.save()
        return item
    }

    private static func normalize(tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    public func listBacklog() -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.isBacklog == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func promoteToBrainDump(_ item: TaskItem, on day: Day) {
        item.isBacklog = false
        item.day = day
        try? context.save()
    }

    /// Move a brain-dump item back into the backlog. Removes the item from
    /// its day's top-3 priority list (if present) and deletes any schedule
    /// entries that referenced it.
    public func moveToBacklog(_ item: TaskItem) {
        if let day = item.day {
            day.top3ItemIDs.removeAll { $0 == item.id }
            let entries = day.schedule.filter { $0.item?.id == item.id }
            for entry in entries { context.delete(entry) }
        }
        item.day = nil
        item.isBacklog = true
        try? context.save()
    }

    public func delete(_ item: TaskItem) {
        context.delete(item)
        try? context.save()
    }
}
