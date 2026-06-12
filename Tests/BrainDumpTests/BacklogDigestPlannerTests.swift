import Foundation
import Testing
@testable import BrainDumpKit

private func backlogTestInput(daysAgo: Int, now: Date) -> BacklogInput {
    BacklogInput(createdAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!)
}

@Test func backlogDigestCountsItemsStrictlyOlderThanThreshold() {
    let now = TestDate.at(2026, 6, 12, hour: 12)
    let inputs = [backlogTestInput(daysAgo: 10, now: now),
                  backlogTestInput(daysAgo: 7, now: now),
                  backlogTestInput(daysAgo: 8, now: now)]
    // threshold 7 => strictly > 7 => the 10- and 8-day-old items (the 7 is not).
    #expect(BacklogDigestPlanner.overdueCount(inputs: inputs, thresholdDays: 7, now: now) == 2)
}

@Test func backlogDigestDisabledYieldsNoDigest() {
    let now = TestDate.at(2026, 6, 12)
    #expect(BacklogDigestPlanner.plan(inputs: [backlogTestInput(daysAgo: 30, now: now)],
        enabled: false, thresholdDays: 7, hour: 9, minute: 0, now: now) == nil)
}

@Test func backlogDigestZeroOverdueYieldsNoDigest() {
    let now = TestDate.at(2026, 6, 12)
    #expect(BacklogDigestPlanner.plan(inputs: [backlogTestInput(daysAgo: 1, now: now)],
        enabled: true, thresholdDays: 7, hour: 9, minute: 0, now: now) == nil)
}

@Test func backlogDigestArmsDailyDigestWithCount() {
    let now = TestDate.at(2026, 6, 12)
    let planned = BacklogDigestPlanner.plan(
        inputs: [backlogTestInput(daysAgo: 30, now: now), backlogTestInput(daysAgo: 20, now: now)],
        enabled: true, thresholdDays: 7, hour: 9, minute: 0, now: now)
    #expect(planned?.trigger == .dailyAt(hour: 9, minute: 0))
    #expect(planned?.id == BacklogDigestPlanner.id)
    #expect(planned?.body.contains("2") == true)
}

@Test func backlogDigestSingularBodyForOneItem() {
    let now = TestDate.at(2026, 6, 12)
    let planned = BacklogDigestPlanner.plan(inputs: [backlogTestInput(daysAgo: 30, now: now)],
        enabled: true, thresholdDays: 7, hour: 8, minute: 30, now: now)
    #expect(planned?.body.contains("1 task has") == true)
    #expect(planned?.trigger == .dailyAt(hour: 8, minute: 30))
}
