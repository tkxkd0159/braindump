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
                .tint(Color(red: 0x1c / 255, green: 0x32 / 255, blue: 0x55 / 255))
        }
        .modelContainer(container)
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}
