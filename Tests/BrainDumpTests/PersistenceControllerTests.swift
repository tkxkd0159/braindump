import Foundation
import SwiftData
import Testing

@testable import BrainDumpKit

@MainActor
struct PersistenceControllerTests {
    @Test
    func defaultStoreURLIsNamespaced() {
        let url = PersistenceController.defaultStoreURL()
        #expect(url.lastPathComponent == "BrainDump.store")
        // Lives under the build-specific app directory (debug vs release).
        #expect(url.deletingLastPathComponent().lastPathComponent == PersistenceController.appDirectoryName)
    }

    @Test
    func appDirectoryNameSeparatesDebugFromRelease() {
        #expect(PersistenceController.appDirectoryName(debug: false) == "BrainDump")
        #expect(PersistenceController.appDirectoryName(debug: true) == "BrainDump-debug")
    }

    @Test
    func resolvedAppDirectoryMatchesBuildConfiguration() {
        // A debug build (how `swift test` compiles) must resolve to the
        // separate folder so it can't migrate/clobber the Release app's data.
        #if DEBUG
        #expect(PersistenceController.appDirectoryName == "BrainDump-debug")
        #else
        #expect(PersistenceController.appDirectoryName == "BrainDump")
        #endif
    }

    @Test
    func makeContainerOpensFreshStoreAsNormal() throws {
        let dir = URL.temporaryDirectory.appending(
            path: "BrainDumpTest-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appending(path: "BrainDump.store")

        let result = PersistenceController.makeContainer(storeURL: url)
        #expect(result.recovery == .normal)

        let context = ModelContext(result.container)
        context.insert(Day(date: TestDate.at(2026, 5, 22)))
        try context.save()
        #expect((try context.fetch(FetchDescriptor<Day>())).count == 1)
    }

    @Test
    func storeRecoveryReportsIsRecoveryAndMessage() {
        #expect(StoreRecovery.normal.isRecovery == false)
        #expect(StoreRecovery.normal.userMessage == nil)

        let moved = URL(fileURLWithPath: "/tmp/BrainDump.store.corrupt-1")
        #expect(StoreRecovery.recoveredFromCorruption(movedAsideTo: moved).isRecovery == true)
        #expect(StoreRecovery.recoveredFromCorruption(movedAsideTo: moved).userMessage != nil)
        #expect(StoreRecovery.inMemoryFallback.isRecovery == true)
        #expect(StoreRecovery.inMemoryFallback.userMessage != nil)
    }

    @Test
    func makeContainerRecoversFromCorruptStore() throws {
        let dir = URL.temporaryDirectory.appending(
            path: "BrainDumpTest-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "BrainDump.store")

        // Not a SQLite database -> ModelContainer open must fail and recover.
        try Data("this is not a sqlite database".utf8).write(to: url)

        let result = PersistenceController.makeContainer(storeURL: url)

        guard case .recoveredFromCorruption(let movedAsideTo) = result.recovery else {
            Issue.record("expected .recoveredFromCorruption, got \(result.recovery)")
            return
        }
        // The bad file was moved aside (preserved, not deleted)...
        let movedSiblings = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.contains(".corrupt-") }
        #expect(!movedSiblings.isEmpty)
        #expect(movedAsideTo.lastPathComponent.contains(".corrupt-"))
        // ...and the fresh container works.
        let context = ModelContext(result.container)
        context.insert(Day(date: TestDate.at(2026, 5, 22)))
        try context.save()
        #expect((try context.fetch(FetchDescriptor<Day>())).count == 1)
    }

    @Test
    func schemaV2IsCurrentVersion() {
        #expect(BrainDumpSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(BrainDumpSchemaV2.models.count == 3)
    }

    @Test
    func reminderOffsetSurvivesReopen() throws {
        let dir = URL.temporaryDirectory.appending(
            path: "BrainDumpTest-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "BrainDump.store")

        // First open: write an entry carrying a reminder offset, then close.
        do {
            let result = PersistenceController.makeContainer(storeURL: url)
            #expect(result.recovery == .normal)
            let context = ModelContext(result.container)
            let day = Day(date: TestDate.at(2026, 6, 12))
            context.insert(day)
            let item = TaskItem(title: "Write")
            item.day = day
            context.insert(item)
            let entry = ScheduleEntry(startMinute: 540, durationMinutes: 60, item: item, day: day)
            entry.reminderOffsetMinutes = 15
            context.insert(entry)
            try context.save()
        }

        // Reopen the same store file via the migration plan: opens normally and
        // preserves the offset (proves the V2 schema is stable across reopen).
        let result = PersistenceController.makeContainer(storeURL: url)
        #expect(result.recovery == .normal)
        let context = ModelContext(result.container)
        let entries = try context.fetch(FetchDescriptor<ScheduleEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.reminderOffsetMinutes == 15)
    }

}
