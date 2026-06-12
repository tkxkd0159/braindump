import Foundation

/// Drives the `UserNotifying` backend from the pure planners and reconciles
/// pending notifications. All operations are idempotent: re-running a sync with
/// the same inputs converges to the same registered set.
@MainActor
public final class NotificationCoordinator {
    private let notifier: UserNotifying

    /// Last-known authorization outcome, surfaced to Settings so it can show a
    /// "turn notifications on in System Settings" hint.
    public private(set) var lastAuthorizationDenied = false

    public init(notifier: UserNotifying) { self.notifier = notifier }

    /// notDetermined -> request once; authorized -> true; denied -> false.
    @discardableResult
    public func ensureAuthorized() async -> Bool {
        switch await notifier.authorizationStatus() {
        case .authorized:
            lastAuthorizationDenied = false
            return true
        case .denied:
            lastAuthorizationDenied = true
            return false
        case .notDetermined:
            let granted = await notifier.requestAuthorization()
            lastAuthorizationDenied = !granted
            return granted
        }
    }

    /// Reconcile a day's schedule reminders: cancel stale ones, arm the desired
    /// set (requesting authorization only when there is something to arm).
    public func syncScheduleReminders(inputs: [ReminderInput], now: Date) async {
        let desired = ScheduleReminderPlanner.plan(inputs: inputs, now: now)
        let desiredIDs = Set(desired.map { $0.id })
        let pending = await notifier.pendingIdentifiers()
        let stale = pending.filter {
            $0.hasPrefix(ScheduleReminderPlanner.idPrefix) && !desiredIDs.contains($0)
        }
        if !stale.isEmpty { await notifier.removePending(ids: stale) }
        guard !desired.isEmpty else { return }
        guard await ensureAuthorized() else { return }
        for notification in desired { await notifier.add(notification) }
    }

    /// Arm or cancel the single daily backlog digest.
    public func syncBacklogDigest(inputs: [BacklogInput], enabled: Bool, thresholdDays: Int,
                                  hour: Int, minute: Int, now: Date) async {
        let planned = BacklogDigestPlanner.plan(
            inputs: inputs, enabled: enabled, thresholdDays: thresholdDays,
            hour: hour, minute: minute, now: now)
        guard let planned else {
            await notifier.removePending(ids: [BacklogDigestPlanner.id])
            return
        }
        guard await ensureAuthorized() else {
            await notifier.removePending(ids: [BacklogDigestPlanner.id])
            return
        }
        await notifier.add(planned)
    }
}
