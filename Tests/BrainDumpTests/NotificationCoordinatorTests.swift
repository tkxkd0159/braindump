import Foundation
import Testing
@testable import BrainDumpKit

@MainActor
private func coordinatorReminderInput(id: UUID = UUID(), start: Int, offset: Int?) -> ReminderInput {
    ReminderInput(entryID: id, dayStart: TestDate.at(2026, 6, 12), startMinute: start,
                  offsetMinutes: offset, isCompleted: false, title: "Task")
}

@MainActor @Test func coordinatorArmsDesiredScheduleReminders() async {
    let spy = SpyUserNotifying()
    let coord = NotificationCoordinator(notifier: spy)
    await coord.syncScheduleReminders(inputs: [coordinatorReminderInput(start: 9 * 60, offset: 15)],
                                      now: TestDate.at(2026, 6, 12, hour: 8))
    #expect(spy.added.count == 1)
    #expect(spy.pending.count == 1)
}

@MainActor @Test func coordinatorCancelsStaleScheduleRemindersNotDesired() async {
    let spy = SpyUserNotifying()
    let stale = ScheduleReminderPlanner.idPrefix + UUID().uuidString
    spy.pending = [stale]
    let coord = NotificationCoordinator(notifier: spy)
    await coord.syncScheduleReminders(inputs: [], now: TestDate.at(2026, 6, 12, hour: 8))
    #expect(spy.removed.contains(stale))
    #expect(spy.pending.isEmpty)
}

@MainActor @Test func coordinatorDeniedAuthorizationArmsNothingButStillCancels() async {
    let spy = SpyUserNotifying()
    spy.status = .denied
    let coord = NotificationCoordinator(notifier: spy)
    await coord.syncScheduleReminders(inputs: [coordinatorReminderInput(start: 9 * 60, offset: 15)],
                                      now: TestDate.at(2026, 6, 12, hour: 8))
    #expect(spy.added.isEmpty)
    #expect(coord.lastAuthorizationDenied == true)
}

@MainActor @Test func coordinatorRequestsAuthorizationWhenNotDetermined() async {
    let spy = SpyUserNotifying()
    spy.status = .notDetermined
    spy.grantOnRequest = true
    let coord = NotificationCoordinator(notifier: spy)
    await coord.syncScheduleReminders(inputs: [coordinatorReminderInput(start: 9 * 60, offset: 15)],
                                      now: TestDate.at(2026, 6, 12, hour: 8))
    #expect(spy.requestCount == 1)
    #expect(spy.added.count == 1)
}

@MainActor @Test func coordinatorReconciliationIsIdempotent() async {
    let spy = SpyUserNotifying()
    let coord = NotificationCoordinator(notifier: spy)
    let inputs = [coordinatorReminderInput(start: 9 * 60, offset: 15)]
    await coord.syncScheduleReminders(inputs: inputs, now: TestDate.at(2026, 6, 12, hour: 8))
    await coord.syncScheduleReminders(inputs: inputs, now: TestDate.at(2026, 6, 12, hour: 8))
    #expect(spy.pending.count == 1)
}

@MainActor @Test func coordinatorBacklogDigestArmsAndCancels() async {
    let spy = SpyUserNotifying()
    let coord = NotificationCoordinator(notifier: spy)
    let old = BacklogInput(createdAt: TestDate.at(2026, 5, 1))
    await coord.syncBacklogDigest(inputs: [old], enabled: true, thresholdDays: 7,
                                  hour: 9, minute: 0, now: TestDate.at(2026, 6, 12))
    #expect(spy.pending.contains(BacklogDigestPlanner.id))
    await coord.syncBacklogDigest(inputs: [old], enabled: false, thresholdDays: 7,
                                  hour: 9, minute: 0, now: TestDate.at(2026, 6, 12))
    #expect(spy.removed.contains(BacklogDigestPlanner.id))
    #expect(!spy.pending.contains(BacklogDigestPlanner.id))
}
