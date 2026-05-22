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

    public func updateNotes(_ item: TaskItem, notes: String) {
        item.notes = notes
        try? context.save()
    }

    public func updateTags(_ item: TaskItem, tags: [String]) {
        var seen = Set<String>()
        let cleaned = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
        item.tags = cleaned
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

    /// All distinct tags across non-backlog tasks, sorted alphabetically.
    public func allTags() -> [String] {
        let descriptor = FetchDescriptor<TaskItem>()
        guard let items = try? context.fetch(descriptor) else { return [] }
        var set = Set<String>()
        for item in items where !item.isBacklog {
            for tag in item.tags { set.insert(tag) }
        }
        return set.sorted()
    }

    /// Client-side search across non-backlog tasks.
    /// - keyword: matched (case-insensitive substring) against title and notes
    /// - tag: requires exact membership in item.tags
    /// - completedRange: requires at least one ScheduleEntry on the item with
    ///   `completedAt` within the range (uncompleted items never match this filter)
    public func searchTasks(
        keyword: String?,
        tag: String?,
        completedRange: ClosedRange<Date>?
    ) -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>()
        guard var items = try? context.fetch(descriptor) else { return [] }
        items = items.filter { !$0.isBacklog }

        if let keyword, !keyword.isEmpty {
            let needle = keyword.lowercased()
            items = items.filter { item in
                item.title.lowercased().contains(needle) || item.notes.lowercased().contains(needle)
            }
        }
        if let tag, !tag.isEmpty {
            items = items.filter { $0.tags.contains(tag) }
        }
        if let completedRange {
            items = items.filter { item in
                guard let day = item.day else { return false }
                return day.schedule.contains { entry in
                    entry.item?.id == item.id
                        && entry.isCompleted
                        && entry.completedAt.map { completedRange.contains($0) } ?? false
                }
            }
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }
}
