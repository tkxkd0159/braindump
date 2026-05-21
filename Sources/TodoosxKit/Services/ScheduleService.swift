import Foundation
import SwiftData

@MainActor
public final class ScheduleService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func schedule(
        _ item: TaskItem,
        on day: Day,
        startHour: Int,
        durationHours: Int
    ) throws -> ScheduleEntry {
        guard durationHours >= 1, startHour >= 5, startHour + durationHours <= 24 else {
            throw TodoError.scheduleOutOfRange
        }
        let newRange = startHour..<(startHour + durationHours)
        for existing in day.schedule {
            let existingRange = existing.startHour..<(existing.startHour + existing.durationHours)
            if newRange.overlaps(existingRange) {
                throw TodoError.scheduleConflict
            }
        }
        let entry = ScheduleEntry(
            startHour: startHour,
            durationHours: durationHours,
            item: item,
            day: day
        )
        context.insert(entry)
        try? context.save()
        return entry
    }
}
