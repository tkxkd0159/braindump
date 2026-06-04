import AppKit
import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import BrainDumpKit

/// Regression for the SwiftData `_assertionFailure` crash on Settings -> Clear
/// Data while Today is on screen (crash report: `ForEachChild.updateValue()` ->
/// `BrainDumpSection.row(for:)` during the alert/sheet-dismissal animation).
///
/// Root cause: `clearAllData()` deletes the Day + items but does NOT invalidate
/// the section bodies, so the existing `ForEach` children survive holding the
/// deleted `TaskItem`s. A forced SwiftUI transaction (the sheet-close animation)
/// then re-evaluates those stale children against deleted models and traps.
///
/// The literal SIGTRAP needs SwiftUI's internal animation-transaction child
/// update, which is NOT deterministically triggerable from a unit test — a
/// runloop pump and a forced resize/layout pass were both verified NOT to
/// re-evaluate the children. This test therefore asserts the FIX'S MECHANISM:
/// after the wipe, `DayView`'s `.id(state.dataGeneration)` changes and the
/// subtree is rebuilt against a fresh empty `Day` (`Day.count == 1`) — exactly
/// the condition that tears down the stale children. Pre-fix the subtree is not
/// rebuilt (`Day.count == 0`). The literal crash is verified manually in the app.
@MainActor
struct ClearDataCrashTests {
    /// Stand-in for the private `MainCanvas`. MUST mirror MainCanvas's
    /// `.id(state.dataGeneration)` on `DayView`, or this test does not exercise
    /// the fix.
    private struct Harness: View {
        @Bindable var state: AppState
        var body: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    DayView(state: state)
                        .id(state.dataGeneration)
                        .padding(.horizontal, 64)
                }
            }
        }
    }

    @Test
    func clearDataRebuildsDayViewAgainstFreshDay() throws {
        Fonts.registerIfNeeded()
        let (context, cleanup) = try FileBackedStore.makeContext()
        defer { cleanup() }

        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let day = dayService.day(for: TestDate.at(2026, 5, 22))
        let item = taskService.addBrainDumpItem(title: "Task with priority", on: day)
        try taskService.escalate(item, on: day)  // populates Top3
        _ = try scheduleService.schedule(
            item, on: day, startMinute: 9 * 60, durationMinutes: 60)  // populates Schedule

        let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
        let state = AppState(
            context: context, now: { TestDate.at(2026, 5, 22) }, defaults: defaults)

        let size = NSSize(width: 1200, height: 900)
        let view = Harness(state: state)
            .environment(\.modelContext, context)
            .frame(width: size.width, height: size.height)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        state.clearAllData()

        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        // Fix mechanism: the subtree rebuilt and vended a fresh empty Day.
        // Pre-fix DayView never re-ran, so this is 0 (red); post-fix it is 1.
        #expect((try context.fetch(FetchDescriptor<Day>())).count == 1)
        #expect((try context.fetch(FetchDescriptor<TaskItem>())).isEmpty)
    }
}
