import Foundation

/// Value snapshot of a backlog item (only its age matters for the digest).
public struct BacklogInput: Equatable, Sendable {
    public let createdAt: Date
    public init(createdAt: Date) { self.createdAt = createdAt }
}

/// Computes the once-a-day backlog-age digest notification.
///
/// The notification is a *repeating* daily trigger; its body reflects the count
/// at the time it was last armed (see the design's "as of your last visit"
/// limitation — notification bodies are static and the app is not always
/// running, so the count is refreshed whenever the app re-arms it).
public enum BacklogDigestPlanner {
    public static let id = "backlog-digest"

    public static func overdueCount(inputs: [BacklogInput], thresholdDays: Int,
                                    now: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        return inputs.filter { input in
            let created = calendar.startOfDay(for: input.createdAt)
            let days = calendar.dateComponents([.day], from: created, to: today).day ?? 0
            return days > thresholdDays
        }.count
    }

    public static func plan(inputs: [BacklogInput], enabled: Bool, thresholdDays: Int,
                            hour: Int, minute: Int, now: Date,
                            calendar: Calendar = .current) -> PlannedNotification? {
        guard enabled else { return nil }
        let count = overdueCount(inputs: inputs, thresholdDays: thresholdDays, now: now, calendar: calendar)
        guard count > 0 else { return nil }
        let noun = count == 1 ? "task has" : "tasks have"
        return PlannedNotification(
            id: id,
            title: "Backlog needs attention",
            body: "\(count) \(noun) been in your backlog over \(thresholdDays) days (as of your last visit).",
            trigger: .dailyAt(hour: hour, minute: minute))
    }
}
