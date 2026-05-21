import Foundation
import Testing
import SwiftData
@testable import TodoosxKit

@MainActor
@Test func addBrainDumpItemAppendsToDay() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))

    let item = taskService.addBrainDumpItem(title: "Buy groceries", on: today)

    #expect(today.items.count == 1)
    #expect(today.items.first?.id == item.id)
    #expect(item.title == "Buy groceries")
}

@MainActor
@Test func renameUpdatesTitle() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))

    let item = taskService.addBrainDumpItem(title: "Old", on: today)
    taskService.rename(item, to: "New")

    #expect(item.title == "New")
}

@MainActor
@Test func deleteRemovesItem() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))

    let item = taskService.addBrainDumpItem(title: "Doomed", on: today)
    taskService.delete(item)

    #expect(today.items.isEmpty)
    let remaining = try context.fetch(FetchDescriptor<TaskItem>())
    #expect(remaining.count == 0)
}
