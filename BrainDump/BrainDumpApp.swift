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
                .frame(minWidth: WindowSizing.minWidth, minHeight: WindowSizing.minHeight)
                .background(WindowConfigurator())
                .tint(Theme.Palette.primary)
        }
        .modelContainer(container)
        .windowStyle(.hiddenTitleBar)
        // `.contentMinSize` (not `.contentSize`) keeps the min as a floor but
        // leaves the max unbounded, so the zoom button and title-bar
        // double-click can expand the window to fill the screen. See WindowSizing.
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.model.checkNow() }
                    .disabled(!updater.model.canCheckForUpdates)
            }
        }
    }
}
