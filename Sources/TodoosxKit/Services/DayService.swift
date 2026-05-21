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
}
