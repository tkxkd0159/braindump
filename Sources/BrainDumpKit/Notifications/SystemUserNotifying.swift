import Foundation
import UserNotifications

/// Real `UserNotifying` backed by `UNUserNotificationCenter`. `current()` is
/// touched only inside methods, never at construction, so this type is never
/// exercised by `swift test` (which has no app bundle); the app injects it,
/// tests inject a spy or `NoopUserNotifying`.
@MainActor
public final class SystemUserNotifying: UserNotifying {
    public init() {}

    private var center: UNUserNotificationCenter { .current() }

    public func authorizationStatus() async -> NotificationAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    public func add(_ n: PlannedNotification) async {
        let content = UNMutableNotificationContent()
        content.title = n.title
        content.body = n.body
        content.sound = .default

        let trigger: UNNotificationTrigger
        switch n.trigger {
        case .at(let date):
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        case .dailyAt(let hour, let minute):
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        }

        let request = UNNotificationRequest(identifier: n.id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    public func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map { $0.identifier }
    }

    public func removePending(ids: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
