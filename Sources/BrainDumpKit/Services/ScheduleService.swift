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
        durationHours: Int,
        colorIndex: Int = 0
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
            colorIndex: colorIndex,
            item: item,
            day: day
        )
        context.insert(entry)
        try? context.save()
        return entry
    }

    public func reschedule(
        _ entry: ScheduleEntry,
        startHour: Int,
        durationHours: Int
    ) throws {
        guard durationHours >= 1, startHour >= 5, startHour + durationHours <= 24 else {
            throw TodoError.scheduleOutOfRange
        }
        let newRange = startHour..<(startHour + durationHours)
        if let day = entry.day {
            for existing in day.schedule where existing.id != entry.id {
                let existingRange = existing.startHour..<(existing.startHour + existing.durationHours)
                if newRange.overlaps(existingRange) {
                    throw TodoError.scheduleConflict
                }
            }
        }
        entry.startHour = startHour
        entry.durationHours = durationHours
        try? context.save()
    }

    public func unschedule(_ entry: ScheduleEntry) {
        context.delete(entry)
        try? context.save()
    }

    public func setCompleted(_ entry: ScheduleEntry, _ completed: Bool) {
        entry.isCompleted = completed
        entry.completedAt = completed ? Date() : nil
        try? context.save()
    }

    public func setColorIndex(_ entry: ScheduleEntry, _ index: Int) {
        entry.colorIndex = max(0, min(Theme.BlockPalette.colors.count - 1, index))
        try? context.save()
    }
}
