import Foundation
import Testing
import SwiftData
@testable import TodoosxKit

@MainActor
@Test func dayForReturnsSameDayForRepeatedCalls() throws {
    let context = try InMemoryStore.makeContext()
    let service = DayService(context: context)

    let d1 = service.day(for: TestDate.at(2026, 5, 22))
    let d2 = service.day(for: TestDate.at(2026, 5, 22))

    #expect(d1 === d2)
}

@MainActor
@Test func dayForNormalizesToStartOfDay() throws {
    let context = try InMemoryStore.makeContext()
    let service = DayService(context: context)

    let d = service.day(for: TestDate.at(2026, 5, 22, hour: 14, minute: 30))
    #expect(d.date == TestDate.at(2026, 5, 22))
}

@MainActor
@Test func dayForCreatesDistinctDaysForDistinctDates() throws {
    let context = try InMemoryStore.makeContext()
    let service = DayService(context: context)

    let a = service.day(for: TestDate.at(2026, 5, 22))
    let b = service.day(for: TestDate.at(2026, 5, 23))

    #expect(a.date != b.date)
    let all = try context.fetch(FetchDescriptor<Day>())
    #expect(all.count == 2)
}
