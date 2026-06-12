import Foundation

/// Value snapshot of a schedule entry, so reminder planning is a pure function
/// of `now` (no live `@Model` access, trivially testable).
public struct ReminderInput: Equatable, Sendable {
    public let entryID: UUID
    public let dayStart: Date     // start-of-local-day of the entry's day
    public let startMinute: Int
    public let offsetMinutes: Int?
    public let isCompleted: Bool
    public let title: String

    public init(entryID: UUID, dayStart: Date, startMinute: Int,
                offsetMinutes: Int?, isCompleted: Bool, title: String) {
        self.entryID = entryID
        self.dayStart = dayStart
        self.startMinute = startMinute
        self.offsetMinutes = offsetMinutes
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
            guard let offset = input.offsetMinutes, !input.isCompleted else { return nil }
            let minuteOfDay = input.startMinute - offset
            guard minuteOfDay >= 0 else { return nil }                 // within the target day
            let fireDate = input.dayStart.addingTimeInterval(TimeInterval(minuteOfDay * 60))
            guard fireDate > now else { return nil }                   // not already passed
            let title = input.title.isEmpty ? "Scheduled task" : input.title
            return PlannedNotification(
                id: id(for: input.entryID),
                title: title,
                body: "Starts \(ReminderOffset.leadTimePhrase(offset)).",
                trigger: .at(fireDate))
        }
    }
}
