import Testing
import SwiftData
import SwiftUI
@testable import BrainDumpKit

@MainActor
@Test func taskDetailFocus_createCase_hasCreatePrefix() throws {
    let context = try InMemoryStore.makeContext()
    let day = DayService(context: context).day(for: TestDate.at(2026, 5, 23))
    let focus = TaskDetailFocus.create(day: day)
    #expect(focus.id.hasPrefix("create-"))
}

@MainActor
@Test func taskDetailFocus_editCase_idEncodesItem() throws {
    let context = try InMemoryStore.makeContext()
    let day = DayService(context: context).day(for: TestDate.at(2026, 5, 23))
    let item = TaskService(context: context).addBrainDumpItem(title: "x", on: day)
    let focus = TaskDetailFocus.edit(item: item, entry: nil, startInEditMode: false)
    #expect(focus.id == "edit-\(item.id.uuidString)")
}

@MainActor
@Test func taskDetailFocus_compatInit_buildsEditCase() throws {
    let context = try InMemoryStore.makeContext()
    let day = DayService(context: context).day(for: TestDate.at(2026, 5, 23))
    let item = TaskService(context: context).addBrainDumpItem(title: "x", on: day)
    let focus = TaskDetailFocus(item: item, entry: nil, startInEditMode: false)
    if case .edit(let f, let e, let s) = focus {
        #expect(f.id == item.id)
        #expect(e == nil)
        #expect(s == false)
    } else {
        Issue.record("Expected .edit case")
    }
}

@MainActor
@Test func taskDetailFocus_compatInit_defaultsToEditStart() throws {
    let context = try InMemoryStore.makeContext()
    let day = DayService(context: context).day(for: TestDate.at(2026, 5, 23))
    let item = TaskService(context: context).addBrainDumpItem(title: "x", on: day)
    let focus = TaskDetailFocus(item: item)
    if case .edit(_, _, let startInEdit) = focus {
        #expect(startInEdit == true)
    } else {
        Issue.record("Expected .edit case")
    }
}

@MainActor
@Test func taskDetailSheet_constructs_inAllThreeModes() throws {
    let context = try InMemoryStore.makeContext()
    let day = DayService(context: context).day(for: TestDate.at(2026, 5, 23))
    let item = TaskService(context: context).addBrainDumpItem(title: "x", on: day)
    let entry = try ScheduleService(context: context).schedule(
        item, on: day, startMinute: 9 * 60, durationMinutes: 60
    )
    // Smoke: each focus can be constructed and passed to a sheet without crashing
    // the initializer. Body evaluation is exercised by the snapshot tests.
    _ = TaskDetailSheet(focus: .create(day: day), dismiss: {})
    _ = TaskDetailSheet(focus: .edit(item: item, entry: entry, startInEditMode: true), dismiss: {})
    _ = TaskDetailSheet(focus: .edit(item: item, entry: nil, startInEditMode: true), dismiss: {})
}
