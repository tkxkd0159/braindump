import Foundation
import SwiftData

@testable import BrainDumpKit

/// A real on-disk SwiftData store in a unique temp directory. Unlike
/// `InMemoryStore`, the on-disk backend reproduces the app's deletion timing
/// (a just-deleted model is NOT detached synchronously), which is required to
/// reproduce the Clear Data crash. Call `cleanup()` in a `defer`.
@MainActor
enum FileBackedStore {
    static func makeContext() throws -> (context: ModelContext, cleanup: () -> Void) {
        let dir = URL.temporaryDirectory.appending(
            path: "BrainDumpTest-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let storeURL = dir.appending(path: "store.sqlite")
        let config = ModelConfiguration(url: storeURL)
        let container = try ModelContainer(
            for: Day.self, TaskItem.self, ScheduleEntry.self,
            configurations: config)
        let context = ModelContext(container)
        return (context, { try? FileManager.default.removeItem(at: dir) })
    }
}
