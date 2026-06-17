import Foundation

/// Value snapshot of a schedule entry, so reminder planning is a pure function
/// of `now` (no live `@Model` access, trivially testable).
public struct ReminderInput: Equatable, Sendable {
    public let entryID: UUID
    public let dayStart: Date     // start-of-local-day of the entry's day
    public let startMinute: Int
    /// Absolute reminder time as a minute-of-day on `dayStart`; `nil` = no reminder.
    public let reminderMinuteOfDay: Int?
    public let isCompleted: Bool
    public let title: String

    public init(entryID: UUID, dayStart: Date, startMinute: Int,
                reminderMinuteOfDay: Int?, isCompleted: Bool, title: String) {
        self.entryID = entryID
        self.dayStart = dayStart
        self.startMinute = startMinute
        self.reminderMinuteOfDay = reminderMinuteOfDay
        self.isCompleted = isCompleted
        self.title = title
    }
}

/// Computes the reminder notifications a day's schedule should have right now.
public enum ScheduleReminderPlanner {
    public static let idPrefix = "schedule-reminder-"
    public static func id(for entryID: UUID) -> String { idPrefix + entryID.uuidString }

    public static func plan(inputs: [ReminderInput], now: Date) -> [PlannedNotification] {
        inputs.compactMap { input in
            guard let minuteOfDay = input.reminderMinuteOfDay, !input.isCompleted else { return nil }
            // Must be a real time-of-day on the entry's day and still in the future.
            guard ReminderTime.validate(
                minuteOfDay: minuteOfDay, dayStart: input.dayStart, now: now) == .ok else { return nil }
            let fireDate = input.dayStart.addingTimeInterval(TimeInterval(minuteOfDay * 60))
            let title = input.title.isEmpty ? "Scheduled task" : input.title
            let lead = input.startMinute - minuteOfDay
            let body = lead >= 0 ? "Starts \(ReminderOffset.leadTimePhrase(lead))." : "In progress."
            return PlannedNotification(
                id: id(for: input.entryID),
                title: title,
                body: body,
                trigger: .at(fireDate))
        }
    }
}
