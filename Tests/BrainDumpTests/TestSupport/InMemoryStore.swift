import Foundation
import SwiftData
@testable import BrainDumpKit

@MainActor
enum InMemoryStore {
    static func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Day.self, TaskItem.self, ScheduleEntry.self,
            configurations: config
        )
        return ModelContext(container)
    }
}
