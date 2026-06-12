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
    func migrationPlanHasV1AndV2WithLightweightStage() {
        #expect(BrainDumpMigrationPlan.schemas.count == 2)
        #expect(BrainDumpMigrationPlan.stages.count == 1)
        #expect(BrainDumpSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(BrainDumpSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
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

    /// The highest-risk path: a store stamped at the V1 schema version must
    /// open through the V2 migration plan as `.normal` with its data intact —
    /// NOT fall into the corruption-recovery branch (which would move the store
    /// aside and present an empty app, i.e. silent data loss).
    @Test
    func v1StampedStoreMigratesToV2AsNormal() throws {
        let dir = URL.temporaryDirectory.appending(
            path: "BrainDumpTest-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "BrainDump.store")

        // Seed a store stamped at schema version 1.0.0 (no migration plan).
        do {
            let v1Schema = Schema(versionedSchema: BrainDumpSchemaV1.self)
            let v1Config = ModelConfiguration(schema: v1Schema, url: url)
            let v1Container = try ModelContainer(for: v1Schema, configurations: v1Config)
            let ctx = ModelContext(v1Container)
            let day = Day(date: TestDate.at(2026, 6, 12))
            ctx.insert(day)
            let item = TaskItem(title: "Carry me across the migration")
            item.day = day
            ctx.insert(item)
            let entry = ScheduleEntry(startMinute: 540, durationMinutes: 60, item: item, day: day)
            ctx.insert(entry)
            try ctx.save()
        }

        // Reopen via the real entry point (V2 schema + migration plan).
        let result = PersistenceController.makeContainer(storeURL: url)
        #expect(result.recovery == .normal)   // not .recoveredFromCorruption

        let ctx = ModelContext(result.container)
        let days = try ctx.fetch(FetchDescriptor<Day>())
        #expect(days.count == 1)
        let items = try ctx.fetch(FetchDescriptor<TaskItem>())
        #expect(items.map(\.title) == ["Carry me across the migration"])
        let entries = try ctx.fetch(FetchDescriptor<ScheduleEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.reminderOffsetMinutes == nil)   // new column defaults to nil
    }
}
