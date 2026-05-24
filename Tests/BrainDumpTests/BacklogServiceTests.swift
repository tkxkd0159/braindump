import Foundation
import Testing
import SwiftData
@testable import BrainDumpKit

@MainActor
@Test func addBacklogItemCreatesItemWithNoDay() throws {
    let context = try InMemoryStore.makeContext()
    let backlog = BacklogService(context: context)

    let item = backlog.addBacklogItem(title: "Refactor module")
    #expect(item.day == nil)
    #expect(item.isBacklog == true)
}

@MainActor
@Test func addBacklogItemSetsIsBacklog() throws {
    let context = try InMemoryStore.makeContext()
    let backlog = BacklogService(context: context)

    let item = backlog.addBacklogItem(title: "Read paper")
    #expect(item.isBacklog == true)
}

@MainActor
@Test func listBacklogReturnsOnlyBacklogItems() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let backlog = BacklogService(context: context)
    let day = dayService.day(for: TestDate.at(2026, 5, 22))
    _ = taskService.addBrainDumpItem(title: "Active", on: day)
    let b1 = backlog.addBacklogItem(title: "Backlog 1")
    let b2 = backlog.addBacklogItem(title: "Backlog 2")

    let items = backlog.listBacklog()
    let ids = Set(items.map(\.id))
    #expect(ids == Set([b1.id, b2.id]))
}

@MainActor
@Test func promoteToBrainDumpClearsBacklogAndAssignsDay() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let backlog = BacklogService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    let item = backlog.addBacklogItem(title: "Promote me")

    backlog.promoteToBrainDump(item, on: today)
    #expect(item.isBacklog == false)
    #expect(item.day?.date == today.date)
    #expect(today.items.contains { $0.id == item.id })
    #expect(backlog.listBacklog().isEmpty)
}

@MainActor
@Test func deleteBacklogItemRemovesIt() throws {
    let context = try InMemoryStore.makeContext()
    let backlog = BacklogService(context: context)
    let item = backlog.addBacklogItem(title: "Gone")

    backlog.delete(item)
    #expect(backlog.listBacklog().isEmpty)
}

@MainActor
@Test func addBacklogItemAcceptsNotesAndTags() throws {
    let context = try InMemoryStore.makeContext()
    let backlog = BacklogService(context: context)

    let item = backlog.addBacklogItem(
        title: "Write spec",
        notes: "Outline before drafting",
        tags: ["Writing", "writing", "deep-work"]
    )

    #expect(item.title == "Write spec")
    #expect(item.notes == "Outline before drafting")
    #expect(item.tags == ["writing", "deep-work"])
    #expect(item.isBacklog == true)
    #expect(item.day == nil)
}

@MainActor
@Test func moveToBacklogTurnsBrainDumpItemIntoBacklogItem() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let backlog = BacklogService(context: context)
    let day = dayService.day(for: TestDate.at(2026, 5, 22))
    let item = taskService.addBrainDumpItem(title: "Move me", on: day)

    backlog.moveToBacklog(item)

    #expect(item.isBacklog == true)
    #expect(item.day == nil)
    #expect(!day.items.contains { $0.id == item.id })
    #expect(backlog.listBacklog().contains { $0.id == item.id })
}

@MainActor
@Test func moveToBacklogClearsTop3AndSchedule() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let scheduleService = ScheduleService(context: context)
    let backlog = BacklogService(context: context)
    let day = dayService.day(for: TestDate.at(2026, 5, 22))
    let item = taskService.addBrainDumpItem(title: "Multi-state", on: day)
    try taskService.escalate(item, on: day)
    _ = try scheduleService.schedule(
        item, on: day, startMinute: 9 * 60, durationMinutes: 60
    )

    backlog.moveToBacklog(item)

    #expect(item.isBacklog == true)
    #expect(item.day == nil)
    #expect(!day.top3ItemIDs.contains(item.id))
    #expect(day.schedule.allSatisfy { $0.item?.id != item.id })
}

@MainActor
@Test func rolloverDoesNotTouchBacklogItems() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let backlog = BacklogService(context: context)
    let item = backlog.addBacklogItem(title: "Stays in backlog")

    dayService.rollover(now: TestDate.at(2026, 5, 23))

    #expect(item.isBacklog == true)
    #expect(item.day == nil)
    #expect(backlog.listBacklog().count == 1)
}
