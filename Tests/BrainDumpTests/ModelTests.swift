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
@Test func scheduleEntryPersistsCustomColorAndAbsoluteReminder() throws {
    let context = try InMemoryStore.makeContext()
    let day = Day(date: TestDate.at(2026, 6, 17))
    let item = TaskItem(title: "Block")
    item.day = day
    let entry = ScheduleEntry(
        startMinute: 540, durationMinutes: 60, colorIndex: 2,
        customColorHex: "#1A2B3C", reminderMinuteOfDay: 525, item: item, day: day)
    context.insert(day)
    context.insert(item)
    context.insert(entry)
    try context.save()

    let fetched = try #require(context.fetch(FetchDescriptor<ScheduleEntry>()).first)
    #expect(fetched.customColorHex == "#1A2B3C")
    #expect(fetched.reminderMinuteOfDay == 525)
    #expect(fetched.reminderOffsetMinutes == nil) // legacy column untouched for new entries
}

@MainActor
@Test func scheduleEntryDefaultsHaveNoCustomColorOrAbsoluteReminder() throws {
    let context = try InMemoryStore.makeContext()
    let entry = ScheduleEntry(startMinute: 0, durationMinutes: 60)
    context.insert(entry)
    try context.save()
    let fetched = try #require(context.fetch(FetchDescriptor<ScheduleEntry>()).first)
    #expect(fetched.customColorHex == nil)
    #expect(fetched.reminderMinuteOfDay == nil)
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
