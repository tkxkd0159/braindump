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

/// Version 1 of the on-disk schema.
public enum BrainDumpSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [Day.self, TaskItem.self, ScheduleEntry.self]
    }
}

/// Version 2 adds `ScheduleEntry.reminderOffsetMinutes` (optional). Both
/// versions reference the live model classes deliberately: SwiftData derives
/// the entity name from the class name, so a frozen/renamed snapshot would read
/// as a *different* entity and lose data rather than migrate. The additive
/// optional column is handled by a lightweight stage on open.
public enum BrainDumpSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [Day.self, TaskItem.self, ScheduleEntry.self]
    }
}

public enum BrainDumpMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [BrainDumpSchemaV1.self, BrainDumpSchemaV2.self]
    }
    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: BrainDumpSchemaV1.self, toVersion: BrainDumpSchemaV2.self)]
    }
}

public enum PersistenceController {
    /// ~/Library/Application Support/BrainDump/BrainDump.store
    public static func defaultStoreURL() -> URL {
        URL.applicationSupportDirectory.appending(path: "BrainDump/BrainDump.store")
    }

    /// Never throws, never `fatalError`s. Tries to open the versioned store;
    /// on failure moves the unreadable store (and its sidecars) aside and
    /// retries fresh; last resort an in-memory container.
    public static func makeContainer(
        storeURL: URL = defaultStoreURL()
    ) -> (container: ModelContainer, recovery: StoreRecovery) {
        let schema = Schema(versionedSchema: BrainDumpSchemaV2.self)
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let config = ModelConfiguration(schema: schema, url: storeURL)

        do {
            let container = try ModelContainer(
                for: schema, migrationPlan: BrainDumpMigrationPlan.self, configurations: config)
            return (container, .normal)
        } catch {
            let movedAsideTo = moveAside(storeURL)
            do {
                let container = try ModelContainer(
                    for: schema, migrationPlan: BrainDumpMigrationPlan.self, configurations: config)
                return (container, .recoveredFromCorruption(movedAsideTo: movedAsideTo))
            } catch {
                // Last resort: in-memory with a valid schema is effectively
                // infallible, so the app never crashes on launch.
                let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let container = try! ModelContainer(for: schema, configurations: memConfig)
                return (container, .inMemoryFallback)
            }
        }
    }

    /// Renames the unreadable store and its SQLite sidecars to
    /// `<name>.corrupt-<unix-stamp><suffix>` (preserved, not deleted).
    /// Returns the moved-aside main store URL.
    private static func moveAside(_ storeURL: URL) -> URL {
        let fm = FileManager.default
        let stamp = Int(Date().timeIntervalSince1970)
        let dir = storeURL.deletingLastPathComponent()
        let base = storeURL.lastPathComponent
        var movedMain = dir.appending(path: "\(base).corrupt-\(stamp)")
        for suffix in ["", "-wal", "-shm"] {
            let src = URL(fileURLWithPath: storeURL.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = dir.appending(path: "\(base).corrupt-\(stamp)\(suffix)")
            try? fm.removeItem(at: dst)
            try? fm.moveItem(at: src, to: dst)
            if suffix.isEmpty { movedMain = dst }
        }
        return movedMain
    }
}
