import Foundation
import SwiftData

@MainActor
public final class DayService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func day(for date: Date) -> Day {
        let target = date.startOfLocalDay()
        let predicate = #Predicate<Day> { $0.date == target }
        let descriptor = FetchDescriptor<Day>(predicate: predicate)
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let day = Day(date: target)
        context.insert(day)
        try? context.save()
        return day
    }

    public func incompleteItemCount(on day: Day) -> Int {
        day.items.filter { item in
            !day.schedule.contains { $0.item?.id == item.id && $0.isCompleted }
        }.count
    }

    public func totalItemCount(on day: Day) -> Int {
        day.items.count
    }

    /// Wipes every Day, TaskItem (including backlog), and ScheduleEntry from
    /// the store. The explicit per-table pass also removes backlog items,
    /// which have no Day parent to cascade through.
    public func clearAllData() {
        let entries = (try? context.fetch(FetchDescriptor<ScheduleEntry>())) ?? []
        for entry in entries { context.delete(entry) }
        let items = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        for item in items { context.delete(item) }
        let days = (try? context.fetch(FetchDescriptor<Day>())) ?? []
        for day in days { context.delete(day) }
        try? context.save()
    }

    public func rollover(now: Date) {
        let today = now.startOfLocalDay()
        let todayDay = day(for: today)

        let pastDescriptor = FetchDescriptor<Day>(
            predicate: #Predicate<Day> { $0.date < today }
        )
        guard let pastDays = try? context.fetch(pastDescriptor) else { return }

        for past in pastDays {
            let itemsSnapshot = past.items
            for item in itemsSnapshot where !item.isBacklog {
                let completedHere = past.schedule.contains {
                    $0.item?.id == item.id && $0.isCompleted
                }
                if completedHere { continue }

                let toRemove = past.schedule.filter { $0.item?.id == item.id }
                for e in toRemove { context.delete(e) }

                past.top3ItemIDs.removeAll { $0 == item.id }
                item.day = todayDay
            }
        }
        try? context.save()
    }
}
