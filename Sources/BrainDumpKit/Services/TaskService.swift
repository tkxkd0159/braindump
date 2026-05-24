import Foundation
import SwiftData

@MainActor
public final class TaskService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func addBrainDumpItem(
        title: String,
        notes: String = "",
        tags: [String] = [],
        on day: Day
    ) -> TaskItem {
        let item = TaskItem(title: title, notes: notes, tags: Self.normalize(tags: tags))
        item.day = day
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

    public func rename(_ item: TaskItem, to title: String) {
        item.title = title
        try? context.save()
    }

    public func updateNotes(_ item: TaskItem, notes: String) {
        item.notes = notes
        try? context.save()
    }

    public func updateTags(_ item: TaskItem, tags: [String]) {
        item.tags = Self.normalize(tags: tags)
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

    /// Drop-onto-slot handler used by drag-and-drop into Top3.
    /// - Item already in Top3: swap with the item at `targetIndex` (or move-to-end
    ///   when target is past the dense array's bounds).
    /// - Item not in Top3 + slot occupied: replace; the displaced item falls out
    ///   of Top3 (back to brain dump).
    /// - Item not in Top3 + slot empty (target ≥ count) + room available: append.
    /// - Item not in Top3 + Top3 full + target past end: no-op.
    public func moveToTop3Slot(_ item: TaskItem, at targetIndex: Int, on day: Day) {
        var ids = day.top3ItemIDs
        let original = ids
        if let oldIndex = ids.firstIndex(of: item.id) {
            if targetIndex < ids.count {
                ids.swapAt(oldIndex, targetIndex)
            } else {
                ids.remove(at: oldIndex)
                ids.append(item.id)
            }
        } else if targetIndex < ids.count {
            ids[targetIndex] = item.id
        } else if ids.count < 3 {
            ids.append(item.id)
        } else {
            return
        }
        if ids == original { return }
        day.top3ItemIDs = ids
        try? context.save()
    }

    public func reorderTop3(on day: Day, ids: [UUID]) {
        let existing = Set(day.top3ItemIDs)
        let filtered = ids.filter { existing.contains($0) }
        guard Set(filtered) == existing else { return }
        day.top3ItemIDs = filtered
        try? context.save()
    }

    /// All distinct tags across every task (brain-dump and backlog), sorted
    /// alphabetically. Tags are a global vocabulary so suggestions surface
    /// regardless of where a tag was first attached.
    public func allTags() -> [String] {
        let descriptor = FetchDescriptor<TaskItem>()
        guard let items = try? context.fetch(descriptor) else { return [] }
        var set = Set<String>()
        for item in items {
            for tag in item.tags { set.insert(tag) }
        }
        return set.sorted()
    }

    /// Client-side search across non-backlog tasks.
    /// - keyword: matched (case-insensitive substring) against title and notes
    /// - tag: requires exact membership in item.tags
    /// - completedOnly: when true (and `completedRange` is nil), keeps only items
    ///   with at least one completed ScheduleEntry
    /// - completedRange: requires at least one ScheduleEntry on the item with
    ///   `completedAt` within the range (uncompleted items never match this filter).
    ///   A non-nil range implies `completedOnly`.
    public func searchTasks(
        keyword: String?,
        tag: String?,
        completedOnly: Bool = false,
        completedRange: ClosedRange<Date>? = nil
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
        } else if completedOnly {
            items = items.filter { item in
                guard let day = item.day else { return false }
                return day.schedule.contains { entry in
                    entry.item?.id == item.id && entry.isCompleted
                }
            }
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }
}
