import AppKit
import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import BrainDumpKit

/// Regression for the "backing data detached" fatal error that happened when
/// the user pressed "Clear Data" while DayView was on screen. Pre-fix,
/// `Top3Section`/`BrainDumpSection`/`ScheduleSection` stored a `let day: Day`
/// reference (and `Top3SlotRow`/`ScheduleBlockView` stored `TaskItem` /
/// `ScheduleEntry`). When `dayService.clearAllData()` flushed the deletion,
/// SwiftData detached those models' backings and SwiftUI re-ran dirty bodies
/// against them — crashing on `\Day.top3ItemIDs` attribute-fault resolution.
/// The fix guards each body with `model.modelContext != nil` so the stale
/// re-render short-circuits before any `@Attribute` read.
@MainActor
struct ClearDataCrashTests {
    /// Minimal canvas around `DayView` to exercise the same lifecycle as
    /// AppShell without exposing the private `MainCanvas` type.
    private struct Harness: View {
        @Bindable var state: AppState

        var body: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    DayView(state: state)
                        .padding(.horizontal, 64)
                }
            }
        }
    }

    @Test
    func modelContextIsNilAfterDeleteAndSave() throws {
        // Anchors the fix: the `let day: Day` views guard with
        // `day.modelContext != nil` so they short-circuit before reading
        // any `@Attribute` (which would fault-resolve and crash).
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let day = dayService.day(for: TestDate.at(2026, 5, 22))
        #expect(day.modelContext != nil)

        dayService.clearAllData()

        #expect(day.modelContext == nil)
    }

    @Test
    func clearAllDataWhileDayViewIsOnScreenDoesNotCrash() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let day = dayService.day(for: TestDate.at(2026, 5, 22))
        let item = taskService.addBrainDumpItem(title: "Task with priority", on: day)
        try taskService.escalate(item, on: day)
        _ = try scheduleService.schedule(
            item, on: day, startMinute: 9 * 60, durationMinutes: 60)

        let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 5, 22) },
            defaults: defaults
        )

        let size = NSSize(width: 1200, height: 900)
        let view = Harness(state: state)
            .environment(\.modelContext, context)
            .frame(width: size.width, height: size.height)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        // The crash reproducer: wipe the store while the views above still
        // reference the now-detached Day. Without the per-view
        // `day.modelContext != nil` guard, SwiftUI re-runs Top3Section /
        // BrainDumpSection bodies and crashes on `day.top3ItemIDs`.
        state.clearAllData()

        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        #expect((try context.fetch(FetchDescriptor<Day>())).isEmpty)
    }
}
