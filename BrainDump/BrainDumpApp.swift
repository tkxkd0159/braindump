import SwiftUI
import SwiftData
import BrainDumpKit

@main
struct BrainDumpApp: App {
    let container: ModelContainer

    init() {
        Fonts.registerIfNeeded()
        do {
            container = try ModelContainer(
                for: Day.self, TaskItem.self, ScheduleEntry.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("Brain Dump") {
            AppShell()
                .frame(minWidth: 1100, minHeight: 760)
                .tint(Theme.Palette.primary)
        }
        .modelContainer(container)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}
