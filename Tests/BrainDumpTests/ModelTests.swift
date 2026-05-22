import Foundation
import Testing
import SwiftData
@testable import BrainDumpKit

@MainActor
@Test func canInsertAndFetchADay() throws {
    let context = try InMemoryStore.makeContext()
    let date = DateComponents(calendar: .current, year: 2026, month: 5, day: 22).date!
    let day = Day(date: date)
    context.insert(day)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Day>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.date == date)
}

@MainActor
@Test func taskItemBelongsToDay() throws {
    let context = try InMemoryStore.makeContext()
    let date = DateComponents(calendar: .current, year: 2026, month: 5, day: 22).date!
    let day = Day(date: date)
    let item = TaskItem(title: "Write spec")
    item.day = day
    context.insert(day)
    context.insert(item)
    try context.save()

    let fetchedDay = try #require(context.fetch(FetchDescriptor<Day>()).first)
    #expect(fetchedDay.items.count == 1)
    #expect(fetchedDay.items.first?.title == "Write spec")
}

@MainActor
@Test func startOfDayNormalization() throws {
    let cal = Calendar.current
    let mid = DateComponents(calendar: cal, year: 2026, month: 5, day: 22, hour: 14, minute: 30).date!
    let startOfDay = mid.startOfLocalDay()
    let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startOfDay)
    #expect(comps.hour == 0)
    #expect(comps.minute == 0)
    #expect(comps.second == 0)
}
