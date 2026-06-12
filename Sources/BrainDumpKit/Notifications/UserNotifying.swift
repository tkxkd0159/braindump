import Foundation

/// When a planned notification should fire.
public enum NotificationTrigger: Equatable, Sendable {
    /// One-shot at an absolute date (schedule-block reminders).
    case at(Date)
    /// Repeating daily at wall-clock hour:minute (backlog digest).
    case dailyAt(hour: Int, minute: Int)
}

/// A backend-agnostic description of a local notification, so planners can be
/// pure values and the coordinator can be tested without `UNUserNotificationCenter`.
public struct PlannedNotification: Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let trigger: NotificationTrigger

    public init(id: String, title: String, body: String, trigger: NotificationTrigger) {
        self.id = id
        self.title = title
        self.body = body
        self.trigger = trigger
    }
}

public enum NotificationAuthorization: Sendable, Equatable {
    case notDetermined, authorized, denied
}

/// The slice of `UNUserNotificationCenter` the app needs, behind a protocol so
/// the coordinator is unit-testable with a spy (the real center cannot run
/// under `swift test`).
@MainActor
public protocol UserNotifying: AnyObject {
    func authorizationStatus() async -> NotificationAuthorization
    func requestAuthorization() async -> Bool
    func add(_ notification: PlannedNotification) async
    func pendingIdentifiers() async -> [String]
    func removePending(ids: [String]) async
}

/// Default no-op notifier. Injected into `AppState` by default so tests never
/// touch the system center; the app injects `SystemUserNotifying`.
@MainActor
public final class NoopUserNotifying: UserNotifying {
    public init() {}
    public func authorizationStatus() async -> NotificationAuthorization { .notDetermined }
    public func requestAuthorization() async -> Bool { false }
    public func add(_ notification: PlannedNotification) async {}
    public func pendingIdentifiers() async -> [String] { [] }
    public func removePending(ids: [String]) async {}
}
