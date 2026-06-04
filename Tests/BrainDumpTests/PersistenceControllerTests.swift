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
        #expect(url.deletingLastPathComponent().lastPathComponent == "BrainDump")
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
}
