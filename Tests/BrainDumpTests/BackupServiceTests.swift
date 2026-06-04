import Foundation
import SwiftData
import Testing

@testable import BrainDumpKit

@MainActor
struct BackupServiceTests {
    /// Builds a context with two days, brain-dump items (notes/tags), a top-3
    /// order, a completed + an open schedule entry, and a backlog item.
    private func seed() throws -> ModelContext {
        let context = try InMemoryStore.makeContext()
        let days = DayService(context: context)
        let tasks = TaskService(context: context)
        let sched = ScheduleService(context: context)
        let backlog = BacklogService(context: context)

        let d1 = days.day(for: TestDate.at(2026, 5, 21))
        let a = tasks.addBrainDumpItem(title: "Write intro", on: d1)
        tasks.updateNotes(a, notes: "first draft")
        tasks.updateTags(a, tags: ["writing"])
        try tasks.escalate(a, on: d1)
        let e = try sched.schedule(a, on: d1, startMinute: 9 * 60, durationMinutes: 60)
        sched.setCompleted(e, true)

        let d2 = days.day(for: TestDate.at(2026, 5, 22))
        _ = tasks.addBrainDumpItem(title: "Review", on: d2)

        _ = backlog.addBacklogItem(title: "Someday task", notes: "", tags: ["later"])
        return context
    }

    @Test
    func exportProducesVersionedSnapshot() throws {
        let context = try seed()
        let data = try BackupService(context: context).exportData()

        let snapshot = try JSONDecoder.iso8601.decode(BackupSnapshot.self, from: data)
        #expect(snapshot.version == 1)
        #expect(snapshot.days.count == 2)
        #expect(snapshot.backlogItems.map(\.title) == ["Someday task"])

        let day1 = try #require(snapshot.days.first { $0.date == TestDate.at(2026, 5, 21) })
        #expect(day1.items.map(\.title) == ["Write intro"])
        #expect(day1.items.first?.tags == ["writing"])
        let firstItemID = try #require(day1.items.first?.id)
        #expect(day1.top3ItemIDs == [firstItemID])
        #expect(day1.entries.count == 1)
        #expect(day1.entries.first?.isCompleted == true)
        #expect(day1.entries.first?.itemID == firstItemID)
    }

    @Test
    func roundTripRestoresEverything() throws {
        let context = try seed()
        let data = try BackupService(context: context).exportData()

        try BackupService(context: context).restore(from: data)

        let days = try context.fetch(FetchDescriptor<Day>(sortBy: [SortDescriptor(\.date)]))
        #expect(days.map(\.date) == [TestDate.at(2026, 5, 21), TestDate.at(2026, 5, 22)])

        let d1 = try #require(days.first)
        #expect(d1.items.map(\.title) == ["Write intro"])
        let firstItem = try #require(d1.items.first)
        #expect(firstItem.notes == "first draft")
        #expect(firstItem.tags == ["writing"])
        #expect(d1.top3ItemIDs == [firstItem.id])
        let entry = try #require(d1.schedule.first)
        #expect(entry.startMinute == 9 * 60)
        #expect(entry.durationMinutes == 60)
        #expect(entry.isCompleted == true)
        #expect(entry.item?.id == firstItem.id)

        let backlog = try context.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isBacklog }))
        #expect(backlog.map(\.title) == ["Someday task"])
    }

    @Test
    func restoreReplacesExistingData() throws {
        let source = try seed()
        let data = try BackupService(context: source).exportData()

        let target = try InMemoryStore.makeContext()
        let day = DayService(context: target).day(for: TestDate.at(2026, 1, 1))
        _ = TaskService(context: target).addBrainDumpItem(title: "OLD - should vanish", on: day)

        try BackupService(context: target).restore(from: data)

        let titles = try target.fetch(FetchDescriptor<TaskItem>()).map(\.title).sorted()
        #expect(!titles.contains("OLD - should vanish"))
        #expect(titles == ["Review", "Someday task", "Write intro"])
    }

    @Test
    func restoreRejectsUnsupportedVersion() throws {
        let context = try InMemoryStore.makeContext()
        let json = #"{"version":999,"days":[],"backlogItems":[]}"#
        #expect(throws: BackupError.unsupportedVersion(999)) {
            try BackupService(context: context).restore(from: Data(json.utf8))
        }
    }

    @Test
    func restoreRejectsMalformedData() throws {
        let context = try InMemoryStore.makeContext()
        #expect(throws: BackupError.malformed) {
            try BackupService(context: context).restore(from: Data("{not json".utf8))
        }
    }
}

extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
