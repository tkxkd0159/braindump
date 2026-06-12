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
        startMinute: Int,
        durationMinutes: Int,
        colorIndex: Int = 0,
        reminderOffsetMinutes: Int? = nil
    ) throws -> ScheduleEntry {
        guard durationMinutes >= 15, startMinute >= 0, startMinute + durationMinutes <= 24 * 60 else {
            throw TodoError.scheduleOutOfRange
        }
        let newRange = startMinute..<(startMinute + durationMinutes)
        for existing in day.schedule {
            let existingRange = existing.startMinute..<(existing.startMinute + existing.durationMinutes)
            if newRange.overlaps(existingRange) {
                throw TodoError.scheduleConflict
            }
        }
        let entry = ScheduleEntry(
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            colorIndex: colorIndex,
            reminderOffsetMinutes: reminderOffsetMinutes,
            item: item,
            day: day
        )
        context.insert(entry)
        try? context.save()
        return entry
    }

    public func reschedule(
        _ entry: ScheduleEntry,
        startMinute: Int,
        durationMinutes: Int
    ) throws {
        guard durationMinutes >= 15, startMinute >= 0, startMinute + durationMinutes <= 24 * 60 else {
            throw TodoError.scheduleOutOfRange
        }
        let newRange = startMinute..<(startMinute + durationMinutes)
        if let day = entry.day {
            for existing in day.schedule where existing.id != entry.id {
                let existingRange = existing.startMinute..<(existing.startMinute + existing.durationMinutes)
                if newRange.overlaps(existingRange) {
                    throw TodoError.scheduleConflict
                }
            }
        }
        entry.startMinute = startMinute
        entry.durationMinutes = durationMinutes
        // Drop a reminder that can no longer fire within the day after the move
        // (e.g. a 1-hour lead on a block pushed to 00:30) so no stale offset lingers.
        if !ReminderOffset.isValid(entry.reminderOffsetMinutes, startMinute: startMinute) {
            entry.reminderOffsetMinutes = nil
        }
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

    /// Set (or clear, with `nil`) the reminder lead time on a schedule entry.
    public func setReminderOffset(_ entry: ScheduleEntry, _ offset: Int?) {
        entry.reminderOffsetMinutes = offset
        try? context.save()
    }
}
