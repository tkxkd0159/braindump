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
        customColorHex: String? = nil,
        reminderMinuteOfDay: Int? = nil,
        additionalBusyRanges: [Range<Int>] = []
    ) throws -> ScheduleEntry {
        guard durationMinutes >= 15, startMinute >= 0, startMinute + durationMinutes <= 24 * 60 else {
            throw TodoError.scheduleOutOfRange
        }
        let newRange = startMinute..<(startMinute + durationMinutes)
        let existingRanges = day.schedule.map { $0.startMinute..<($0.startMinute + $0.durationMinutes) }
        for existingRange in existingRanges + additionalBusyRanges {
            if newRange.overlaps(existingRange) {
                throw TodoError.scheduleConflict
            }
        }
        let entry = ScheduleEntry(
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            colorIndex: colorIndex,
            customColorHex: customColorHex,
            reminderMinuteOfDay: reminderMinuteOfDay,
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
        durationMinutes: Int,
        additionalBusyRanges: [Range<Int>] = []
    ) throws {
        guard durationMinutes >= 15, startMinute >= 0, startMinute + durationMinutes <= 24 * 60 else {
            throw TodoError.scheduleOutOfRange
        }
        let newRange = startMinute..<(startMinute + durationMinutes)
        var ranges = additionalBusyRanges
        if let day = entry.day {
            ranges += day.schedule
                .filter { $0.id != entry.id }
                .map { $0.startMinute..<($0.startMinute + $0.durationMinutes) }
        }
        for existingRange in ranges {
            if newRange.overlaps(existingRange) {
                throw TodoError.scheduleConflict
            }
        }
        entry.startMinute = startMinute
        entry.durationMinutes = durationMinutes
        // An absolute reminder is independent of placement, so moving the block
        // deliberately leaves it untouched.
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

    /// Select a preset palette color. Clears any custom override so the preset
    /// is what renders.
    public func setColorIndex(_ entry: ScheduleEntry, _ index: Int) {
        entry.colorIndex = max(0, min(Theme.BlockPalette.colors.count - 1, index))
        entry.customColorHex = nil
        try? context.save()
    }

    /// Set (or clear, with `nil`) an arbitrary custom color overriding the preset.
    public func setCustomColor(_ entry: ScheduleEntry, _ hex: String?) {
        entry.customColorHex = hex
        try? context.save()
    }

    /// Set (or clear, with `nil`) the absolute reminder time on a schedule entry.
    /// Editing the reminder also retires any legacy lead-time offset, so the
    /// AppState bridge never resurrects an old reminder after this one is cleared.
    public func setReminderMinuteOfDay(_ entry: ScheduleEntry, _ minuteOfDay: Int?) {
        entry.reminderMinuteOfDay = minuteOfDay
        entry.reminderOffsetMinutes = nil
        try? context.save()
    }
}
