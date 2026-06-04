import Foundation
import SwiftData

/// Outcome of opening the persistent store, surfaced to the UI for a one-time
/// notice when data could not be opened normally.
public enum StoreRecovery: Equatable, Sendable {
    case normal
    case recoveredFromCorruption(movedAsideTo: URL)
    case inMemoryFallback

    public var isRecovery: Bool {
        if case .normal = self { return false }
        return true
    }

    public var userMessage: String? {
        switch self {
        case .normal:
            return nil
        case .recoveredFromCorruption(let url):
            return "BrainDump couldn't open your saved data, so it started fresh. "
                + "Your previous data was preserved at \(url.path(percentEncoded: false))."
        case .inMemoryFallback:
            return "BrainDump couldn't open or recreate your saved data, so it's running "
                + "in temporary memory. Changes this session won't be saved."
        }
    }
}

/// Version 1 of the on-disk schema. Establishes the migration seam: a future
/// V2 adds a `MigrationStage` to `BrainDumpMigrationPlan` instead of crashing.
public enum BrainDumpSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [Day.self, TaskItem.self, ScheduleEntry.self]
    }
}

public enum BrainDumpMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [BrainDumpSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum PersistenceController {
    /// ~/Library/Application Support/BrainDump/BrainDump.store
    public static func defaultStoreURL() -> URL {
        URL.applicationSupportDirectory.appending(path: "BrainDump/BrainDump.store")
    }

    /// Never throws, never `fatalError`s. (Recovery added in Task 2.)
    public static func makeContainer(
        storeURL: URL = defaultStoreURL()
    ) -> (container: ModelContainer, recovery: StoreRecovery) {
        let schema = Schema(versionedSchema: BrainDumpSchemaV1.self)
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let config = ModelConfiguration(schema: schema, url: storeURL)
        let container = try! ModelContainer(
            for: schema, migrationPlan: BrainDumpMigrationPlan.self, configurations: config)
        return (container, .normal)
    }
}
