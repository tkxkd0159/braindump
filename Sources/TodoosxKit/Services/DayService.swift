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

    public func rollover(now: Date) {
        let today = now.startOfLocalDay()
        let todayDay = day(for: today)

        let pastDescriptor = FetchDescriptor<Day>(
            predicate: #Predicate<Day> { $0.date < today }
        )
        guard let pastDays = try? context.fetch(pastDescriptor) else { return }

        for past in pastDays {
            let itemsSnapshot = past.items
            for item in itemsSnapshot {
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
