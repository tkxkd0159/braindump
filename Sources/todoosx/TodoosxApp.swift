import SwiftUI
import SwiftData
import TodoosxKit

@main
struct TodoosxApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Day.self, TaskItem.self, ScheduleEntry.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("todoosx") {
            AppShell()
                .frame(minWidth: 920, minHeight: 720)
        }
        .modelContainer(container)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}
