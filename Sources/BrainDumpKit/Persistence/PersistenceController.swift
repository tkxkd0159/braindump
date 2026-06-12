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

/// Current schema version. Used to stamp the store so future migration plans
/// have a reliable starting version to migrate from.
///
/// NOTE: Schema versioning via `SchemaMigrationPlan` requires each
/// `VersionedSchema` to contain a *historical snapshot* of the model classes
/// (typically as nested @Model types), NOT the live classes. Using the same
/// live classes for all versions makes every version identical to CoreData,
/// which throws an ObjC NSException (uncatchable by Swift try/catch) when it
/// tries to build a migration mapping. For purely additive optional changes,
/// SwiftData's built-in lightweight auto-migration handles upgrades without a
/// formal plan — which is what this project uses.
public enum BrainDumpSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [Day.self, TaskItem.self, ScheduleEntry.self]
    }
}

public enum PersistenceController {
    /// Application Support subdirectory for this build. Debug builds use a
    /// separate folder so a dev build can't migrate or clobber the installed
    /// Release app's real data (e.g. when iterating on a schema migration).
    /// The calendar cache shares this directory (see `CalendarCache`).
    public static var appDirectoryName: String {
        #if DEBUG
        appDirectoryName(debug: true)
        #else
        appDirectoryName(debug: false)
        #endif
    }

    static func appDirectoryName(debug: Bool) -> String {
        debug ? "BrainDump-debug" : "BrainDump"
    }

    /// ~/Library/Application Support/BrainDump[-debug]/BrainDump.store
    public static func defaultStoreURL() -> URL {
        URL.applicationSupportDirectory.appending(path: "\(appDirectoryName)/BrainDump.store")
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
            let container = try ModelContainer(for: schema, configurations: config)
            return (container, .normal)
        } catch {
            let movedAsideTo = moveAside(storeURL)
            do {
                let container = try ModelContainer(for: schema, configurations: config)
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
