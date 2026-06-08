import SwiftUI
import SwiftData
import BrainDumpKit

@main
struct BrainDumpApp: App {
    let container: ModelContainer
    let storeRecovery: StoreRecovery
    let updater = SparkleUpdaterController()

    init() {
        Fonts.registerIfNeeded()
        let result = PersistenceController.makeContainer()
        container = result.container
        storeRecovery = result.recovery
    }

    var body: some Scene {
        WindowGroup("Brain Dump") {
            AppShell(storeRecovery: storeRecovery, updateModel: updater.model)
                .frame(minWidth: 1100, minHeight: 760)
                .tint(Theme.Palette.primary)
        }
        .modelContainer(container)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.model.checkNow() }
                    .disabled(!updater.model.canCheckForUpdates)
            }
        }
    }
}
