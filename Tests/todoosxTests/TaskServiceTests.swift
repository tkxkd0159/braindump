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

@MainActor
@Test func escalateAddsToTop3() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))

    let item = taskService.addBrainDumpItem(title: "A", on: today)
    try taskService.escalate(item, on: today)

    #expect(today.top3ItemIDs == [item.id])
}

@MainActor
@Test func escalateIsIdempotent() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))

    let item = taskService.addBrainDumpItem(title: "A", on: today)
    try taskService.escalate(item, on: today)
    try taskService.escalate(item, on: today)

    #expect(today.top3ItemIDs == [item.id])
}

@MainActor
@Test func escalateThrowsWhenTop3Full() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))

    let a = taskService.addBrainDumpItem(title: "A", on: today)
    let b = taskService.addBrainDumpItem(title: "B", on: today)
    let c = taskService.addBrainDumpItem(title: "C", on: today)
    let d = taskService.addBrainDumpItem(title: "D", on: today)
    try taskService.escalate(a, on: today)
    try taskService.escalate(b, on: today)
    try taskService.escalate(c, on: today)

    #expect(throws: TodoError.top3Full) {
        try taskService.escalate(d, on: today)
    }
}

@MainActor
@Test func deescalateRemoves() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))

    let a = taskService.addBrainDumpItem(title: "A", on: today)
    let b = taskService.addBrainDumpItem(title: "B", on: today)
    try taskService.escalate(a, on: today)
    try taskService.escalate(b, on: today)
    taskService.deescalate(a, on: today)

    #expect(today.top3ItemIDs == [b.id])
}

@MainActor
@Test func reorderTop3() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))

    let a = taskService.addBrainDumpItem(title: "A", on: today)
    let b = taskService.addBrainDumpItem(title: "B", on: today)
    let c = taskService.addBrainDumpItem(title: "C", on: today)
    try taskService.escalate(a, on: today)
    try taskService.escalate(b, on: today)
    try taskService.escalate(c, on: today)

    taskService.reorderTop3(on: today, ids: [c.id, a.id, b.id])
    #expect(today.top3ItemIDs == [c.id, a.id, b.id])
}

@MainActor
@Test func allTagsReturnsDistinctSortedTags() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    let a = taskService.addBrainDumpItem(title: "A", on: today)
    let b = taskService.addBrainDumpItem(title: "B", on: today)
    taskService.updateTags(a, tags: ["writing", "deep"])
    taskService.updateTags(b, tags: ["deep", "research"])

    #expect(taskService.allTags() == ["deep", "research", "writing"])
}

@MainActor
@Test func searchByKeywordMatchesTitleAndNotes() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    let manuscript = taskService.addBrainDumpItem(title: "Manuscript review", on: today)
    let email = taskService.addBrainDumpItem(title: "Email", on: today)
    taskService.updateNotes(email, notes: "Reply about the manuscript revisions")
    _ = taskService.addBrainDumpItem(title: "Unrelated task", on: today)

    let results = taskService.searchTasks(keyword: "manuscript", tag: nil, completedRange: nil)
    let ids = Set(results.map(\.id))
    #expect(ids == Set([manuscript.id, email.id]))
}

@MainActor
@Test func searchByTagReturnsOnlyTaggedItems() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    let a = taskService.addBrainDumpItem(title: "A", on: today)
    let b = taskService.addBrainDumpItem(title: "B", on: today)
    taskService.updateTags(a, tags: ["writing"])
    taskService.updateTags(b, tags: ["research"])

    let results = taskService.searchTasks(keyword: nil, tag: "writing", completedRange: nil)
    #expect(results.map(\.id) == [a.id])
}

@MainActor
@Test func searchCompletedRangeReturnsItemsWithEntryInRange() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let scheduleService = ScheduleService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    let done = taskService.addBrainDumpItem(title: "Done", on: today)
    let entry = try scheduleService.schedule(done, on: today, startHour: 9, durationHours: 1)
    scheduleService.setCompleted(entry, true)

    let lower = TestDate.at(2026, 5, 22, hour: 0)
    let upper = TestDate.at(2026, 5, 22, hour: 23, minute: 59)
    let results = taskService.searchTasks(keyword: nil, tag: nil, completedRange: lower...upper)
    #expect(results.map(\.id) == [done.id])
}

@MainActor
@Test func searchCompletedRangeIgnoresUncompletedItems() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let scheduleService = ScheduleService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    let open = taskService.addBrainDumpItem(title: "Open", on: today)
    _ = try scheduleService.schedule(open, on: today, startHour: 9, durationHours: 1)

    let lower = TestDate.at(2026, 5, 22, hour: 0)
    let upper = TestDate.at(2026, 5, 22, hour: 23, minute: 59)
    let results = taskService.searchTasks(keyword: nil, tag: nil, completedRange: lower...upper)
    #expect(results.isEmpty)
}

@MainActor
@Test func searchExcludesBacklogItems() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    let active = taskService.addBrainDumpItem(title: "Active", on: today)
    let backlog = TaskItem(title: "Backlog", isBacklog: true)
    context.insert(backlog)
    try context.save()

    let results = taskService.searchTasks(keyword: nil, tag: nil, completedRange: nil)
    let ids = Set(results.map(\.id))
    #expect(ids == Set([active.id]))
    #expect(!ids.contains(backlog.id))
}

@MainActor
@Test func updateNotesPersists() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    let item = taskService.addBrainDumpItem(title: "Spec", on: today)
    #expect(item.notes == "")

    taskService.updateNotes(item, notes: "Outline section headings before deep dive.")
    #expect(item.notes == "Outline section headings before deep dive.")
}

@MainActor
@Test func updateTagsPersistsAndDeduplicates() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))
    let item = taskService.addBrainDumpItem(title: "Spec", on: today)
    #expect(item.tags == [])

    taskService.updateTags(item, tags: ["writing", "deep-work", "writing"])
    #expect(item.tags == ["writing", "deep-work"])
}

@MainActor
@Test func deleteRemovesFromTop3() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let today = dayService.day(for: TestDate.at(2026, 5, 22))

    let a = taskService.addBrainDumpItem(title: "A", on: today)
    try taskService.escalate(a, on: today)
    taskService.delete(a)

    #expect(today.top3ItemIDs.isEmpty)
}
